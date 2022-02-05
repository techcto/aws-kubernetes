import json
import logging
import boto3
import subprocess
import shlex
from crhelper import CfnResource

logger = logging.getLogger(__name__)
helper = CfnResource(json_logging=True, log_level='DEBUG')

try:
    s3_client = boto3.client('s3')
    iam_client = boto3.client('iam')
    kms_client = boto3.client('kms')
except Exception as init_exception:
    helper.init_failure(init_exception)


def run_command(command):
    try:
        print("executing command: %s" % command)
        output = subprocess.check_output(shlex.split(command), stderr=subprocess.STDOUT).decode("utf-8")
        print(output)
    except subprocess.CalledProcessError as exc:
        print("Command failed with exit code %s, stderr: %s" % (exc.returncode, exc.output.decode("utf-8")))
        raise Exception(exc.output.decode("utf-8"))
    return output

def create_kubeconfig(cluster_name):
    run_command(f"aws eks update-kubeconfig --name {cluster_name} --alias {cluster_name}")
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

def enable_dashboard():
    logger.debug(run_command("kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.0.0-beta8/aio/deploy/alternative.yaml"))
    logger.debug(run_command("kubectl apply -f https://raw.githubusercontent.com/techcto/charts/master/solodev-network/templates/admin-role.yaml"))
    logger.debug(run_command("kubectl create clusterrolebinding permissive-binding --clusterrole=cluster-admin --user=admin --user=kubelet --group=system:serviceaccounts;"))

def get_token():
    token=subprocess.check_output("kubectl get secrets -n kube-system -o jsonpath=\"{.items[?(@.metadata.annotations['kubernetes\.io/service-account\.name']=='eks-admin')].data.token}\"", shell=True).decode("utf-8")
    helper.Data['Token'] = token

@helper.create
@helper.update
def create_handler(event, _):
    print('Received event: %s' % json.dumps(event))
    create_kubeconfig(event['ResourceProperties']['ClusterName'])
    response_data = {}
    if 'Weave' in event['ResourceProperties'].keys():
        enable_weave()
    if 'Dashboard' in event['ResourceProperties'].keys():
        enable_dashboard()
    if 'Marketplace' in event['ResourceProperties'].keys():
        enable_marketplace(event['ResourceProperties']['ClusterName'], event['ResourceProperties']['Namespace'], event['ResourceProperties']['ServiceRoleName'])
    if 'AccessToken' in event['ResourceProperties'].keys():
        get_token()

def lambda_handler(event, context):
    helper(event, context)
