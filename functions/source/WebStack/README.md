# WebStack Lambda

Custom CloudFormation resource backing Helm installs, network bootstrap,
subnet tagging, and the cert-manager ClusterIssuer setup. The deployment
package includes the Kubernetes Python client, Helm, and the repository-owned
network/Let's Encrypt manifests, so stack creation does not depend on the
retired public S3 Helm repository.

`eks.yaml` sets `PATH` to include `/var/task/bin`, so `kubectl`/`aws`
need to land there inside the deployment package.

## Building

From the repo root:

```sh
./cmd.sh lambda
```

This does everything inside a container matching the Lambda runtime
(`public.ecr.aws/lambda/python:3.13`, `x86_64`) — installs the Python
dependencies, vendors Helm and the local manifests, then creates
`functions/packages/WebStack/lambda.zip`. Requires Docker.

It always runs in Docker, even on Linux/macOS: zipping on the host can
silently drop the executable bit (NTFS has no such concept at all, and
even some Linux/macOS setups can lose it through a Docker bind mount) —
producing a zip that looks fine but fails at runtime the moment Lambda
tries to exec `kubectl`/`aws`, with no error until then. Building and
zipping in the same container sidesteps that entirely.

`bin/` is gitignored - each contributor (or CI) rebuilds it locally
rather than committing ~50-80MB of vendored binaries. `./cmd.sh lambda`
only re-fetches the binaries if `bin/kubectl` and `bin/aws-dist/aws`
aren't already there, so re-runs after just editing `lambda_function.py`
are fast.
