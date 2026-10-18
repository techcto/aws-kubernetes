# Kubernetes-UI: Web Dashboard for Kubernetes Clusters

Kubernetes-UI is an open-source web dashboard for managing Kubernetes workloads
and clusters. The SpaceMade and Solodev team maintains this continuation of
Kubernetes Dashboard, including security and dependency updates, OIDC/SSO
integration, release images, Helm packaging, and AWS deployment tooling.

The original [Kubernetes Dashboard project](https://github.com/kubernetes-retired/dashboard)
was archived after its maintainers reported a lack of active maintainers and
contributors. We are continuing development as **Kubernetes-UI**, with the goal
of keeping this dashboard useful and maintained. This is an independent
continuation; the original Apache 2.0 license and attribution are preserved.
Contributions and issue reports are welcome.

**[Launch Kubernetes-UI on AWS — Quick Start](marketplace/QUICKSTART.md)**

The guide covers installing into an existing Amazon EKS cluster or creating a
new EKS environment with CloudFormation, plus manual Helm installation. AWS
Marketplace software charges and AWS infrastructure charges are separate.

This repository contains the AWS deployment templates and release tooling.
The [Kubernetes-UI application source](https://github.com/techcto/kubernetes-ui)
contains the dashboard itself.

The control plane and node group are provisioned with native
`AWS::EKS::Cluster` / `AWS::EKS::Nodegroup` resources, and the cluster's
supporting Lambda functions (cluster-access lookup, load balancer
cleanup) are self-hosted inline in `eks.yaml`. This project no longer
depends on the AWS Quick Start EKS templates or its shared per-account/
per-region resources, both of which were retired in 2024–2025.

## What this deploys

- An EKS cluster (`eks.yaml`) with:
  - Native `AWS::EKS::Cluster` control plane and IAM role
  - Native `AWS::EKS::Nodegroup` (managed node group) with a launch
    template for custom bootstrap arguments (e.g. raising `max-pods`, or
    flags supported by a custom node AMI)
  - `AWS::EKS::AccessEntry` resources for cluster access instead of the
    legacy aws-auth ConfigMap
  - Optional AWS Load Balancer Controller, installed via Helm
- An optional web stack (`webstack.yaml` + `webstack/*.template.yaml`),
  installed via Helm, for:
  - NGINX Ingress
  - ExternalDNS (Route 53)
  - cert-manager + Let's Encrypt
  - Kubernetes Dashboard
  - A small custom Lambda-backed resource (`functions/source/WebStack`)
    for cluster-internal setup (Solodev network/token provisioning)
  - RBAC for SSO login into the Dashboard: a `dashboard-api` ServiceAccount
    allowed to impersonate users/groups, plus ClusterRoleBindings mapping
    Keycloak's `view`/`edit`/`admin` client roles onto Kubernetes' own
    built-in `view`/`edit`/`admin` ClusterRoles through organization-scoped
    `spacemade:namespace:<org>:<role>` groups; only the launcher receives
    cluster-admin access (see
    `charts/network/templates/admin-role.yaml`)
  - The same `AccessNamespace` value is passed into the Dashboard Helm
    settings as `defaultNamespace` and its fallback namespace, so every SSO
    role lands in the organization namespace instead of `default`

## Repository layout

| Path | Purpose |
|---|---|
| `eks.yaml` | Root CloudFormation template: EKS control plane, node group, Load Balancer Controller, and the self-hosted helper Lambdas |
| `kubernetes-ui.yaml` | Standalone Quick Start that installs only Kubernetes UI into an existing EKS cluster |
| `webstack.yaml`, `webstack/` | Optional add-on stacks, installed via the repository-owned `Custom::Helm` Lambda |
| `charts/` | Helm charts owned by this repo (`network`, `dashboard`, `lets-encrypt`) and their packaged `.tgz`/`index.yaml`, published as a private Helm repo |
| `functions/source/WebStack` | Source for the custom web-stack Lambda (see its own README for the `kubectl`/`aws` build step); `functions/packages/` holds the built `lambda.zip` |
| `submodules/amazon-eks-ami` | Fork used for custom node AMI builds (not consumed directly by the CFN templates) |
| `bin/eks.json` | Local, untracked CloudFormation parameters file for `eks.yaml` (see `deploy.sh`) |
| `kcmd.sh` | Interactive CLI to create/delete the cluster and manage it day-to-day (see `pages/kcmd.md`) — the CloudFormation-based counterpart to this org's `eksctl`-based `ekscli.sh` |
| `cmd.sh` | All build/deploy/publish commands (see below) |

## Prerequisites

- An existing VPC with public/private subnets
- AWS CLI and credentials for the target account
- [Helm](https://helm.sh/) 3+
- Docker (to build the `kubectl`/`aws` binaries vendored into the
  WebStack Lambda — see `functions/source/WebStack/README.md`)

## Building and deploying

Everything goes through `cmd.sh`:

```sh
./cmd.sh init      # one-time: register the amazon-eks-ami submodule
./cmd.sh lambda     # package functions/source/WebStack into functions/packages/WebStack/lambda.zip
./cmd.sh helm       # package charts/{network,dashboard,lets-encrypt} and publish the Helm repo index to S3
./cmd.sh cft        # publish eks.yaml/webstack.yaml/etc. to S3 (upload only, does not create a stack)
./cmd.sh test       # create a throwaway tmp-kube-* stack from the currently-published eks.yaml, using bin/eks.json
./cmd.sh kcmd       # publish kcmd.sh to S3 so it can be curl'd standalone
```

`kcmd.sh create cluster` always reads `eks.yaml` from S3, never your
local working copy — run `./cmd.sh lambda && ./cmd.sh helm && ./cmd.sh cft`
(in that order) to publish a change before creating a cluster from it.
See `pages/kcmd.md` for using `kcmd.sh` day-to-day once published.

## Kubernetes version support

`KubernetesVersion` in `eks.yaml` tracks Amazon EKS's standard support
window. Check the
[EKS Kubernetes release calendar](https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions.html)
before bumping the default or allowed values.

## Cloud catalog versions

The repository root contains `cloud.yaml` for Cloud's Kubernetes catalog item.
Link `techcto/aws-kubernetes` to the item through its **Git** action. Cloud
configures a signed repository webhook and imports the manifest from the exact
commit referenced by each new semantic version tag (for example `v1.2.3`).
Branch pushes, deleted tags, and forced tag updates do not create versions.
Repeated deliveries leave an existing catalog version unchanged.

`${Git.Version}` in the manifest resolves to the tag version without its `v`
prefix. Other expressions, such as `${Picker.AWSVPCID}`, stay unchanged until
installation. The starter creates draft versions; set `version_status: active`
when new tagged releases should publish automatically.

Publish the tagged release's artifacts before pushing its tag. The manifest
uses `https://kubernetes-ui.s3.amazonaws.com/cloudformation/${Git.Version}/eks.yaml`;
the existing `./cmd.sh cft` command publishes the development bundle to
`solodev-kubernetes`, so it does not populate that release URL. Building and
publishing artifacts remain separate from Cloud's webhook import. No pipeline
call to `cloud catalog update` is needed for a webhook-linked item.

## Direct installation overrides

CloudFormation defaults to AWS Marketplace images and entitlement checks.
For a direct installation using a shared private release registry, explicitly
set `DeliveryMode=Direct`, `ImageRegistry`, `ImageRepositoryPrefix`, and
`ImageVersion`. The version must exist for all four images and the OCI Helm
chart in that registry. Use the direct release's versioned CloudFormation URL
from the publishing bucket; do not mix nested templates from different releases.
See [release configuration](marketplace/README.md#direct-and-marketplace-release-paths).

## Teardown verification

The full cluster stack removes Helm workloads before its AWS fallback cleanup,
then waits for cluster-owned load balancers to disappear before deleting their
target groups and the cluster infrastructure. Network or permission errors on a
live cluster fail the deletion so it can be retried; only a confirmed missing
cluster or missing Helm release is treated as already deleted.

Run the offline regression checks before releasing template or installer changes:

```sh
python3 -m pip install -r tests/requirements.txt
python3 -m unittest discover -s tests -v
```

These tests cover ordering, ownership boundaries, retries and failure handling.
A real create/delete cycle in AWS is still required to verify service behavior.

## Contributing

Issues and pull requests welcome. Please open an issue before large
changes to the CloudFormation templates, since they provision real
account-level infrastructure (IAM roles, EKS access entries) that's easy
to get subtly wrong.
