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
existing_cluster_url="https://$KUBERNETES_RELEASE_BUCKET.s3.amazonaws.com/cloudformation/$RELEASE_VERSION/kubernetes-ui.yaml"

details="$(jq -n \
  --arg version "$RELEASE_VERSION" \
  --arg chart "$MP_AWS_ECR/$MP_CHART_REPOSITORY:$RELEASE_VERSION" \
  --arg usage "$USAGE_INSTRUCTIONS_URL" \
  --arg quickstart "$quickstart_url" \
  --arg existing "$existing_cluster_url" \
  --argjson images "$images_json" \
  '{Version:{VersionTitle:$version,ReleaseNotes:("Kubernetes UI " + $version + " with private OIDC SSO, fixed-monthly AWS Marketplace entitlement enforcement, and version-locked existing/full EKS Quick Starts.")},DeliveryOptions:[{DeliveryOptionTitle:"Deploy Kubernetes UI on EKS",Details:{HelmDeliveryOptionDetails:{ContainerImages:$images,HelmChartUri:$chart,CompatibleServices:["EKS"],Description:"Deploy Kubernetes UI on an existing EKS cluster with Helm or CloudFormation, or launch the complete EKS stack.",UsageInstructions:("Subscribe first. Existing EKS Quick Start: " + $existing + ". Complete EKS stack: " + $quickstart + ". eksctl and Helm instructions: " + $usage),ReleaseName:"kubernetes-dashboard",MarketplaceServiceAccountName:"kubernetes-dashboard-auth",Namespace:"kubernetes-dashboard",OverrideParameters:[{Key:"auth.serviceAccount.create",DefaultValue:"false",Metadata:{Label:"Create auth service account",Description:"AWS Marketplace supplies the entitlement service account, so the chart must not create a duplicate.",Obfuscate:false}},{Key:"auth.serviceAccount.name",DefaultValue:"${AWSMP_SERVICE_ACCOUNT}",Metadata:{Label:"Marketplace service account",Description:"Use the AWS Marketplace service account authorized for fixed-monthly entitlement registration.",Obfuscate:false}}]}}}]}' )"

aws marketplace-catalog start-change-set --catalog AWSMarketplace --change-set "$(jq -n \
  --arg id "$MP_PRODUCT_ID" --arg details "$details" \
  '[{ChangeType:"AddDeliveryOptions",Entity:{Identifier:$id,Type:"ContainerProduct@1.0"},Details:$details}]')"
