# AWS Quick Start: Kubernetes-UI — Web Dashboard for Kubernetes Clusters

Kubernetes UI is a fixed-monthly AWS Marketplace container product for Amazon
EKS. Subscribe once, then choose the deployment that matches your environment.
The software charge is separate from the AWS infrastructure used by your EKS
cluster.

<p align="center">
  <a href="https://aws.amazon.com/marketplace/pp/prodview-7uaseskhg4mla"><img src="https://raw.githubusercontent.com/solodev/aws/master/pages/images/Subscribe_Large.jpg" width="200" alt="Subscribe to Kubernetes UI in AWS Marketplace" /></a>
</p>

## Start here

1. Subscribe to **Kubernetes-UI: Web Dashboard for Kubernetes Clusters** in
   [AWS Marketplace](https://aws.amazon.com/marketplace/pp/prodview-7uaseskhg4mla).
2. Choose **View purchase options**, review pricing and terms, and accept the
   subscription. Wait until it is active in the AWS account that will run the
   cluster. CloudFormation does not subscribe to the product for you.
3. Select an available product version. Use the version-specific CloudFormation
   template linked in that version's usage instructions; a Git tag alone does
   not mean the Marketplace version is ready.
4. Choose **existing EKS cluster** below to install the dashboard, or **complete
   EKS stack** to create a cluster and install it. The launch links below open
   CloudFormation in `us-east-1`; select your supported target Region before
   creating the stack.
5. Review the template, parameters, IAM permissions, and infrastructure costs.
   Create the stack and wait for `CREATE_COMPLETE`.
6. Open the stack's **Outputs** tab and use `AdminUrl` where provided. For a
   private installation without an ingress address, use the port-forward
   procedure under **Verify the deployment**.

This is a seller-provided CloudFormation Quick Start. AWS Marketplace's former
built-in Helm Quick Launch experience was discontinued on March 1, 2026;
[standard Helm and seller deployment instructions remain supported](https://docs.aws.amazon.com/marketplace/latest/userguide/container-based-products.html).

## AWS reviewer test path

Use `us-east-1` and an existing EKS cluster for the smallest evaluation. The
container-image and Helm delivery options use the same four application images
and version. Test each option with the version submitted for review.

### Container image delivery

1. Subscribe and accept the product terms in the account that owns the test
   cluster. Select the **Container image** delivery option.
2. Open the version-specific **Existing EKS CloudFormation Quick Start** URL in
   that delivery option's usage instructions. Supply the cluster values listed
   under [Option 1](#option-1-add-kubernetes-ui-to-an-existing-eks-cluster).
3. Wait for `CREATE_COMPLETE`, then follow
   [Verify the deployment](#verify-the-deployment). Confirm all dashboard pods
   are ready and the UI opens through the documented port-forward. If testing
   SSO, supply your OIDC client settings and verify the configured login flow.
4. Delete the evaluation stack and wait for `DELETE_COMPLETE`. Confirm its Helm
   release and application pods are removed; the pre-existing EKS cluster must
   remain available.

### Helm chart delivery

1. Subscribe and accept the product terms in the account that owns the test
   cluster. Select the **Helm chart** delivery option.
2. Follow [Option 3](#option-3-test-the-ui-chart-on-any-existing-amazon-eks-cluster),
   setting `RELEASE_VERSION` to the version submitted for review. This creates
   the entitlement service account and installs the versioned OCI chart.
3. Follow [Verify the deployment](#verify-the-deployment). Confirm the four
   application components are running, entitlement registration succeeds, and
   the UI opens. Configure your OIDC client settings when testing SSO.
4. Follow [Remove the evaluation](#remove-the-evaluation) for the manual Helm
   path. Confirm the release is gone while the pre-existing EKS cluster remains
   available.

For either option, keep the Marketplace entitlement checks enabled. A failed
image pull or `CustomerNotEntitledException` requires checking the subscription,
AWS account, selected version, and service-account permissions before retrying.

## Why Kubernetes-UI continues

The upstream [Kubernetes Dashboard](https://github.com/kubernetes-retired/dashboard)
was archived because it lacked active maintainers and contributors. The
SpaceMade and Solodev team is continuing the project as **Kubernetes-UI**, with
plans for ongoing maintenance, security and dependency updates, and AWS
integration. The project retains the original Apache 2.0 licensing and author
attribution. Contributors are welcome in the
[application repository](https://github.com/techcto/kubernetes-ui).

## Choose a deployment

| Deployment | Use it when |
|---|---|
| Existing EKS Quick Start | You already have an EKS cluster and want CloudFormation to install only Kubernetes UI. |
| Complete EKS Quick Start | You want CloudFormation to create an EKS cluster, managed nodes, and Kubernetes UI. |
| Container images | Choose the container-image delivery option, then use a CloudFormation Quick Start or supply your own EKS manifests and IRSA configuration. |
| Helm chart for EKS | Choose the Helm delivery option and follow the `eksctl`/Helm commands below. |
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
  <a href="https://console.aws.amazon.com/cloudformation/home?region=us-east-1#/stacks/create/review?templateURL=https://kubernetes-ui.s3.amazonaws.com/cloudformation/kubernetes-ui.yaml&amp;stackName=kubernetes-ui"><img src="https://raw.githubusercontent.com/solodev/aws/master/pages/images/solodev-launch-btn.png" width="200" alt="Launch Kubernetes UI into an existing EKS cluster" /></a>
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
  <a href="https://console.aws.amazon.com/cloudformation/home?region=us-east-1#/stacks/create/review?templateURL=https://kubernetes-ui.s3.amazonaws.com/cloudformation/eks.yaml&amp;stackName=kubernetes-ui-eks"><img src="https://raw.githubusercontent.com/solodev/aws/master/pages/images/solodev-launch-btn.png" width="200" alt="Launch a complete Kubernetes UI EKS environment" /></a>
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
# subscribed buyer account; replace the placeholder before running Helm.
export RELEASE_VERSION='<available-marketplace-version>'
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

Wait for stack deletion to finish before removing shared network connectivity
or IAM access. The full EKS stack uninstalls its charts while the Kubernetes API
and worker nodes remain available, then cleans up cluster-tagged load balancers
and target groups before removing the nodes and control plane. If deletion
fails, inspect **Events**, correct the reported cause, and retry deletion; do
not retain stack resources simply to make the stack disappear.

Persistent application data follows its storage retention/reclaim policy.
Review and back up that data before deletion. The existing VPC and shared
network resources are not owned by this Quick Start and are not deleted.


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
