# WebStack Lambda

Custom CloudFormation resource backing `webstack-network` and the
`ProvisionWeave`/marketplace-service-account setup in `eks.yaml`. Shells
out to `kubectl` and `aws` (via `crhelper`'s `run_command`), so both
binaries must be present in the deployment package at `bin/` - there is
no Lambda layer for them anymore (the `eks-quickstart-Kubectl`/`AwsCli`
layers this used to depend on came from the now-retired AWS Quick Start
shared resources).

`eks.yaml` sets `PATH` to include `/var/task/bin`, so `kubectl`/`aws`
just need to land at `functions/source/WebStack/bin/kubectl` and
`functions/source/WebStack/bin/aws` before running `./cmd.sh lambda`.

## Building the bin/ bundle

Both binaries must be Linux x86_64 (this Lambda runs on `python3.13`,
`x86_64` architecture) - build them in a container matching that
runtime rather than downloading platform-specific binaries on a dev
machine, since a Windows/macOS download will not run in Lambda.

```sh
docker run --rm -v "$PWD:/out" -w /out public.ecr.aws/lambda/python:3.13 bash -c '
  set -euo pipefail
  mkdir -p bin

  # kubectl - single static binary
  KUBECTL_VERSION=$(curl -sL https://dl.k8s.io/release/stable.txt)
  curl -sL "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl" -o bin/kubectl
  chmod +x bin/kubectl

  # AWS CLI v2 - unpack the official installer, keep only the runnable dist/
  curl -sL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip
  cd /tmp && unzip -q awscliv2.zip && cd -
  cp -r /tmp/aws/dist bin/aws-dist
  ln -sf aws-dist/aws bin/aws
'
```

Run this from `functions/source/WebStack/`. Verify both work before
packaging:

```sh
docker run --rm -v "$PWD:/var/task" -w /var/task public.ecr.aws/lambda/python:3.13 \
  bash -c 'PATH=/var/task/bin:$PATH kubectl version --client && PATH=/var/task/bin:$PATH aws --version'
```

Then run `./cmd.sh lambda` from the repo root as usual to zip everything
(including `bin/`) into `functions/packages/WebStack/lambda.zip`.

`bin/` is gitignored - each contributor (or CI) rebuilds it locally
rather than committing ~50-80MB of vendored binaries.
