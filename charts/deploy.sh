#!/bin/bash
export AWS_PROFILE="${AWS_PROFILE:-develop}"

helm package network
helm package lets-encrypt
helm repo index .

aws s3 cp index.yaml s3://solodev-kubernetes/charts/index.yaml
aws s3 sync . s3://solodev-kubernetes/charts/ --exclude "*" --include="*.tgz"
aws s3 sync network/templates s3://solodev-kubernetes/charts/network