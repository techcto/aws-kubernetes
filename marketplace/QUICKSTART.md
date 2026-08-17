# Kubernetes UI on AWS Marketplace

Kubernetes UI is a fixed-monthly AWS Marketplace container product for Amazon
EKS. Subscribe once, then choose the deployment that matches your environment.
The software charge is separate from the AWS infrastructure used by your EKS
cluster.

<p align="center">
  <a href="https://aws.amazon.com/marketplace/pp?sku=3hyqc0li3ot9242x6e6t0rxoe"><img src="https://raw.githubusercontent.com/solodev/aws/master/pages/images/Subscribe_Large.jpg" width="200" alt="Subscribe to Kubernetes UI in AWS Marketplace" /></a>
</p>

## Choose a deployment

| Deployment | Use it when |
|---|---|
| Existing EKS Quick Start | You already have an EKS cluster and want CloudFormation to install only Kubernetes UI. |
| Complete EKS Quick Start | You want CloudFormation to create an EKS cluster, managed nodes, and Kubernetes UI. |
| `eksctl` and Helm | You want to inspect and run every installation command yourself. |
| EKS add-on | The limited Kubernetes UI add-on is available for your cluster version and account. |

The existing-cluster Quick Start is the smallest CloudFormation test path. It
does not replace, resize, or delete the EKS cluster. It creates an installer
Lambda, an EKS access entry, the Marketplace metering role, and the Kubernetes
UI Helm release.

## Prerequisites

- An AWS account subscribed to Kubernetes UI.
- Amazon EKS in an AWS Marketplace-supported Region.
- At least one schedulable EKS worker node.
- Outbound HTTPS access from the cluster for Marketplace ECR and entitlement
  registration.
- An IAM OIDC provider associated with the cluster.
- For the existing-cluster CloudFormation option, EKS access-entry
  authentication (`API` or `API_AND_CONFIG_MAP`) must be enabled.
- For CloudFormation, permission to create IAM roles, EKS access entries,
  Lambda functions, security-group rules, nested stacks, and Helm resources.

## Option 1: Add Kubernetes UI to an existing EKS cluster

Select the AWS Region containing the EKS cluster, then launch the standalone
template.

<p align="center">
  <a href="https://console.aws.amazon.com/cloudformation/home#/stacks/create/review?templateURL=https://kubernetes-ui.s3.amazonaws.com/cloudformation/kubernetes-ui.yaml&amp;stackName=kubernetes-ui"><img src="https://raw.githubusercontent.com/solodev/aws/master/pages/images/solodev-launch-btn.png" width="200" alt="Launch Kubernetes UI into an existing EKS cluster" /></a>
</p>

Use these commands to obtain the required values:

```bash
export AWS_REGION=us-east-1
export CLUSTER_NAME=my-eks-cluster

aws eks describe-cluster --region "$AWS_REGION" --name "$CLUSTER_NAME" \
  --query 'cluster.resourcesVpcConfig.vpcId' --output text

aws eks describe-cluster --region "$AWS_REGION" --name "$CLUSTER_NAME" \
  --query 'cluster.resourcesVpcConfig.clusterSecurityGroupId' --output text

aws eks describe-cluster --region "$AWS_REGION" --name "$CLUSTER_NAME" \
  --query 'cluster.identity.oidc.issuer' --output text

aws eks describe-cluster --region "$AWS_REGION" --name "$CLUSTER_NAME" \
  --query 'cluster.resourcesVpcConfig.subnetIds' --output text
```

In the CloudFormation form provide:

- `ClusterName` — the existing EKS cluster name.
- `VPCID` — the cluster VPC.
- `PrivateSubnetIDs` — private subnets with access to the EKS API and outbound
  AWS APIs. Do not use public subnets for the installer Lambda.
- `ClusterSecurityGroupID` — the EKS-created cluster security group.
- `OIDCIssuerURL` — the complete `https://` issuer returned above.
- Optional OIDC values when Kubernetes UI should use your private SSO service.

Keep the prefilled release and Marketplace product-code parameters unchanged.
CloudFormation prompts for acknowledgement that the template creates IAM
resources.

## Option 2: Launch the complete EKS stack

Use this path when there is no existing cluster. It creates an EKS control
plane, managed node group, access entries, and Kubernetes UI in an existing
VPC.

<p align="center">
  <a href="https://console.aws.amazon.com/cloudformation/home#/stacks/create/review?templateURL=https://kubernetes-ui.s3.amazonaws.com/cloudformation/eks.yaml&amp;stackName=kubernetes-ui-eks"><img src="https://raw.githubusercontent.com/solodev/aws/master/pages/images/solodev-launch-btn.png" width="200" alt="Launch a complete Kubernetes UI EKS environment" /></a>
</p>

Provide a VPC and private subnets in at least two Availability Zones. Public
subnets are needed only for public load balancers. Keep `IamOidcProvider`
enabled because the Kubernetes UI auth pod uses IRSA to verify the Marketplace
subscription.

For a minimal evaluation without DNS, disable ExternalDNS, ingress, and the
load-balancer controller. Access the service with `kubectl port-forward` as
shown below.

## Option 3: Test the UI chart on any existing Amazon EKS cluster

This path is useful for AWS review and for customers who do not want the full
CloudFormation stack. It installs only the Marketplace UI chart and does not
modify the cluster control plane or node groups. Install AWS CLI, `kubectl`,
`eksctl`, and Helm 3 first.

```bash
export AWS_REGION=us-east-1
export CLUSTER_NAME=my-eks-cluster
# Replace this with the version AWS Marketplace shows as available to the
# subscribed buyer account. The repository's current release is shown here.
export RELEASE_VERSION=1.1.2
export MP_ECR=709825985650.dkr.ecr.us-east-1.amazonaws.com

aws eks update-kubeconfig \
  --region "$AWS_REGION" \
  --name "$CLUSTER_NAME"

eksctl utils associate-iam-oidc-provider \
  --region "$AWS_REGION" \
  --cluster "$CLUSTER_NAME" \
  --approve

kubectl create namespace kubernetes-dashboard \
  --dry-run=client -o yaml | kubectl apply -f -

eksctl create iamserviceaccount \
  --region "$AWS_REGION" \
  --cluster "$CLUSTER_NAME" \
  --namespace kubernetes-dashboard \
  --name kubernetes-dashboard-auth \
  --attach-policy-arn arn:aws:iam::aws:policy/AWSMarketplaceMeteringRegisterUsage \
  --approve

aws ecr get-login-password --region "$AWS_REGION" | \
  helm registry login --username AWS --password-stdin "$MP_ECR"

helm upgrade --install kubernetes-dashboard \
  "oci://$MP_ECR/solodev/kubernetes-dashboard" \
  --version "$RELEASE_VERSION" \
  --namespace kubernetes-dashboard \
  --create-namespace \
  --set auth.serviceAccount.create=false \
  --set auth.serviceAccount.name=kubernetes-dashboard-auth
```

AWS Marketplace supplies the service-account name automatically when the Helm
delivery is launched from the buyer experience. The explicit `eksctl` command
above creates the equivalent IRSA configuration for a manual installation.
The subscribed account must be the AWS profile used by both `eksctl` and the
ECR login. Set `AWS_PROFILE` before running the commands when it is not the
default profile.

## Option 4: Install as an EKS add-on

When the limited add-on delivery is visible in your account, open the EKS
cluster, choose **Add-ons**, then **Get more add-ons**, and select Kubernetes
UI from AWS Marketplace. Subscribe before installing. Add-on availability is
independent from the primary Helm delivery and may support fewer Kubernetes
versions while AWS validation is in progress.

## Verify the deployment

```bash
kubectl get nodes
kubectl get pods -n kubernetes-dashboard
helm status kubernetes-dashboard -n kubernetes-dashboard
kubectl logs -n kubernetes-dashboard \
  -l app.kubernetes.io/name=kubernetes-dashboard-auth --all-containers --tail=100
kubectl port-forward -n kubernetes-dashboard svc/kubernetes-dashboard-web 8443:8000
```

In a second terminal, verify that the UI responds, then open it in a browser:

```bash
curl --fail --head http://127.0.0.1:8443
```

Open <http://localhost:8443>. This confirms the chart, Marketplace images,
services, and UI are running on the existing EKS cluster. The auth container must successfully register
the subscribed account before login is available. If the account is not
subscribed, the pod reports `CustomerNotEntitledException` and does not expose
the application.

If the chart version or service name differs, inspect the release with:

```bash
helm list -n kubernetes-dashboard
kubectl get services -n kubernetes-dashboard
kubectl get pods -n kubernetes-dashboard -o wide
```

## Remove the evaluation

For CloudFormation deployments, delete only the stack you launched. Deleting
the existing-cluster Quick Start removes Kubernetes UI and its installer
resources but leaves the existing EKS cluster intact. Deleting the complete
EKS stack also deletes the cluster and node group created by that stack.

For a manual Helm deployment:

```bash
helm uninstall kubernetes-dashboard -n kubernetes-dashboard
eksctl delete iamserviceaccount \
  --region "$AWS_REGION" \
  --cluster "$CLUSTER_NAME" \
  --namespace kubernetes-dashboard \
  --name kubernetes-dashboard-auth
kubectl delete namespace kubernetes-dashboard
```

## Support

- Source and issues: <https://github.com/techcto/aws-kubernetes>
- Marketplace release details: [README](README.md)
