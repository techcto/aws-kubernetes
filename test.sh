#!/usr/bin/env bash
# Creates a throwaway EKS stack from the currently-published eks.yaml, for
# testing template changes end-to-end. Run ./deploy.sh first to publish.
DATE=$(date +%d%H%M)

echo "Create Solodev EKS Cluster"
aws cloudformation create-stack --disable-rollback --stack-name tmp-kube-${DATE} --disable-rollback --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM \
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
