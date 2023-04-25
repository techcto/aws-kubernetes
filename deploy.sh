#!/usr/bin/env bash
DEPLOY=1
DATE=$(date +%d%H%M)

aws s3 cp shared.yaml s3://solodev-kubernetes/cloudformation/shared.yaml --acl public-read

# echo "Create Shared Resources"
# aws cloudformation create-stack --disable-rollback --stack-name tmp-shared-${DATE} --disable-rollback --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM \
#     --template-url https://s3.amazonaws.com/solodev-kubernetes/cloudformation/shared.yaml

aws s3 cp eks.yaml s3://solodev-kubernetes/cloudformation/eks.yaml --acl public-read
aws s3 cp submodules/quickstart-amazon-eks-nodegroup/templates/amazon-eks-nodegroup.template.yaml s3://solodev-kubernetes/cloudformation/amazon-eks-nodegroup.template.yaml --acl public-read
aws s3 cp submodules/quickstart-amazon-eks/templates/amazon-eks-load-balancer-controller.template.yaml s3://solodev-kubernetes/cloudformation/amazon-eks-load-balancer-controller.template.yaml --acl public-read
aws s3 cp submodules/quickstart-aws-vpc/templates/aws-vpc.template.yaml s3://solodev-kubernetes/cloudformation/aws-vpc.template.yaml --acl public-read

aws s3 cp webstack.yaml s3://solodev-kubernetes/cloudformation/webstack.yaml --acl public-read
aws s3 sync webstack s3://solodev-kubernetes/cloudformation/webstack --delete
aws s3 sync functions/packages s3://solodev-kubernetes/cloudformation/functions/packages --delete

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

# echo "Create Salesforce"
# export AWS_PROFILE=cloud
# aws cloudformation create-stack --disable-rollback --stack-name tmp-sales-${DATE} --disable-rollback --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM \
#     --parameters file://bin/salesforce.json \
#     --template-url https://s3.amazonaws.com/solodev-kubernetes/cloudformation/webstack/webstack-salesforce.template.yaml