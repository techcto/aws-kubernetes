#!/usr/bin/env bash
set -euo pipefail

: "${MP_PRODUCT_ID:?Set MP_PRODUCT_ID}"
: "${RELEASE_VERSION:?Set RELEASE_VERSION}"
: "${MP_AWS_ECR:?Set MP_AWS_ECR}"
: "${USAGE_INSTRUCTIONS_URL:?Set USAGE_INSTRUCTIONS_URL}"
: "${KUBERNETES_RELEASE_BUCKET:?Set KUBERNETES_RELEASE_BUCKET}"
: "${MP_AUTH_REPOSITORY:?Set MP_AUTH_REPOSITORY}"
: "${MP_API_REPOSITORY:?Set MP_API_REPOSITORY}"
: "${MP_WEB_REPOSITORY:?Set MP_WEB_REPOSITORY}"
: "${MP_METRICS_REPOSITORY:?Set MP_METRICS_REPOSITORY}"
: "${MP_KONG_REPOSITORY:?Set MP_KONG_REPOSITORY}"

images=(
  "$MP_AWS_ECR/$MP_AUTH_REPOSITORY:$RELEASE_VERSION"
  "$MP_AWS_ECR/$MP_API_REPOSITORY:$RELEASE_VERSION"
  "$MP_AWS_ECR/$MP_WEB_REPOSITORY:$RELEASE_VERSION"
  "$MP_AWS_ECR/$MP_METRICS_REPOSITORY:$RELEASE_VERSION"
  "$MP_AWS_ECR/$MP_KONG_REPOSITORY:3.9"
)
images_json="$(printf '%s\n' "${images[@]}" | jq -R . | jq -s .)"

quickstart_url="https://$KUBERNETES_RELEASE_BUCKET.s3.amazonaws.com/cloudformation/eks.yaml"

details="$(jq -n \
  --arg version "$RELEASE_VERSION" \
  --arg usage "$USAGE_INSTRUCTIONS_URL" \
  --arg quickstart "$quickstart_url" \
  --argjson images "$images_json" \
  '{Version:{VersionTitle:$version,ReleaseNotes:("SpaceMade Kubernetes UI " + $version + " with private OIDC SSO, AWS Marketplace entitlement enforcement, and a full EKS Quick Start.")},DeliveryOptions:[{Details:{EcrDeliveryOptionDetails:{DeliveryOptionTitle:"Kubernetes UI – EKS Quick Start",ContainerImages:$images,DeploymentResources:[{Name:"Launch the complete EKS stack with CloudFormation",Url:$quickstart}],CompatibleServices:["EKS"],Description:"Paid SpaceMade Kubernetes UI container for Amazon EKS. The linked CloudFormation Quick Start provisions EKS and installs the subscribed UI.",UsageInstructions:("Subscribe first, then launch the CloudFormation Quick Start. The UI auth pod calls AWS Marketplace RegisterUsage through IRSA and refuses to start when the buyer is not entitled. Deployment guide: " + $usage)}}}]}' )"

aws marketplace-catalog start-change-set --catalog AWSMarketplace --change-set "$(jq -n \
  --arg id "$MP_PRODUCT_ID" --arg details "$details" \
  '[{ChangeType:"AddDeliveryOptions",Entity:{Identifier:$id,Type:"ContainerProduct@1.0"},Details:$details}]')"
