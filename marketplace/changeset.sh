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
: "${MP_CHART_REPOSITORY:?Set MP_CHART_REPOSITORY}"

images=(
  "$MP_AWS_ECR/$MP_AUTH_REPOSITORY:$RELEASE_VERSION"
  "$MP_AWS_ECR/$MP_API_REPOSITORY:$RELEASE_VERSION"
  "$MP_AWS_ECR/$MP_WEB_REPOSITORY:$RELEASE_VERSION"
  "$MP_AWS_ECR/$MP_METRICS_REPOSITORY:$RELEASE_VERSION"
)
images_json="$(printf '%s\n' "${images[@]}" | jq -R . | jq -s .)"

quickstart_url="https://$KUBERNETES_RELEASE_BUCKET.s3.amazonaws.com/cloudformation/$RELEASE_VERSION/eks.yaml"

details="$(jq -n \
  --arg version "$RELEASE_VERSION" \
  --arg chart "$MP_AWS_ECR/$MP_CHART_REPOSITORY:$RELEASE_VERSION" \
  --arg usage "$USAGE_INSTRUCTIONS_URL" \
  --arg quickstart "$quickstart_url" \
  --argjson images "$images_json" \
  '{Version:{VersionTitle:$version,ReleaseNotes:("SpaceMade Kubernetes UI " + $version + " with private OIDC SSO, AWS Marketplace entitlement enforcement, and a full EKS Quick Start.")},DeliveryOptions:[{DeliveryOptionTitle:"Deploy SpaceMade Kubernetes UI on EKS",Details:{HelmDeliveryOptionDetails:{ContainerImages:$images,HelmChartUri:$chart,CompatibleServices:["EKS","EKS-Anywhere"],Description:"Deploy the paid SpaceMade Kubernetes UI on Amazon EKS with Helm, or use the complete CloudFormation EKS Quick Start.",UsageInstructions:("Subscribe first. Complete EKS CloudFormation Quick Start: " + $quickstart + ". Additional deployment instructions: " + $usage),ReleaseName:"kubernetes-dashboard",MarketplaceServiceAccountName:"kubernetes-dashboard-auth",Namespace:"kubernetes-dashboard",OverrideParameters:[{Key:"auth.serviceAccount.create",DefaultValue:"false",Metadata:{Label:"Create auth service account",Description:"AWS Marketplace supplies the metering service account, so the chart must not create a duplicate.",Obfuscate:false}},{Key:"auth.serviceAccount.name",DefaultValue:"${AWSMP_SERVICE_ACCOUNT}",Metadata:{Label:"Marketplace service account",Description:"Use the AWS Marketplace service account that is authorized for RegisterUsage.",Obfuscate:false}}]}}}]}' )"

aws marketplace-catalog start-change-set --catalog AWSMarketplace --change-set "$(jq -n \
  --arg id "$MP_PRODUCT_ID" --arg details "$details" \
  '[{ChangeType:"AddDeliveryOptions",Entity:{Identifier:$id,Type:"ContainerProduct@1.0"},Details:$details}]')"
