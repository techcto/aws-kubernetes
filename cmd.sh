#!/bin/bash
args=("$@")

# solodev-kubernetes S3/CloudFormation operations default to the develop
# account; override with AWS_PROFILE=<name> ./cmd.sh <command> as needed
# (e.g. a "demo" profile for testing launches against a demo account).
export AWS_PROFILE="${AWS_PROFILE:-develop}"

tag(){
    VERSION="${args[1]}"
    git tag -a v${VERSION} -m "tag release"
    git push --tags
}

init(){
    git submodule init
    git submodule add -f https://github.com/techcto/kubernetes-ui.git ./submodules/kubernetes-ui
}

update(){
    git submodule update
}

build(){
    command -v cfn-lint >/dev/null || pip install --quiet cfn-lint
    cfn-lint eks.yaml webstack.yaml webstack/*.template.yaml

    aws cloudformation validate-template --template-body file://eks.yaml >/dev/null \
        && echo "eks.yaml: valid"
    aws cloudformation validate-template --template-body file://webstack.yaml >/dev/null \
        && echo "webstack.yaml: valid"
}

helm(){
    cd charts
    ./deploy.sh
}

# Installs functions/source/WebStack's Python deps (kubernetes client, pyyaml,
# crhelper - boto3 isn't bundled since the Lambda runtime already provides it),
# vendors a static helm binary (replaces the AWSQS::Kubernetes::Helm registry
# extension - see functions/source/WebStack/README.md), and zips the whole
# thing into functions/packages/WebStack/lambda.zip, all inside a container
# matching the Lambda runtime. Runs in Docker even on Linux/macOS: zipping on
# the host can silently drop the executable bit on some filesystems (NTFS has
# no such concept at all), which produces a zip that fails at runtime with no
# error until Lambda actually tries to exec helm. Builds in an isolated /tmp
# dir inside the container (never bind-mounted) so pip's vendored dependencies
# never land in the git-tracked source directory.
lambda(){
    HELM_VERSION="${HELM_VERSION:-v3.16.3}"
    MSYS_NO_PATHCONV=1 docker run --rm -v "$PWD:/repo" -w /repo -e HELM_VERSION="$HELM_VERSION" --entrypoint bash public.ecr.aws/lambda/python:3.13 -c '
        set -euo pipefail
        microdnf install -y zip tar gzip >/dev/null
        command -v curl >/dev/null || microdnf install -y curl >/dev/null

        rm -rf /tmp/build && mkdir -p /tmp/build
        cp functions/source/WebStack/lambda_function.py /tmp/build/
        pip install --quiet --target /tmp/build kubernetes pyyaml crhelper --no-cache-dir --upgrade

        curl -sSL "https://get.helm.sh/helm-${HELM_VERSION}-linux-amd64.tar.gz" | tar -xz -C /tmp linux-amd64/helm
        mv /tmp/linux-amd64/helm /tmp/build/helm
        chmod +x /tmp/build/helm

        rm -f /repo/functions/packages/WebStack/lambda.zip
        cd /tmp/build
        zip -rq /repo/functions/packages/WebStack/lambda.zip . -x "*__pycache__*"
    '
}

cft(){
    ./deploy.sh
}

# Builds and pushes the Dashboard's Docker images (auth, api, web) from the
# techcto/kubernetes-ui submodule to Docker Hub as spacemade/kubernetes-ui-*.
# Usage:
#   ./cmd.sh images                  # build + push auth, api, and web at :latest
#   ./cmd.sh images auth             # just one of them
#   VERSION=1.2.3 ./cmd.sh images    # tag with a version instead of latest
images(){
    local target="${args[1]:-all}"
    local version="${VERSION:-latest}"
    local modules_dir="submodules/kubernetes-ui/modules"

    local names
    case "$target" in
        all) names=(auth api web) ;;
        auth|api|web) names=("$target") ;;
        *) echo "Unknown image target: $target (expected auth, api, web, or all)" >&2; return 1 ;;
    esac

    for name in "${names[@]}"; do
        local image="spacemade/kubernetes-ui-${name}:${version}"
        echo "[images] Building ${image}"
        docker build \
            -f "${modules_dir}/${name}/Dockerfile" \
            -t "${image}" \
            --build-arg TARGETARCH=amd64 \
            --build-arg TARGETOS=linux \
            --build-arg VERSION="${version}" \
            "${modules_dir}"

        echo "[images] Pushing ${image}"
        docker push "${image}"
    done
}

test(){
    ./test.sh
}

kcmd(){
    aws s3 cp kcmd.sh s3://solodev-kubernetes/kcmd.sh --acl public-read
}

$*