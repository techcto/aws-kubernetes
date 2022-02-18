# Deploy Solodev CMS on an EKS Cluster via CloudFormation
The following steps will allow you to deploy Solodev CMS to an existing EKS cluster by launching a new stack via AWS CloudFormation. Additional installation methods are available including <a href="https://github.com/techcto/charts">via Helm Charts</a>.

## Step 1: Subscribe on the AWS Marketplace
If you have not already done so, you'll first need to subscribe to Solodev on the <a href="https://aws.amazon.com/marketplace/pp/B07XV951M6">AWS Marketplace.</a> Click the button below to get started: 
<table>
	<tr>
		<td width="60%"><a href="https://aws.amazon.com/marketplace/pp/B07XV951M6"><img src="https://raw.githubusercontent.com/solodev/aws/master/pages/images/AWS_Marketplace_Logo.jpg" /></a></td>
		<td><a href="https://aws.amazon.com/marketplace/pp/B07XV951M6"><img src="https://raw.githubusercontent.com/solodev/aws/master/pages/images/Subscribe_Large.jpg" /></a></td>
	</tr>
</table>

## Step 2: Gather EKS Stack Outputs for Solodev CMS
Take note of several of your <a href="deploy-solodev-eks.md#step-6-gather-stack-outputs-for-solodev-eks">EKS stack outputs</a>. You will need these output values when launching Solodev CMS on the EKS cluster.

Click on the primary stack and view the "Outputs" tab. You will find details pertaining to the cluster's BastionIP, EKSClusterName, HelmLambdaArn, KubeConfigPath, and KubeManifestLambdaArn. 

<table>
	<tr>
		<td><img src="https://raw.githubusercontent.com/solodev/AWS-Launch-Pad/master/pages/images/install/outputs-solodev-cms-eks.jpg" /></td>
	</tr>
</table>


## Step 3: Launch your CloudFormation Stack
<p align="center"><a href="https://console.aws.amazon.com/cloudformation/home?region=us-east-1#/stacks/new?stackName=solodev-cms&templateURL=https://solodev-quickstarts.s3.amazonaws.com/eks/1.15/templates/solodev-eks-cms.template.yaml"><img src="https://raw.githubusercontent.com/solodev/aws/master/pages/images/solodev-launch-btn.png" width="200" /></a></p>

## Step 4: Fill Out the CloudFormation Stack Wizard
<strong>Continue with the preselected CloudFormation Template</strong><br />
The Amazon S3 template URL (used for the CloudFormation configuration) should be preselected. Click "Next" to continue.

<strong>Specify Details</strong><br />
The following parameters must be configured to launch your Solodev DCX CloudFormation stack:

<table>
	<tr>
		<td><img src="https://raw.githubusercontent.com/solodev/AWS-Launch-Pad/master/pages/images/install/parameters-solodev-cms-eks-app.jpg" /></td>
	</tr>
</table>

<table>
	<tr>
		<th width="33%"><strong>Parameter</strong></th>
		<th width="600px"><strong>Description</strong></th>
	</tr>
	<tr>
		<td>Stack name</td>
		<td>The name of your stack (set to "solodev-cms" by default). Please note, the name must be all lowercase.</td>
	</tr>
</table>

<table>
	<tr>
		<td colspan="2"><strong>User Settings</strong></td>
	</tr>
	<tr>
		<td width="33%">AdminUser</td>
		<td width="600px">The Solodev admin username</td>
	</tr>
	<tr>
		<td>AdminPassword</td>
		<td>The Solodev admin password</td>
	</tr>
</table>

<table>
	<tr>
		<td colspan="2"><strong>Advanced Settings</strong></td>
	<tr>
		<td width="33%">DatabaseName</td>
		<td width="600px">The Solodev database name</td>
	</tr>
	<tr>
		<td>DatabasePassword</td>
		<td>The database root password</td>
	</tr>
	<tr>
		<td>AppSecret</td>
		<td>Secret Key for app encryption</td>
	</tr>          
</table>

<table>
	<tr>
		<td colspan="2"><strong>EKS Cluster</strong></td>
	<tr>
		<td width="33%">HelmLambdaArn</td>
		<td width="600px">The HelmLambdaArn found in the <a href="deploy-solodev-eks.md#step-6-gather-stack-outputs-for-solodev-eks">outputs on your EKS stack</a></td>
	</tr>
	<tr>
		<td>KubeConfigPath</td>
		<td>The KubeConfigPath found in the <a href="deploy-solodev-eks.md#step-6-gather-stack-outputs-for-solodev-eks">outputs on your EKS stack</td>
	</tr> 
	<tr>
		<td>KubeConfigKmsContext</td>
		<td>Defaults to "EKSQuickStart".</td>
	</tr>
	<tr>
		<td>ServiceRoleName</td>
		<td>Defaults to "aws-serviceaccount".</td>
	</tr>  	       
</table>

<strong>Specify Options</strong><br />
Generally speaking, no additional options need to be configured. If you are experiencing continued problems installing the software, disable "Rollback on failure" under the "Advanced" options. This will allow for further troubleshooting if necessary. Click on the "Next" button to continue.

<table>
	<tr>
		<td><img src="https://raw.githubusercontent.com/solodev/AWS-Launch-Pad/master/pages/images/install/options-solodev-cms-eks-app.jpg" /></td>
	</tr>
</table>

<strong>Review</strong><br />
Review all CloudFront details and options. Click on the "Create" button to launch your stack.

<table>
	<tr>
		<td><img src="https://raw.githubusercontent.com/solodev/AWS-Launch-Pad/master/pages/images/install/review-solodev-cms-eks-app.jpg" /></td>
	</tr>
</table>

## Step 5: Monitor the CloudFormation Stack Creation Process
Upon launching your CloudFormation stack, you will be able to monitor the installation logs under the "Events" tab. The CloudFormation template will launch multiple stacks related to your Solodev instance. If you encounter any failures during this time, please visit the <a href="https://github.com/solodev/AWS-Launch-Pad/wiki/Common-Issues">Common Issues</a> page to begin troubleshooting.

<table>
	<tr>
		<td><img src="https://raw.githubusercontent.com/solodev/AWS-Launch-Pad/master/pages/images/install/monitor-solodev-cms-eks-app.jpg" /></td>
	</tr>
</table>

## Step 6: Accessing the UI endpoint address
After the creation of the CloudFormation stack is completed, users must locate the CNAME for the UI endpoint address to launch an instance of Solodev. This process involves connecting to the Kubernetes dashboard. Please refer to <a href="deploy-solodev-eks.md#step-8-connect-to-kubernetes-dashboard">Section 8: Connect to Kubernetes Dashboard</a> on the Launch Solodev Kubernetes for EKS page for more information. 

Once the user connects to the Kubernetes dashboard, click the select box under Namespace:

<table>
	<tr>
		<td><img src="https://raw.githubusercontent.com/solodev/aws/master/pages/images/install/ui-endpoint-eks-1.jpg" /></td>
	</tr>
</table>

Choose solodev-dcx:

<table>
	<tr>
		<td><img src="https://raw.githubusercontent.com/solodev/aws/master/pages/images/install/ui-endpoint-eks-2.jpg" /></td>
	</tr>
</table>

In the Kubernetes dashboard choose services:

<table>
	<tr>
		<td><img src="https://raw.githubusercontent.com/solodev/aws/master/pages/images/install/ui-endpoint-eks-3.jpg" /></td>
	</tr>
</table>

Click the external endpoint CNAME associated with the instance name for port 80:

<table>
	<tr>
		<td><img src="https://raw.githubusercontent.com/solodev/aws/master/pages/images/install/ui-endpoint-eks-4.jpg" /></td>
	</tr>
</table>

Login to Solodev:

<table>
	<tr>
		<td><img src="https://raw.githubusercontent.com/solodev/aws/master/pages/images/install/ui-endpoint-eks-5.jpg" /></td>
	</tr>
</table>

---
© 2020 Solodev. All rights reserved worldwide. And off planet. 

Errors or corrections? Email us at help@solodev.com.

---
Visit [solodev.com](https://www.solodev.com/) to learn more. <img src="https://www.google-analytics.com/collect?v=1&tid=UA-3849724-1&cid=1&t=event&ec=github_aws&ea=main&cs=github&cm=github&cn=github_aws" />
