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
  '{
    Version: {
      VersionTitle: $version,
      ReleaseNotes: ("Kubernetes-UI " + $version + " with container image and EKS Helm delivery, OIDC SSO, and version-locked CloudFormation Quick Starts.")
    },
    DeliveryOptions: [
      {
        DeliveryOptionTitle: "Kubernetes-UI Container Images",
        Details: {
          EcrDeliveryOptionDetails: {
            ContainerImages: $images,
            CompatibleServices: ["EKS"],
            DeploymentResources: [
              {Name: "Existing EKS CloudFormation Quick Start", Url: $existing},
              {Name: "Complete EKS CloudFormation Quick Start", Url: $quickstart}
            ],
            Description: "Deploy the Kubernetes-UI container images on Amazon EKS using the provided CloudFormation Quick Starts or your own Kubernetes configuration.",
            UsageInstructions: ("First subscribe and accept the terms at https://aws.amazon.com/marketplace/pp/prodview-7uaseskhg4mla using the AWS account that will run the cluster. Wait until the subscription is active before launching CloudFormation or Helm. All four images are required. Configure the auth service account with IRSA and AWSMarketplaceMeteringRegisterUsage; retain Marketplace entitlement registration. Existing EKS Quick Start: " + $existing + ". Complete EKS Quick Start: " + $quickstart + ". Installation and access instructions: " + $usage)
          }
        }
      },
      {
        DeliveryOptionTitle: "Kubernetes-UI Helm Chart for Amazon EKS",
        Details: {
          HelmDeliveryOptionDetails: {
            ContainerImages: $images,
            HelmChartUri: $chart,
            CompatibleServices: ["EKS"],
            Description: "Install Kubernetes-UI on Amazon EKS using the versioned Helm chart, with optional CloudFormation installation.",
            UsageInstructions: ("First subscribe and accept the terms at https://aws.amazon.com/marketplace/pp/prodview-7uaseskhg4mla using the AWS account that will run the cluster. Wait until the subscription is active before launching CloudFormation or Helm. Existing EKS Quick Start: " + $existing + ". Complete EKS Quick Start: " + $quickstart + ". Helm installation and access instructions: " + $usage),
            ReleaseName: "kubernetes-dashboard",
            MarketplaceServiceAccountName: "kubernetes-dashboard-auth",
            Namespace: "kubernetes-dashboard",
            OverrideParameters: [
              {
                Key: "auth.serviceAccount.create",
                DefaultValue: "false",
                Metadata: {Label: "Create auth service account", Description: "AWS Marketplace supplies the entitlement service account, so the chart must not create a duplicate.", Obfuscate: false}
              },
              {
                Key: "auth.serviceAccount.name",
                DefaultValue: "${AWSMP_SERVICE_ACCOUNT}",
                Metadata: {Label: "Marketplace service account", Description: "Use the AWS Marketplace service account authorized for fixed-monthly entitlement registration.", Obfuscate: false}
              }
            ]
          }
        }
      }
    ]
  }' )"

aws marketplace-catalog start-change-set --catalog AWSMarketplace --change-set "$(jq -n \
  --arg id "$MP_PRODUCT_ID" --arg details "$details" \
  '[{ChangeType:"AddDeliveryOptions",Entity:{Identifier:$id,Type:"ContainerProduct@1.0"},Details:$details}]')"
