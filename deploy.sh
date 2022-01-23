#!/usr/bin/env bash
DEPLOY=1
DATE=$(date +%d%H%M)

# aws s3 cp eks.json s3://build-secure/solodev-kubernetes/eks.json
aws s3 cp eks.yaml s3://solodev-kubernetes/cloudformation/eks.yaml --acl public-read
aws s3 cp ./submodules/quickstart-amazon-eks-nodegroup/templates/amazon-eks-nodegroup.template.yaml s3://solodev-kubernetes/cloudformation/nodegroup.yaml --acl public-read

./bin/stacks.sh