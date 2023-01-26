#!/bin/bash
export AWS_PROFILE=default

helm package network
helm package dashboard
helm package lets-encrypt
helm package solodev-cms
helm package wordpress
helm repo index .
helm repo update

aws s3 cp index.yaml s3://solodev-kubernetes/charts/index.yaml
aws s3 sync . s3://solodev-kubernetes/charts/ --exclude "*" --include="*.tgz"
aws s3 sync network/templates s3://solodev-kubernetes/charts/network