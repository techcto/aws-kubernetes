#!/usr/bin/env bash
DEPLOY=1
DATE=$(date +%d%H%M)

# aws s3 cp shared.yaml s3://solodev-kubernetes/cloudformation/shared.yaml --acl public-read

# echo "Create Shared Resources"
# aws cloudformation create-stack --disable-rollback --stack-name tmp-shared-${DATE} --disable-rollback --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM \
#     --template-url https://s3.amazonaws.com/solodev-kubernetes/cloudformation/shared.yaml

aws s3 cp eks.yaml s3://solodev-kubernetes/cloudformation/eks.yaml --acl public-read
aws s3 cp nodegroup.yaml s3://solodev-kubernetes/cloudformation/nodegroup.yaml --acl public-read
aws s3 cp solodev-eks-nginx-ingress.template.yaml s3://solodev-kubernetes/cloudformation/solodev-eks-nginx-ingress.template.yaml --acl public-read
aws s3 cp solodev-eks-external-dns.template.yaml s3://solodev-kubernetes/cloudformation/solodev-eks-external-dns.template.yaml --acl public-read
aws s3 cp solodev-eks-lets-encrypt.template.yaml s3://solodev-kubernetes/cloudformation/solodev-eks-lets-encrypt.template.yaml --acl public-read
aws s3 sync functions/packages s3://solodev-kubernetes/cloudformation/functions/packages --delete

echo "Create AWS EKS Mega Cluster"
aws cloudformation create-stack --disable-rollback --stack-name tmp-kube-${DATE} --disable-rollback --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM \
    --parameters file://bin/eks.json \
    --template-url https://s3.amazonaws.com/solodev-kubernetes/cloudformation/eks.yaml

# aws s3 cp webstack.yaml s3://solodev-kubernetes/cloudformation/webstack.yaml --acl public-read

# echo "Create Webstack"
# aws cloudformation create-stack --disable-rollback --stack-name tmp-webstack-${DATE} --disable-rollback --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM \
#     --parameters file://bin/webstack.json \
#     --template-url https://s3.amazonaws.com/solodev-kubernetes/cloudformation/webstack.yaml