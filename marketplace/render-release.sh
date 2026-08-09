#!/usr/bin/env bash
set -euo pipefail

: "${RELEASE_VERSION:?Set RELEASE_VERSION}"
: "${MP_AWS_ECR:?Set MP_AWS_ECR}"
: "${MP_AUTH_REPOSITORY:?Set MP_AUTH_REPOSITORY}"
: "${MP_API_REPOSITORY:?Set MP_API_REPOSITORY}"
: "${MP_WEB_REPOSITORY:?Set MP_WEB_REPOSITORY}"
: "${MP_METRICS_REPOSITORY:?Set MP_METRICS_REPOSITORY}"
: "${MP_CHART_REPOSITORY:?Set MP_CHART_REPOSITORY}"
: "${MP_PRODUCT_CODE:?Set MP_PRODUCT_CODE}"
: "${KUBERNETES_RELEASE_BUCKET:?Set KUBERNETES_RELEASE_BUCKET}"

output="${1:-release-artifacts}"
case "$output" in
  ""|/|.|..) echo "Refusing unsafe output directory: $output" >&2; exit 1 ;;
esac
rm -rf "$output"
mkdir -p "$output/cloudformation/webstack" "$output/cloudformation/functions/packages/WebStack" "$output/chart"
cp -R submodules/kubernetes-ui/charts/kubernetes-dashboard/. "$output/chart/"

# Marketplace releases use the self-contained SpaceMade dashboard only. The
# source chart keeps optional community dependencies for non-Marketplace users,
# but disabled third-party charts/images must not enter the reviewed artifact.
rm -rf "$output/chart/charts"
mkdir -p "$output/chart/charts"
sed -i '/^dependencies:/,$d' "$output/chart/Chart.yaml"

sed -i \
  -e "0,/^version: /s//version: $RELEASE_VERSION/" \
  -e "/^auth:/,/^api:/ s|repository: .*|repository: $MP_AWS_ECR/$MP_AUTH_REPOSITORY|" \
  -e "/^auth:/,/^api:/ s|tag: .*|tag: $RELEASE_VERSION|" \
  -e "/^auth:/,/^api:/ s|^    args: \[\]|    args:\n      - --marketplace-product-code=$MP_PRODUCT_CODE|" \
  -e "/^api:/,/^web:/ s|repository: .*|repository: $MP_AWS_ECR/$MP_API_REPOSITORY|" \
  -e "/^api:/,/^web:/ s|tag: .*|tag: $RELEASE_VERSION|" \
  -e "/^web:/,/^metricsScraper:/ s|repository: .*|repository: $MP_AWS_ECR/$MP_WEB_REPOSITORY|" \
  -e "/^web:/,/^metricsScraper:/ s|tag: .*|tag: $RELEASE_VERSION|" \
  -e "/^metricsScraper:/,/^metrics-server:/ s|repository: .*|repository: $MP_AWS_ECR/$MP_METRICS_REPOSITORY|" \
  -e "/^metricsScraper:/,/^metrics-server:/ s|tag: .*|tag: $RELEASE_VERSION|" \
  "$output/chart/values.yaml"

helm package "$output/chart" --destination "$output" --version "$RELEASE_VERSION" --app-version "$RELEASE_VERSION"

cp eks.yaml webstack.yaml "$output/cloudformation/"
cp webstack/*.template.yaml "$output/cloudformation/webstack/"
cp functions/packages/WebStack/lambda.zip "$output/cloudformation/functions/packages/WebStack/"
dashboard="$output/cloudformation/webstack/webstack-dashboard.template.yaml"
sed -i \
  -e "s|Repository: \"http://solodev-kubernetes.s3-website-us-east-1.amazonaws.com/charts\"|Repository: \"oci://$MP_AWS_ECR/$MP_CHART_REPOSITORY\"|" \
  -e "s|Chart: kubernetes-dashboard|Chart: kubernetes-dashboard|" \
  -e "s|Version: 7.14.0|Version: $RELEASE_VERSION|" \
  -e "s|repository: spacemade/kubernetes-ui-auth|repository: $MP_AWS_ECR/$MP_AUTH_REPOSITORY|g" \
  -e "s|repository: spacemade/kubernetes-ui-api|repository: $MP_AWS_ECR/$MP_API_REPOSITORY|g" \
  -e "s|repository: spacemade/kubernetes-ui-web|repository: $MP_AWS_ECR/$MP_WEB_REPOSITORY|g" \
  -e "s|tag: latest|tag: $RELEASE_VERSION|g" \
  "$dashboard"

sed -i \
  "/^  MarketplaceProductCode:/,/^  [A-Za-z]/ s|^    Default: \"\"|    Default: \"$MP_PRODUCT_CODE\"|" \
  "$output/cloudformation/eks.yaml"

# Keep the root template, nested stacks, and Lambda package in the selected
# release bucket. Marketplace sellers often use a bucket separate from their
# legacy public chart repository.
find "$output/cloudformation" -type f -name '*.yaml' -exec \
  sed -i "s|solodev-kubernetes|$KUBERNETES_RELEASE_BUCKET|g" {} +
