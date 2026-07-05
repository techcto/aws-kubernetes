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
# crhelper - boto3 isn't bundled since the Lambda runtime already provides it)
# and zips the whole thing into functions/packages/WebStack/lambda.zip, all
# inside a container matching the Lambda runtime. Runs in Docker even on
# Linux/macOS: zipping on the host can silently drop the executable bit on
# some filesystems (NTFS has no such concept at all), which produces a zip
# that fails at runtime with no error until Lambda actually tries to use it.
# Builds in an isolated /tmp dir inside the container (never bind-mounted) so
# pip's vendored dependencies never land in the git-tracked source directory.
lambda(){
    MSYS_NO_PATHCONV=1 docker run --rm -v "$PWD:/repo" -w /repo --entrypoint bash public.ecr.aws/lambda/python:3.13 -c '
        set -euo pipefail
        microdnf install -y zip >/dev/null

        rm -rf /tmp/build && mkdir -p /tmp/build
        cp functions/source/WebStack/lambda_function.py /tmp/build/
        pip install --quiet --target /tmp/build kubernetes pyyaml crhelper --no-cache-dir --upgrade

        rm -f /repo/functions/packages/WebStack/lambda.zip
        cd /tmp/build
        zip -rq /repo/functions/packages/WebStack/lambda.zip . -x "*__pycache__*"
    '
}

cft(){
    ./deploy.sh
}

test(){
    ./test.sh
}

kcmd(){
    aws s3 cp kcmd.sh s3://solodev-kubernetes/kcmd.sh --acl public-read
}

$*