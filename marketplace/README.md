# AWS Marketplace release

Tags matching `v*` publish SpaceMade's Kubernetes UI images, a self-contained
Helm chart, versioned CloudFormation templates, and a paid AWS Marketplace
container product version. Like the CMS product, the Marketplace version uses
an EKS Helm delivery option and also points buyers to the full EKS
CloudFormation Quick Start. It can separately submit a limited-visibility EKS
add-on delivery option for validation. It uses the same dedicated Marketplace
AWS credentials as the approved OpenADA release workflow.

The buyer flow is: subscribe to the paid container product, launch
`cloudformation/eks.yaml`, then sign in to the UI. Marketplace ECR prevents an
unsubscribed account from pulling the product artifacts. At pod startup the
auth image also calls `RegisterUsage`; any non-throttling error (including
`CustomerNotEntitledException`) terminates the pod before login is available.
The Quick Start creates the least-privilege IRSA role used for this call.

## GitHub repository variables

Required:

- `MP_AWS_ACCESS_KEY_ID` - dedicated Marketplace AWS access key ID, stored as a
  repository variable to match the approved OpenADA release workflow.
- `MP_AWS_SECRET_ACCESS_KEY` - matching key, stored as a repository secret.
- `MP_AWS_ECR` - AWS Marketplace-managed ECR registry hostname. Defaults to
  `709825985650.dkr.ecr.us-east-1.amazonaws.com`.
- `MP_AWS_MARKETPLACE_PRODUCT_ID` - Marketplace container product ID
  (`prod-...`).
- `MP_PRODUCT_CODE` - product code embedded in the paid auth image's startup
  configuration and passed to `RegisterUsage`.

Optional defaults:

- `AWS_REGION` (`us-east-1`)
- `MP_AUTH_REPOSITORY` (`solodev/kubernetes-ui-auth`)
- `MP_API_REPOSITORY` (`solodev/kubernetes-ui-api`)
- `MP_WEB_REPOSITORY` (`solodev/kubernetes-ui-web`)
- `MP_METRICS_REPOSITORY` (`solodev/kubernetes-ui-metrics-scraper`)
- `MP_CHART_REPOSITORY` (`solodev/kubernetes-dashboard`)
- `KUBERNETES_RELEASE_BUCKET` (`solodev-kubernetes`)
- `USAGE_INSTRUCTIONS_URL` (`https://github.com/techcto/aws-kubernetes`)
- `MP_ENABLE_EKS_ADDON` (`false`) - set to `true` only when the product is
  ready for AWS's separate limited-visibility EKS add-on validation.

The Marketplace portal must create/authorize every listed ECR repository for
this product before the first release. The IAM role needs ECR push, S3 publish,
and `marketplace-catalog:StartChangeSet` permissions.

The SpaceMade web image owns gateway routing, so Marketplace submission
contains four application images plus the OCI chart; no fifth gateway image is
required.

## Marketplace product settings

Use a **paid monthly container product** (for example, `$99/month`) with an
EKS Helm delivery option compatible with EKS and EKS Anywhere. Do not publish
the Marketplace image or rendered chart to a public registry. The
CloudFormation template and source repository can be public; entitlement is
enforced by the Marketplace-managed ECR artifacts and `RegisterUsage`.

The EKS cluster must keep `IamOidcProvider=Enabled` (the default). AWS requires
IRSA—not node credentials, EKS Pod Identity, or stored access keys—for
`RegisterUsage` from EKS.

The EKS add-on delivery requires semantic release versions and AMD64/ARM64
images. The workflow builds both architectures and initially declares EKS 1.36
compatibility. Its change set is intentionally separate from the Helm delivery,
so add-on validation cannot block the primary product release. Complete AWS ISV
testing before setting `MP_ENABLE_EKS_ADDON=true` or changing its visibility
from `Limited`.
