import base64
import json
import logging
import math
import os
import subprocess
import time
from hashlib import md5

import boto3
import botocore.signers
import urllib3
import yaml
from kubernetes import client as k8s_client
from kubernetes import dynamic as k8s_dynamic
from kubernetes.client import Configuration

from crhelper import CfnResource

HELM_BIN = '/var/task/helm'

logger = logging.getLogger(__name__)
helper = CfnResource(json_logging=True, log_level="DEBUG")
# Short, explicit timeouts everywhere a network call could otherwise hang -
# without these, an unreachable endpoint fails after minutes instead of
# seconds, burning through the whole Lambda timeout across a few retries
# without ever surfacing a useful error.
NET_TIMEOUT = urllib3.Timeout(connect=10, read=20)
K8S_TIMEOUT = (10, 20)
http = urllib3.PoolManager(timeout=NET_TIMEOUT, retries=False)

try:
    iam_client = boto3.client('iam')
    eks_client = boto3.client('eks')
    sts_client = boto3.client('sts')
    ec2_client = boto3.client('ec2')
except Exception as init_exception:
    helper.init_failure(init_exception)


def get_bearer_token(cluster_name):
    """Generates an EKS auth token the same way `aws eks get-token` does,
    without needing the aws CLI - see the well-known STS presigned-URL scheme
    used by aws-iam-authenticator / the AWS CLI's `eks get-token` command."""
    session = boto3.session.Session()
    region = session.region_name or eks_client.meta.region_name
    sts = session.client('sts', region_name=region)
    signer = botocore.signers.RequestSigner(
        sts.meta.service_model.service_id, region, 'sts', 'v4',
        session.get_credentials(), session.events,
    )
    params = {
        'method': 'GET',
        'url': f'https://sts.{region}.amazonaws.com/?Action=GetCallerIdentity&Version=2011-06-15',
        'body': {},
        'headers': {'x-k8s-aws-id': cluster_name},
        'context': {},
    }
    signed_url = signer.generate_presigned_url(
        params, region_name=region, expires_in=60, operation_name='',
    )
    token = base64.urlsafe_b64encode(signed_url.encode('utf-8')).decode('utf-8').rstrip('=')
    return 'k8s-aws-v1.' + token


def k8s_api_client(cluster_name):
    cluster = eks_client.describe_cluster(name=cluster_name)['cluster']
    ca_path = '/tmp/eks-ca.crt'
    with open(ca_path, 'wb') as f:
        f.write(base64.b64decode(cluster['certificateAuthority']['data']))

    configuration = Configuration()
    configuration.host = cluster['endpoint']
    configuration.ssl_ca_cert = ca_path
    configuration.api_key = {'authorization': 'Bearer ' + get_bearer_token(cluster_name)}
    return k8s_client.ApiClient(configuration)


def apply_manifest_url(api_client, url):
    """Applies every document in a remote multi-doc YAML manifest, roughly
    equivalent to `kubectl apply -f <url>`."""
    dynamic_client = k8s_dynamic.DynamicClient(api_client)
    body = http.request('GET', url, timeout=NET_TIMEOUT).data
    for doc in yaml.safe_load_all(body):
        if not doc:
            continue
        resource = dynamic_client.resources.get(api_version=doc['apiVersion'], kind=doc['kind'])
        try:
            resource.create(body=doc, namespace=doc.get('metadata', {}).get('namespace'),
                             _request_timeout=K8S_TIMEOUT)
        except k8s_dynamic.exceptions.ConflictError:
            resource.patch(body=doc, namespace=doc.get('metadata', {}).get('namespace'),
                            content_type='application/merge-patch+json', _request_timeout=K8S_TIMEOUT)


def enable_marketplace(api_client, cluster_name, namespace, role_name):
    core_v1 = k8s_client.CoreV1Api(api_client)

    try:
        core_v1.create_namespace(k8s_client.V1Namespace(metadata=k8s_client.V1ObjectMeta(name=namespace)),
                                  _request_timeout=K8S_TIMEOUT)
    except k8s_client.exceptions.ApiException as e:
        if e.status != 409:
            raise
        logger.info("Namespace already exists")

    issuer_url = eks_client.describe_cluster(name=cluster_name)['cluster']['identity']['oidc']['issuer']
    issuer_hostpath = issuer_url.split('://', 1)[-1]
    account_id = sts_client.get_caller_identity()['Account']
    role_full_name = f"{role_name}-{namespace}"

    irp_trust_policy = {
        "Version": "2012-10-17",
        "Statement": [
            {
                "Effect": "Allow",
                "Principal": {"Federated": f"arn:aws:iam::{account_id}:oidc-provider/{issuer_hostpath}"},
                "Action": "sts:AssumeRoleWithWebIdentity",
                "Condition": {
                    "StringEquals": {f"{issuer_hostpath}:sub": f"system:serviceaccount:{namespace}:{role_name}"}
                },
            }
        ],
    }
    try:
        iam_client.create_role(RoleName=role_full_name, AssumeRolePolicyDocument=json.dumps(irp_trust_policy))
    except iam_client.exceptions.EntityAlreadyExistsException:
        logger.info("Role already exists")

    # Matches the AWS Marketplace listing's own manual `eksctl
    # create iamserviceaccount` instructions exactly - the running
    # CMS pod needs all three to register usage, meter it on an
    # ongoing basis, and check out its license at startup.
    for policy_arn in (
        "arn:aws:iam::aws:policy/AWSMarketplaceMeteringFullAccess",
        "arn:aws:iam::aws:policy/AWSMarketplaceMeteringRegisterUsage",
        "arn:aws:iam::aws:policy/service-role/AWSLicenseManagerConsumptionPolicy",
    ):
        iam_client.attach_role_policy(RoleName=role_full_name, PolicyArn=policy_arn)

    try:
        core_v1.create_namespaced_service_account(
            namespace, k8s_client.V1ServiceAccount(metadata=k8s_client.V1ObjectMeta(name=role_name)),
            _request_timeout=K8S_TIMEOUT)
    except k8s_client.exceptions.ApiException as e:
        if e.status != 409:
            raise

    role_arn = iam_client.get_role(RoleName=role_full_name)['Role']['Arn']
    core_v1.patch_namespaced_service_account(
        role_name, namespace,
        {"metadata": {"annotations": {"eks.amazonaws.com/role-arn": role_arn}}},
        _request_timeout=K8S_TIMEOUT,
    )


def tag_subnets(props):
    """The AWS Load Balancer Controller auto-discovers subnets via these
    tags - without them it can't provision a Service/Ingress load balancer
    at all. Idempotent (create_tags is an upsert), so safe to run on every
    update, not just create."""
    cluster_tag = {'Key': f"kubernetes.io/cluster/{props['ClusterName']}", 'Value': 'shared'}
    public_ids = [s for s in props.get('PublicSubnetIds', '').split(',') if s]
    private_ids = [s for s in props.get('PrivateSubnetIds', '').split(',') if s]

    if public_ids:
        ec2_client.create_tags(Resources=public_ids,
                                Tags=[cluster_tag, {'Key': 'kubernetes.io/role/elb', 'Value': '1'}])
    if private_ids:
        ec2_client.create_tags(Resources=private_ids,
                                Tags=[cluster_tag, {'Key': 'kubernetes.io/role/internal-elb', 'Value': '1'}])


def helm_kube_args(cluster_name):
    """--kube-* flags let the helm CLI talk to the cluster with a bearer
    token directly, the same way k8s_api_client() does for the python
    client - no kubeconfig file or in-cluster context needed."""
    cluster = eks_client.describe_cluster(name=cluster_name)['cluster']
    ca_path = '/tmp/eks-ca.crt'
    with open(ca_path, 'wb') as f:
        f.write(base64.b64decode(cluster['certificateAuthority']['data']))
    return [
        '--kube-apiserver', cluster['endpoint'],
        '--kube-token', get_bearer_token(cluster_name),
        '--kube-ca-file', ca_path,
    ]


def _redact(args):
    out = list(args)
    for i, a in enumerate(out):
        if a == '--kube-token' and i + 1 < len(out):
            out[i + 1] = '***'
    return out


def run_helm(args):
    # Lambda's only writable path is /tmp - helm's default cache/config/data
    # dirs live under $HOME, which is otherwise unset (or read-only) here.
    env = dict(os.environ, HOME='/tmp', XDG_CACHE_HOME='/tmp/.cache',
               XDG_CONFIG_HOME='/tmp/.config', XDG_DATA_HOME='/tmp/.data')
    logger.info("helm %s", ' '.join(_redact(args)))
    result = subprocess.run([HELM_BIN] + args, env=env, capture_output=True, text=True, timeout=600)
    logger.info("helm exit=%s\nstdout:\n%s\nstderr:\n%s", result.returncode, result.stdout, result.stderr)
    if result.returncode != 0:
        raise RuntimeError((result.stderr or result.stdout or 'helm failed with no output').strip()[:1500])
    return result.stdout


def ecr_registry_login(registry_host):
    """OCI charts hosted in ECR need a docker-style registry login before
    helm can pull them - unlike classic HTTP chart repos, there's no
    unauthenticated index to fetch. Cross-account pulls also require the
    target ECR repository's own policy to allow this account, which is a
    one-time setup step outside of what this function can do."""
    region = registry_host.split('.')[3]
    ecr_client = boto3.client('ecr', region_name=region)
    auth = ecr_client.get_authorization_token()
    token = base64.b64decode(auth['authorizationData'][0]['authorizationToken']).decode('utf-8')
    _, password = token.split(':', 1)

    env = dict(os.environ, HOME='/tmp')
    result = subprocess.run(
        [HELM_BIN, 'registry', 'login', registry_host, '--username', 'AWS', '--password-stdin'],
        input=password, env=env, capture_output=True, text=True, timeout=30,
    )
    if result.returncode != 0:
        raise RuntimeError((result.stderr or result.stdout or 'helm registry login failed').strip()[:1500])


def helm_install(props):
    cluster_name = props['ClusterName']
    namespace = props['Namespace']
    name = props['Name']
    chart = props['Chart']
    repository = props.get('Repository')
    is_oci = bool(repository) and repository.startswith('oci://')

    values_path = '/tmp/values.yaml'
    with open(values_path, 'w') as f:
        f.write(props.get('ValueYaml') or '')

    if is_oci:
        # OCI chart references are self-contained (registry + repo path) -
        # there's no separate --repo flag or bare chart name like classic
        # HTTP repos use; the full oci:// URL IS the chart argument.
        ecr_registry_login(repository[len('oci://'):].split('/', 1)[0])
        args = ['upgrade', '--install', name, repository,
                '--namespace', namespace, '--create-namespace',
                '--wait', '--timeout', '750s', '--atomic']
    else:
        args = ['upgrade', '--install', name, chart,
                '--namespace', namespace, '--create-namespace',
                '--wait', '--timeout', '750s', '--atomic']
        if repository:
            args += ['--repo', repository]

    if props.get('Version'):
        args += ['--version', props['Version']]
    if os.path.getsize(values_path) > 0:
        args += ['-f', values_path]
    for key, value in (props.get('Values') or {}).items():
        args += ['--set', f'{key}={value}']

    run_helm(args + helm_kube_args(cluster_name))
    return name


def helm_uninstall(props):
    # Deleting a Service of type LoadBalancer can outlast a short timeout -
    # the LB controller has to notice the deletion and tear down the actual
    # AWS NLB before helm's wait considers the release fully uninstalled.
    args = ['uninstall', props['Name'], '--namespace', props['Namespace'],
            '--wait', '--timeout', '480s']
    try:
        run_helm(args + helm_kube_args(props['ClusterName']))
    except RuntimeError as e:
        if 'release: not found' in str(e).lower():
            logger.info("Release already gone, nothing to uninstall")
        else:
            raise


def enable_solodev(api_client):
    apply_manifest_url(api_client, "http://solodev-kubernetes.s3-website-us-east-1.amazonaws.com/charts/network/admin-role.yaml")
    apply_manifest_url(api_client, "http://solodev-kubernetes.s3-website-us-east-1.amazonaws.com/charts/network/storage-class.yaml")

    # Kubernetes 1.24+ no longer auto-creates a long-lived Secret for a
    # ServiceAccount - request a token directly via the TokenRequest API.
    core_v1 = k8s_client.CoreV1Api(api_client)
    token_request = k8s_client.AuthenticationV1TokenRequest(spec=k8s_client.V1TokenRequestSpec())
    response = core_v1.create_namespaced_service_account_token(
        "solodev-admin", "kube-system", token_request, _request_timeout=K8S_TIMEOUT)
    helper.Data['Token'] = response.status.token


@helper.create
@helper.update
def create_handler(event, context):
    if event['ResourceType'] == 'Custom::Helm':
        return helm_install(event['ResourceProperties'])
    if event['ResourceType'] == 'Custom::SubnetTags':
        tag_subnets(event['ResourceProperties'])
        return 'subnet-tags'

    cluster_name = event["ResourceProperties"]["ClusterName"]

    interval = 5
    retry_timeout = (
        math.floor(context.get_remaining_time_in_millis() / interval / 1000) - 1
    )

    while True:
        try:
            api_client = k8s_api_client(cluster_name)
            outp = "Init Solodev"
            if 'Marketplace' in event['ResourceProperties'].keys():
                enable_marketplace(
                    api_client, cluster_name,
                    event['ResourceProperties']['Namespace'],
                    event['ResourceProperties']['ServiceRoleName'],
                )
            if 'Solodev' in event['ResourceProperties'].keys():
                enable_solodev(api_client)
            break
        except Exception as e:
            if retry_timeout < 1:
                logger.exception("Out of retries")
                raise RuntimeError(f"Out of retries: {e}")
            else:
                logger.exception("Retrying after error")
                time.sleep(interval)
                retry_timeout = retry_timeout - interval

    response_data = {"id": ""}

    if "ResponseKey" in event["ResourceProperties"]:
        response_data[event["ResourceProperties"]["ResponseKey"]] = outp
    if len(outp.encode("utf-8")) > 1000:
        outp_utf8 = outp.encode("utf-8")
        md5_digest = md5(outp_utf8).hexdigest()  # nosec B324, B303
        outp = "MD5-" + str(md5_digest)
    helper.Data.update(response_data)
    return outp


@helper.delete
def delete_handler(event, context):
    if event['ResourceType'] == 'Custom::Helm':
        helm_uninstall(event['ResourceProperties'])
    return ''


def lambda_handler(event, context):
    props = event.get("ResourceProperties", {})
    logger.setLevel(props.get("LogLevel", logging.INFO))
    logger.debug(json.dumps(event))
    helper(event, context)
