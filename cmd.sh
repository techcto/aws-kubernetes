#!/bin/bash
args=("$@")

tag(){
    VERSION="${args[1]}"
    git tag -a v${VERSION} -m "tag release"
    git push --tags
}

init(){
    git submodule init
    git submodule add -f https://github.com/aws-quickstart/quickstart-aws-vpc.git ./submodules/quickstart-aws-vpc
    git submodule add -f https://github.com/aws-quickstart/quickstart-linux-bastion.git ./submodules/quickstart-linux-bastion
    git submodule add -f https://github.com/techcto/amazon-eks-ami.git ./submodules/amazon-eks-ami
    git submodule add -f https://github.com/aws-quickstart/quickstart-amazon-eks-nodegroup.git ./submodules/quickstart-amazon-eks-nodegroup
    git submodule add -f https://github.com/aws-quickstart/quickstart-amazon-eks.git ./submodules/quickstart-amazon-eks
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
    zip a functions/packages/WebStack/lambda.zip ./functions/source/WebStack/*
}

cft(){
    ./deploy.sh
}

$*