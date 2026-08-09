#!/usr/bin/env bash
set -euo pipefail

: "${MP_PRODUCT_ID:?Set MP_PRODUCT_ID}"
: "${RELEASE_VERSION:?Set RELEASE_VERSION}"
: "${MP_AWS_ECR:?Set MP_AWS_ECR}"
: "${USAGE_INSTRUCTIONS_URL:?Set USAGE_INSTRUCTIONS_URL}"
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

details="$(jq -n \
  --arg version "$RELEASE_VERSION" \
  --arg chart "$MP_AWS_ECR/$MP_CHART_REPOSITORY:$RELEASE_VERSION" \
  --arg usage "$USAGE_INSTRUCTIONS_URL" \
  --argjson images "$images_json" \
  '{Version:{VersionTitle:$version,ReleaseNotes:("Kubernetes UI " + $version + " as a limited-visibility Amazon EKS add-on.")},DeliveryOptions:[{DeliveryOptionTitle:"Kubernetes UI EKS Add-on",Visibility:"Limited",Details:{EksAddOnDeliveryOptionDetails:{ContainerImages:$images,HelmChartUri:$chart,Description:"Install and manage Kubernetes UI from the Amazon EKS add-on catalog.",UsageInstructions:("Subscribe before installing the add-on. Documentation: " + $usage),AddOnName:"kubernetes-ui",AddOnVersion:$version,AddOnType:"infra-management",CompatibleKubernetesVersions:["1.36"],SupportedArchitectures:["amd64","arm64"],Namespace:"kubernetes-dashboard",EnvironmentOverrideParameters:[{Key:"cluster-name",Value:"${AWS_EKS_CLUSTER_NAME}"},{Key:"region-name",Value:"${AWS_REGION}"}]}}}]}' )"

aws marketplace-catalog start-change-set --catalog AWSMarketplace --change-set "$(jq -n \
  --arg id "$MP_PRODUCT_ID" --arg details "$details" \
  '[{ChangeType:"AddDeliveryOptions",Entity:{Identifier:$id,Type:"ContainerProduct@1.0"},Details:$details}]')"
