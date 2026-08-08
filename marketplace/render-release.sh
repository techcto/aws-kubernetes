#!/usr/bin/env bash
set -euo pipefail

: "${RELEASE_VERSION:?Set RELEASE_VERSION}"
: "${MP_AWS_ECR:?Set MP_AWS_ECR}"
: "${MP_AUTH_REPOSITORY:?Set MP_AUTH_REPOSITORY}"
: "${MP_API_REPOSITORY:?Set MP_API_REPOSITORY}"
: "${MP_WEB_REPOSITORY:?Set MP_WEB_REPOSITORY}"
: "${MP_METRICS_REPOSITORY:?Set MP_METRICS_REPOSITORY}"
: "${MP_KONG_REPOSITORY:?Set MP_KONG_REPOSITORY}"
: "${MP_CHART_REPOSITORY:?Set MP_CHART_REPOSITORY}"
: "${MP_PRODUCT_CODE:?Set MP_PRODUCT_CODE}"

output="${1:-release-artifacts}"
case "$output" in
  ""|/|.|..) echo "Refusing unsafe output directory: $output" >&2; exit 1 ;;
esac
rm -rf "$output"
mkdir -p "$output/cloudformation/webstack" "$output/chart"
cp -R submodules/kubernetes-ui/charts/kubernetes-dashboard/. "$output/chart/"

sed -i \
  -e "0,/^version: /s//version: $RELEASE_VERSION/" \
  -e "/^auth:/,/^api:/ s|repository: .*|repository: $MP_AWS_ECR/$MP_AUTH_REPOSITORY|" \
  -e "/^auth:/,/^api:/ s|tag: .*|tag: $RELEASE_VERSION|" \
  -e "/^api:/,/^web:/ s|repository: .*|repository: $MP_AWS_ECR/$MP_API_REPOSITORY|" \
  -e "/^api:/,/^web:/ s|tag: .*|tag: $RELEASE_VERSION|" \
  -e "/^web:/,/^metricsScraper:/ s|repository: .*|repository: $MP_AWS_ECR/$MP_WEB_REPOSITORY|" \
  -e "/^web:/,/^metricsScraper:/ s|tag: .*|tag: $RELEASE_VERSION|" \
  -e "/^metricsScraper:/,/^metrics-server:/ s|repository: .*|repository: $MP_AWS_ECR/$MP_METRICS_REPOSITORY|" \
  -e "/^metricsScraper:/,/^metrics-server:/ s|tag: .*|tag: $RELEASE_VERSION|" \
  "$output/chart/values.yaml"

# Kong is the only enabled dependency image in the default chart. Disabled
# cert-manager/nginx/metrics-server dependencies remain disabled.
tar -xzf "$output/chart/charts/kong-2.52.0.tgz" -C "$output/chart/charts"
rm "$output/chart/charts/kong-2.52.0.tgz"
sed -i \
  -e "0,/repository: kong/s|repository: kong|repository: $MP_AWS_ECR/$MP_KONG_REPOSITORY|" \
  "$output/chart/charts/kong/values.yaml"

helm package "$output/chart" --destination "$output" --version "$RELEASE_VERSION" --app-version "$RELEASE_VERSION"

cp eks.yaml webstack.yaml "$output/cloudformation/"
cp webstack/*.template.yaml "$output/cloudformation/webstack/"
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
