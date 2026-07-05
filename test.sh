#!/usr/bin/env bash
# Creates a throwaway EKS stack from the currently-published eks.yaml, for
# testing template changes end-to-end. Run ./deploy.sh first to publish.
DATE=$(date +%d%H%M)
REGION="${REGION:-us-east-1}"
PROFILE="${AWS_PROFILE:-}"
PROFILE_ARGS=()
[ -n "$PROFILE" ] && PROFILE_ARGS=(--profile "$PROFILE")

# Refuse to launch while another tmp-kube-* test stack is still around - they
# share the same VPC/subnets, and a half-deleted stack contending for the same
# limited subnet IP space is a real, observed cause of the new cluster's own
# control plane failing to stabilize.
EXISTING=$(aws cloudformation list-stacks --region "$REGION" "${PROFILE_ARGS[@]}" \
    --stack-status-filter CREATE_COMPLETE CREATE_IN_PROGRESS UPDATE_COMPLETE DELETE_IN_PROGRESS DELETE_FAILED \
    --query "StackSummaries[?starts_with(StackName, 'tmp-kube-')].[StackName,StackStatus]" --output text)
if [ -n "$EXISTING" ]; then
    echo "Refusing to launch - another tmp-kube-* stack is still around:"
    echo "$EXISTING"
    echo "Wait for it to fully delete (check: aws eks list-clusters --region $REGION) before starting a new one."
    exit 1
fi

echo "Create Solodev EKS Cluster (region: ${REGION})"
aws cloudformation create-stack --region "$REGION" --disable-rollback --stack-name tmp-kube-${DATE} --disable-rollback --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM \
    --parameters file://bin/eks.json \
    --template-url https://s3.amazonaws.com/solodev-kubernetes/cloudformation/eks.yaml

# echo "Create Webstack"
# aws cloudformation create-stack --disable-rollback --stack-name tmp-webstack-${DATE} --disable-rollback --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM \
#     --parameters file://bin/webstack.json \
#     --template-url https://s3.amazonaws.com/solodev-kubernetes/cloudformation/webstack.yaml

# echo "Create Dashboard"
# # export AWS_PROFILE=cloud
# aws cloudformation create-stack --disable-rollback --stack-name tmp-dash-${DATE} --disable-rollback --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM \
#     --parameters file://bin/dashboard.json \
#     --template-url https://s3.amazonaws.com/solodev-kubernetes/cloudformation/webstack/webstack-dashboard.template.yaml

# echo "Create Network"
# aws cloudformation create-stack --disable-rollback --stack-name tmp-net-${DATE} --disable-rollback --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM \
#     --parameters file://bin/network.json \
#     --template-url https://s3.amazonaws.com/solodev-kubernetes/cloudformation/webstack/webstack-network.template.yaml
