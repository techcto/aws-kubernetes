# aws-kubernetes

CloudFormation templates and Helm charts for deploying a Solodev-managed
Amazon EKS cluster into an existing VPC, with an optional set of cluster
add-ons (ingress, external DNS, TLS via cert-manager/Let's Encrypt, and the
Kubernetes Dashboard).

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
    built-in `view`/`edit`/`cluster-admin` ClusterRoles (see
    `charts/network/templates/admin-role.yaml`)

## Repository layout

| Path | Purpose |
|---|---|
| `eks.yaml` | Root CloudFormation template: EKS control plane, node group, Load Balancer Controller, and the self-hosted helper Lambdas |
| `webstack.yaml`, `webstack/` | Optional add-on stacks, installed via `AWSQS::Kubernetes::Helm` |
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
- CloudFormation public extensions activated in the target region/account:
  `AWSQS::Kubernetes::Helm` (used for all Helm-based installs in this repo)

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

## Contributing

Issues and pull requests welcome. Please open an issue before large
changes to the CloudFormation templates, since they provision real
account-level infrastructure (IAM roles, EKS access entries) that's easy
to get subtly wrong.
