#!/usr/bin/env bash
DATE=$(date +%d%H%M)

echo "Create AWS EKS Mega Cluster"
aws cloudformation create-stack --disable-rollback --stack-name tmp-kube-${DATE} --disable-rollback --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM \
    --parameters file://bin/eks.json \
    --template-url https://s3.amazonaws.com/solodev-kubernetes/cloudformation/eks.yaml