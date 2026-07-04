#!/bin/bash
args=("$@")

tag(){
    VERSION="${args[1]}"
    git tag -a v${VERSION} -m "tag release"
    git push --tags
}

init(){
    git submodule init
    git submodule add -f https://github.com/techcto/amazon-eks-ami.git ./submodules/amazon-eks-ami
}

merge() {
    cd submodule/amazon-eks-ami
    git pull https://github.com/awslabs/amazon-eks-ami.git master --allow-unrelated-histories
    git fetch upstream
    git checkout job_stabilize_fix
    git merge job_stabilize_fix
    cd ../../
}

update(){
    git submodule update
}

build(){
    export AWS_PROFILE=default
    taskcat test run --lint-disable
    # taskcat test run
}

helm(){
    cd charts
    ./deploy.sh
}

lambda(){
    if [ ! -x functions/source/WebStack/bin/kubectl ] || [ ! -x functions/source/WebStack/bin/aws ]; then
        echo "Missing functions/source/WebStack/bin/{kubectl,aws} - see functions/source/WebStack/README.md to build them."
        exit 1
    fi
    rm -f functions/packages/WebStack/lambda.zip
    (cd functions/source/WebStack && zip -r ../../packages/WebStack/lambda.zip . -x '*__pycache__*')
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