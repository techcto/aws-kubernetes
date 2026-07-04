# kcmd.sh

Interactive CLI for creating and managing a Solodev EKS cluster
(`eks.yaml`) — the CloudFormation-based counterpart to this
organization's `ekscli.sh` (which drives clusters via `eksctl` for
running Solodev CMS). Use `kcmd.sh` when the cluster itself is, or
should be, a CloudFormation stack from this repo.

## Install

```bash
curl -O https://solodev-kubernetes.s3.amazonaws.com/kcmd.sh && chmod 700 kcmd.sh
```

Requires: `aws` CLI, `kubectl`, `helm`, `jq`

## Publish (maintainers)

```bash
./cmd.sh kcmd
```

Uploads `kcmd.sh` to `s3://solodev-kubernetes/kcmd.sh` (public-read) —
run this after any change to the script.

## Usage

```
./kcmd.sh [options]                    Open interactive menu
./kcmd.sh [options] create cluster     Create the EKS cluster (eks.yaml)
./kcmd.sh [options] delete cluster     Delete the EKS cluster and all resources
./kcmd.sh [options] kubeconfig         Write/refresh the kubeconfig
./kcmd.sh [options] status             Show stack + pod status
./kcmd.sh [options] ls                 List all pods and services
./kcmd.sh [options] pod <name>         Show a pod
./kcmd.sh [options] logs <name>        Follow a pod's logs
./kcmd.sh [options] token              Print admin token
./kcmd.sh [options] proxy              Open Dashboard (port-forward)
./kcmd.sh [options] update             Update Helm repos
./kcmd.sh [options] install <name>     Install a release
./kcmd.sh [options] delete <name>      Delete a Helm release + PVCs
./kcmd.sh [options] clean <namespace>  Force-clean a namespace
./kcmd.sh [options] initsecret <ns>    Create a namespace
./kcmd.sh [options] ssh <host>         Print a bastion-proxied ssh command
```

**Options**

| Flag | Description |
|------|-------------|
| `-y, --yes` | Skip confirmation prompts |
| `--dry-run` | Print commands without running them |
| `--region <name>` | AWS region (default: `us-east-1`) |
| `-h, --help` | Show help |

**Environment overrides**

| Variable | Default | Description |
|----------|---------|-------------|
| `AWS_PROFILE` | prompt / `.kcmd/aws.profile` | AWS named profile |
| `STACK_NAME` | prompt / `.kcmd/stack.<user>` | CloudFormation stack / cluster name |
| `REGION` | `us-east-1` | AWS region |
| `USER_ARN` | — | Also grant this IAM principal cluster-admin access |
| `KUBECONFIG` | `.kcmd/<stack>.kubeconfig` | Kubeconfig path |

## First run

On first run, `kcmd.sh` prompts for an AWS profile and cluster/stack
name and saves both to `.kcmd/` (gitignored, per-developer state) so
you don't need to pass them again. `create cluster` also prompts once
for the handful of `eks.yaml` parameters that have no sensible default
(VPC ID, a private subnet, the cluster DNS zone, optionally a key pair)
and saves them to `.kcmd/<stack>.params.json` — edit that file directly
to set anything else (node type, node count, add-ons, ...) before
re-running `create cluster`.

## Recommended flow

```bash
# 1. Create the cluster (once per developer/environment)
./kcmd.sh create cluster

# 2. Confirm it's up
./kcmd.sh status

# 3. Access the dashboard
./kcmd.sh proxy
# then open http://localhost:8080/#/overview?namespace=_all

# 4. Tear it down when done
./kcmd.sh delete cluster
```
