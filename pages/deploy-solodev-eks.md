# Launch Solodev Managed Kubernetes for EKS

## Step 1: Configure Your VPC and EC2 Key Pair
Please note that both a <a href="http://docs.aws.amazon.com/AmazonVPC/latest/UserGuide/VPC_Introduction.html">VPC</a> and <a href="http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/concepts.html">EC2 Key Pair</a> must be configured within the region you intend to launch your stack.

While not required, <b><i>it is strongly recommended</i></b> to create a new VPC using the <a href="https://github.com/techcto/solodev-aws/blob/master/aws/corp-vpc.yaml">AWS VPC by Solodev CloudFormation Template</a>. Click the button below to launch the AWS VPC by Solodev.

<p align="center"><a href="https://console.aws.amazon.com/cloudformation/home?region=us-east-1#/stacks/new?stackName=solodev-vpc&templateURL=https://solodev-aws-ha.s3.amazonaws.com/aws/corp-vpc.yaml"><img src="https://raw.githubusercontent.com/solodev/aws/master/pages/images/solodev-launch-btn.png" width="200" /></a></p>


## Step 2: Launch your CloudFormation Stack
<p align="center"><a href="https://console.aws.amazon.com/cloudformation/home?region=us-east-1#/stacks/new?stackName=solodev-eks&templateURL=https://solodev-quickstarts.s3.amazonaws.com/eks/1.15/templates/solodev-eks-master-existing-vpc.template.yaml"><img src="https://raw.githubusercontent.com/solodev/aws/master/pages/images/solodev-launch-btn.png" width="200" /></a></p>

## Step 3: Fill Out the CloudFormation Stack Wizard
<strong>Continue with the preselected CloudFormation Template</strong><br />
The Amazon S3 template URL (used for the CloudFormation configuration) should be preselected. Click "Next" to continue.

<strong>Specify Details</strong><br />
The following parameters must be configured to launch your Solodev Managed Kubernetes for EKS CloudFormation stack:

<strong>Kubernetes WebStack add-ins note:</strong> the Solodev Managed Kubernetes for EKS cluster contains a set of WebStack add-ins specifically configured for production-ready web development applications. These add-ins include CloudFormation templates for the following:
<ul>
	<li>Provision <a href="https://www.weave.works/docs/net/latest/kubernetes/kube-addon/">Weave CNI</a></li>
	<li>Provision <a href="https://kubernetes.github.io/ingress-nginx/">Nginx proxy</a></li>
	<li>Provision external DNS management through Amazon Route 53</li>
	<li>Enabled the <a href="https://kubernetes.io/docs/tasks/access-application-cluster/web-ui-dashboard/">Kubernetes dashboard</a></li>
	<li>Enable secure access tokens</li>
	<li>Optional installation of Solodev CMS on the cluster upon deployment</li>
</ul>

<table>
	<tr>
		<td><img src="https://raw.githubusercontent.com/solodev/aws/master/pages/images/install/parameters-solodev-cms-eks-1-15.jpg" /></td>
	</tr>
</table>

<table>
	<tr>
		<th width="33%"><strong>Parameter</strong></th>
		<th width="600px"><strong>Description</strong></th>
	</tr>
	<tr>
		<td>Stack name</td>
		<td>The name of your stack (set to "solodev-eks" by default). Please note, the name must be all lowercase.</td>
	</tr>
</table>

<table>
	<tr>
		<td colspan="2"><strong>Network configuration</strong></td>
	</tr>
	<tr>
		<td width="33%">VPC ID</td>
		<td width="600px">The ID of your existing VPC (e.g., vpc-0343606e)</td>
	</tr>
	<tr>
		<td>Private subnet 1 ID</td>
		<td>The ID of the private subnet in Availability Zone 1 in your existing VPC (e.g., subnet-fe9a8b32)</td>
	</tr>
	<tr>
		<td>Private subnet 2 ID</td>
		<td>The ID of the private subnet in Availability Zone 2 in your existing VPC (e.g., subnet-be8b01ea)</td>
	</tr>
	<tr>
		<td>Private subnet 3 ID</td>
		<td>The ID of the private subnet in Availability Zone 3 in your existing VPC (e.g., subnet-abd39039)</td>
	</tr>
	<tr>
		<td>Public subnet 1 ID</td>
		<td>The ID of the public subnet in Availability Zone 1 in your existing VPC (e.g., subnet-a0246dcd)</td>
	</tr>	
	<tr>
		<td>Public subnet 2 ID</td>
		<td>The ID of the public subnet in Availability Zone 2 in your existing VPC (e.g., subnet-b1236eea)</td>
	</tr>
	<tr>
		<td>Public subnet 3 ID</td>
		<td>The ID of the public subnet in Availability Zone 3 in your existing VPC (e.g., subnet-c3456aba)</td>
	</tr>
	<tr>
		<td>Allowed external access CIDR</td>
		<td>The CIDR IP range that is permitted to access the instances. We recommend that you set this value to a trusted IP range.</td>
	</tr>  
</table>

<table>
	<tr>
		<td colspan="2"><strong>Amazon EC2 configuration</strong></td>
	</tr>
	<tr>
		<td width="33%">SSH key name</td>
		<td width="600px">The name of an existing public/private key pair, which allows you to securely connect to your instance after it launches</td>
	</tr>
	<tr>
		<td width="33%">Provision Bastion Host</td>
		<td width="600px">Skip creating a bastion host by setting this is set to Disabled.</td>
	</tr>
</table>

<table>
	<tr>
		<td colspan="2"><strong>Amazon EKS configuration</strong></td>
	</tr>
	<tr>
		<td width="33%">Nodes instance type</td>
		<td width="600px">The type of EC2 instance for the node instances.</td>
	</tr>
	<tr>
		<td>Number of nodes</td>
		<td>The number of Amazon EKS node instances. The default is one for each of the three Availability Zones.</td>
	</tr> 
	<tr>
		<td>Node group name</td>
		<td>The name for EKS node group.</td>
	</tr>
	<tr>
		<td>Node volume size</td>
		<td>The size for the node's root EBS volumes.</td>
	</tr>
	<tr>
		<td>Managed Node Group</td>
		<td>Choose if you want to use a managed node group. If you select "yes", you must select Kubernetes version 1.14 or higher.</td>
	</tr>
	<tr>
		<td>Managed Node Group AMI Type</td>
		<td>Select one of the two AMI Types for your Managed Node Group (Only applies if you selected Managed Node Group "yes". ). GPU instance types should use the AL2_x86_64_GPU AMI type, which uses the Amazon EKS-optimized Linux AMI with GPU support. Non-GPU instances should use the AL2_x86_64 AMI type, which uses the Amazon EKS-optimized Linux AMI.</td>
	</tr>
	<tr>
		<td>Additional EKS admin ARN (IAM User)</td>
		<td>[OPTIONAL] IAM user Amazon Resource Name (ARN) to be granted admin access to the EKS cluster</td>
	</tr>
	<tr>
		<td>Additional EKS admin ARN (IAM Role)</td>
		<td>[OPTIONAL] IAM role Amazon Resource Name (ARN) to be granted admin access to the EKS cluster</td>
	</tr>
	<tr>
		<td>Kubernetes version</td>
		<td>The Kubernetes control plane version.</td>
	</tr>          
</table>

<table>
	<tr>
		<td colspan="2"><strong>Optional Kubernetes WebStack add-ins</strong></td>
	</tr>
	<tr>
		<td width="33%">ProvisionWeave</td>
		<td width="600px">Choose Enabled to enable Weave CNI. (Note: This will disable the default Amazon CNI)</td>
	</tr>
	<tr>
		<td width="33%">ProvisionNginxIngress</td>
		<td width="600px">Choose Enabled to enable Inginx Proxy</td>
	</tr>
	<tr>
		<td width="33%">ProvisionExternalDNS</td>
		<td width="600px">Choose Enabled to enable External DNS with Route 53</td>
	</tr>
	<tr>
		<td width="33%">ProvisionDashboard</td>
		<td width="600px">Choose Enabled to enable Kubernetes Dashboard</td>
	</tr>
	<tr>
		<td width="33%">ProvisionAccessToken</td>
		<td width="600px">Choose Enabled to get secure access token</td>
	</tr>
	<tr>
		<td width="33%">ProvisionCMS</td>
		<td width="600px">Choose Enabled to enable Solodev CMS</td>
	</tr>
</table>

<table>
	<tr>
		<td colspan="2"><strong>Optional Kubernetes add-ins</strong></td>
	</tr>
	<tr>
		<td width="33%">Cluster autoscaler</td>
		<td width="600px">Choose Enabled to enable Kubernetes cluster autoscaler.</td>
	</tr>
	<tr>
		<td>EFS storage class</td>
		<td>Choose Enabled to enable EFS storage class, which will create the required EFS volume.</td>
	</tr>
	<tr>
		<td>EFS performance mode</td>
		<td>Choose maxIO mode to provide greater IOPS with an increased latency. Only has an effect when EfsStorageClass is enabled.</td>
	</tr>
	<tr>
		<td>EFS throughput mode</td>
		<td>Choose provisioned for throughput that is not dependent on the amount of data stored in the file system. Only has an effect when EfsStorageClass is enabled.</td>
	</tr>
	<tr>
		<td>EFS provisioned throughput in Mibps</td>
		<td>Set to 0 if EfsThroughputMode is set to bursting. Only has an effect when EfsStorageClass is enabled.</td>
	</tr>        
</table>

<table>
	<tr>
		<td colspan="2"><strong>AWS Quick Start configuration</strong></td>
	</tr>
	<tr>
		<td width="33%">Quick Start S3 bucket name</td>
		<td width="600px">S3 bucket name for the Quick Start assets. This string can include numbers, lowercase letters, uppercase letters, and hyphens (-). It cannot start or end with a hyphen (-).</td>
	</tr>
	<tr>
		<td>Quick Start S3 key prefix</td>
		<td>S3 key prefix for the Quick Start assets. Quick Start key prefix can include numbers, lowercase letters, uppercase letters, hyphens (-), dots(.) and forward slash (/).</td>
	</tr>
	<tr>
		<td>Quick Start S3 bucket region</td>
		<td>The AWS Region where the Quick Start S3 bucket (QSS3BucketName) is hosted. When using your own bucket, you must specify this value.</td>
	</tr>
	<tr>
		<td>Lambda zips bucket name</td>
		<td>[OPTIONAL] The name of the S3 bucket where the Lambda zip files should be placed. If you leave this parameter blank, an S3 bucket will be created.</td>
	</tr>    
</table>

<table>
	<tr>
		<td colspan="2"><strong>Other parameters</strong></td>
	</tr>
	<tr>
		<td width="33%">EKSClusterLoggingTypes</td>
		<td width="600px">EKS cluster control plane logs to be exported to CloudWatch Logs.</td>
	</tr>
	<tr>
		<td width="33%">EKSEncryptSecrets</td>
		<td width="600px">Envelope encryption of Kubernetes secrets using KMS.</td>
	</tr>  
	<tr>
		<td width="33%">EKSEncryptSecretsKmsKeyArn</td>
		<td width="600px">[OPTIONAL] KMS key to use for envelope encryption of Kubernetes secrets. If this parameter is omitted A key will be created for the cluster. The CMK must be symmetric, created in the same region as the cluster, and if the CMK was created in a different account, the user must have access to the CMK.</td>
	</tr>  
	<tr>
		<td width="33%">EKSPrivateAccessEndpoint</td>
		<td width="600px">Configure access to the Kubernetes API server endpoint from within your VPC. If this is disabled, EKSPublicAccessEndpoint must be enabled.</td>
	</tr>  
	<tr>
		<td width="33%">EKSPublicAccessCIDRs</td>
		<td width="600px">The public CIDR IP ranges that are permitted to access the Kubernetes API. These values are only used if EKSPublicAccessEndpoint is enabled. Can't contain private IP ranges.</td>
	</tr>  
	<tr>
		<td width="33%">EKSPublicAccessEndpoint</td>
		<td width="600px">Configure access to the Kubernetes API server endpoint from outside of your VPC.</td>
	</tr>  
	<tr>
		<td width="33%">HttpProxy</td>
		<td width="600px">HTTP(S) proxy configuration, if provided all worker nodes and pod egress traffic will go use this proxy. Example: http://10.101.0.100:3128/</td>
	</tr>    		       
</table>

<strong>Specify Options</strong><br />
Generally speaking, no additional options need to be configured. If you are experiencing continued problems deploying, disable "Rollback on failure" under the "Advanced" options. This will allow for further troubleshooting if necessary. Click on the "Next" button to continue.

<table>
	<tr>
		<td><img src="https://raw.githubusercontent.com/solodev/aws/master/pages/images/install/options-solodev-cms-eks.jpg" /></td>
	</tr>
</table>

<strong>Review</strong><br />
Review all CloudFront details and options. Ensure that the "I acknowledge that AWS CloudFormation might create IAM resources with custom names" checkbox is selected as well as the "I acknowledge that AWS CloudFormation might require the following capability: CAPABILITY_AUTO_EXPAND" checkbox. Click on the "Create" button to launch your stack.

<table>
	<tr>
		<td><img src="https://raw.githubusercontent.com/solodev/aws/master/pages/images/install/review-solodev-cms-eks-1-15.jpg" /></td>
	</tr>
</table>

## Step 4: Monitor the CloudFormation Stack Creation Process
Upon launching your CloudFormation stack, you will be able to monitor the installation logs under the "Events" tab. The CloudFormation template will launch several stacks related to your Solodev instance. If you encounter any failures during this time, please visit the <a href="https://github.com/solodev/aws/wiki/Common-Issues">Common Issues</a> page to begin troubleshooting.

<table>
	<tr>
		<td><img src="https://raw.githubusercontent.com/solodev/aws/master/pages/images/install/monitor-solodev-cms-eks.jpg" /></td>
	</tr>
</table>

## Launch Optional Apps on your Solodev Managed Kubernetes for EKS
With your EKS stack successfully launched, you can proceed to launch additional apps such as the <a href="https://github.com/techcto/quickstart-solodev-eks/blob/master/pages/deploy-kubernetes-web-ui.md">Kubernetes Web UI (Dashboard)</a>. If you enabled the "ProvisionDashboard" parameter above, find instructions for connecting to the Kubernetes Web UI (Dashboard) via the Solodev's custom <a href="https://github.com/techcto/quickstart-solodev-eks/blob/master/pages/kcmd.md">kcmd.sh script</a>. Return to the <a href="https://github.com/techcto/quickstart-solodev-eks#launch-apps-on-your-managed-kubernetes-cluster">repository home</a> to view available apps for available for installation.

---
© 2020 Solodev. All rights reserved worldwide. And off planet. 

Errors or corrections? Email us at help@solodev.com.

---
Visit [solodev.com](https://www.solodev.com/) to learn more. <img src="https://www.google-analytics.com/collect?v=1&tid=UA-3849724-1&cid=1&t=event&ec=github_aws&ea=main&cs=github&cm=github&cn=github_aws" />
