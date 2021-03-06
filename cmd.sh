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

update(){
    git submodule update
}

build(){
    export AWS_PROFILE=default
    taskcat test run --lint-disable
    # taskcat test run
}

cft(){
    ./deploy.sh
}

$*