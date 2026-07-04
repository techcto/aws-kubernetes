#!/usr/bin/env bash
# Publishes eks.yaml, webstack.yaml/webstack/, and functions/packages/ to S3.
# Does NOT create a stack - see test.sh for that.

aws s3 cp eks.yaml s3://solodev-kubernetes/cloudformation/eks.yaml --acl public-read

aws s3 cp webstack.yaml s3://solodev-kubernetes/cloudformation/webstack.yaml --acl public-read
aws s3 sync webstack s3://solodev-kubernetes/cloudformation/webstack --delete
aws s3 sync functions/packages s3://solodev-kubernetes/cloudformation/functions/packages --delete
