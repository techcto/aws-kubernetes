import json
import logging
import boto3
import subprocess
import shlex
import time
import math
from hashlib import md5

from crhelper import CfnResource

logger = logging.getLogger(__name__)
helper = CfnResource(json_logging=True, log_level="DEBUG")

try:
    s3_client = boto3.client('s3')
    iam_client = boto3.client('iam')
    kms_client = boto3.client('kms')
except Exception as init_exception:
    helper.init_failure(init_exception)

def run_command(command):
    try:
        logger.info(f"executing command: {command}")
        output = subprocess.check_output(  # nosec B603
            shlex.split(command), stderr=subprocess.STDOUT
        ).decode("utf-8")
        logger.info(output)
    except subprocess.CalledProcessError as e:
        logger.exception(
            "Command failed with exit code %s, stderr: %s"
            % (e.returncode, e.output.decode("utf-8"))
        )
        raise Exception(e.output.decode("utf-8"))

    return output


def create_kubeconfig(cluster_name):
    run_command(
        f"aws eks update-kubeconfig --name {cluster_name} --alias {cluster_name}"
    )
    run_command(f"kubectl config use-context {cluster_name}")

def enable_weave():
    logger.debug(run_command("kubectl delete ds aws-node -n kube-system"))
    subprocess.check_output("curl --location -o /tmp/weave-net.yaml \"https://cloud.weave.works/k8s/net?k8s-version=$(kubectl version | base64 | tr -d '\n')\"", shell=True)
    logger.debug(run_command("kubectl apply -f /tmp/weave-net.yaml"))

#Apply AWS Marketplace service account for launching paid container apps
def enable_marketplace(cluster_name, namespace, role_name):
    try:
        logger.debug(run_command(f"kubectl create namespace {namespace}"))
    except Exception as exception:
        print("Namespace already exists")
    
    try:
        ISSUER_URL = run_command(f"aws eks describe-cluster --name {cluster_name} --query cluster.identity.oidc.issuer --output text")
        print(ISSUER_URL)
        ISSUER_HOSTPATH = subprocess.check_output("echo \"" + ISSUER_URL + "\" | cut -f 3- -d'/'", shell=True).decode("utf-8")
        print(ISSUER_HOSTPATH)
        ACCOUNT_ID = run_command(f"aws sts get-caller-identity --query Account --output text")
        print(ACCOUNT_ID)
        irp_trust_policy = {
            "Version": "2012-10-17",
            "Statement": [
                {
                    "Effect": "Allow",
                    "Principal": {
                        "Federated": "arn:aws:iam::{ACCOUNT_ID}:oidc-provider/{ISSUER_HOSTPATH}"
                    },
                    "Action": "sts:AssumeRoleWithWebIdentity",
                    "Condition": {
                        "StringEquals": {
                            "{ISSUER_HOSTPATH}:sub": "system:serviceaccount:{namespace}:{role_name}"
                        }
                    }
                }
            ]
        }
        RoleName=role_name+"-"+namespace
        iam_client.create_role(
            RoleName=RoleName,
            AssumeRolePolicyDocument=json.dumps(irp_trust_policy)
        )
    except Exception as exception:
        print("Role already exists")

    try:
        aws_usage_policy = {
            "Version": "2012-10-17",
            "Statement": [
                {
                    "Action": [
                        "aws-marketplace:RegisterUsage"
                    ],
                    "Resource": "*",
                    "Effect": "Allow"
                }
            ]
        }
        response = iam_client.create_policy(
            PolicyName='AWSUsagePolicy-' + namespace,
            PolicyDocument=json.dumps(aws_usage_policy)
        )
        iam_client.attach_role_policy(
            RoleName=RoleName,
            PolicyArn=response['Policy']['Arn']
        )
    except Exception as exception:
        print("Policy already exists")

    try:
        logger.debug(run_command(f"kubectl create sa {role_name} --namespace {namespace}"))
        ROLE_ARN = run_command(f"aws iam get-role --role-name {RoleName} --query Role.Arn --output text")
        print(ROLE_ARN)
        logger.debug(run_command(f"kubectl annotate sa {role_name} eks.amazonaws.com/role-arn={ROLE_ARN} --namespace {namespace}"))
    except Exception as exception:
        print("There was an error.")

def enable_solodev():
    logger.debug(run_command("kubectl apply -f http://solodev-kubernetes.s3-website-us-east-1.amazonaws.com/charts/network/admin-role.yaml"))
    logger.debug(run_command("kubectl apply -f http://solodev-kubernetes.s3-website-us-east-1.amazonaws.com/charts/network/storage-class.yaml"))
    print("Get Access Token")
    TOKEN = run_command("kubectl get secrets -n kube-system -o jsonpath=\"{.items[?(@.metadata.annotations['kubernetes\.io/service-account\.name']=='solodev-admin')].data.token}\"")
    helper.Data['Token'] = TOKEN

@helper.create
@helper.update
def create_handler(event, context):
    create_kubeconfig(event["ResourceProperties"]["ClusterName"])

    interval = 5
    retry_timeout = (
        math.floor(context.get_remaining_time_in_millis() / interval / 1000) - 1
    )

    while True:
        try:
            outp = "Init Solodev"
            if 'Weave' in event['ResourceProperties'].keys():
                enable_weave()
            if 'Marketplace' in event['ResourceProperties'].keys():
                enable_marketplace(event['ResourceProperties']['ClusterName'], event['ResourceProperties']['Namespace'], event['ResourceProperties']['ServiceRoleName'])
            if 'Solodev' in event['ResourceProperties'].keys():
                enable_solodev()
            break
        except Exception:
            if retry_timeout < 1:
                message = "Out of retries"
                logger.error(message)
                raise RuntimeError(message)
            else:
                logger.info("Retrying until timeout...")

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

def lambda_handler(event, context):
    props = event.get("ResourceProperties", {})
    logger.setLevel(props.get("LogLevel", logging.INFO))
    logger.debug(json.dumps(event))
    helper(event, context)