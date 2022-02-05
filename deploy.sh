#!/usr/bin/env bash
DEPLOY=1
DATE=$(date +%d%H%M)

aws s3 cp eks.yaml s3://solodev-kubernetes/cloudformation/eks.yaml --acl public-read
aws s3 cp nodegroup.yaml s3://solodev-kubernetes/cloudformation/nodegroup.yaml --acl public-read
aws s3 cp solodev-eks-nginx-ingress.template.yaml s3://solodev-kubernetes/cloudformation/solodev-eks-nginx-ingress.template.yaml --acl public-read
aws s3 cp solodev-eks-external-dns.template.yaml s3://solodev-kubernetes/cloudformation/solodev-eks-external-dns.template.yaml --acl public-read
aws s3 cp solodev-eks-lets-encrypt.template.yaml s3://solodev-kubernetes/cloudformation/solodev-eks-lets-encrypt.template.yaml --acl public-read
aws s3 sync functions/packages s3://solodev-kubernetes/cloudformation/functions/packages --delete

./bin/stacks.sh