# Use Solodev kcmd.sh to Connect to Kubernetes Web UI (Dashboard)
The following steps will allow you to connect to the Kubernetes Web UI (Dashboard) through the use of Solodev's custom kcmd shell script (kcmd.sh). 

## Step 1: Gather Stack Outputs for your Solodev Managed Kubernetes for EKS
Click on the primary stack and view the "Outputs" tab. You will find details pertaining to the cluster's BastionIP, EKSClusterName, HelmLambdaArn, KubeConfigPath, and KubeManifestLambdaArn. Click on the "ControlPlane" stack to see details pertaining to the cluster's CADATA, ControlPlaneProvisionRoleArn, EKSEndpoint, EKSName, EksArn, and KubeConfigPath.

Save or take note of these output values as you will need them when launching Solodev EKS on the cluster.

<table>
	<tr>
		<td><img src="https://raw.githubusercontent.com/solodev/aws/master/pages/images/install/outputs-solodev-cms-eks-1-15.jpg" /></td>
	</tr>
</table>

## Step 2: Download and Configure kcmd.sh
Details such as the number of services and pods running on your EKS cluster can be accessed via the <a href="https://kubernetes.io/docs/tasks/access-application-cluster/web-ui-dashboard/">Kubernetes Dashboard</a>. Solodev has simplified getting this up and running through the use of commands in a custom kcmd shell script.

<b>Prerequisites:</b> These instructions presume you already have installed <a href="https://kubernetes.io/docs/tasks/tools/install-kubectl/">kubectl</a>, <a href="https://aws.amazon.com/cli/">aws cli</a>, <a href="https://docs.aws.amazon.com/eks/latest/userguide/install-aws-iam-authenticator.html">aws-iam-authenticator</a>, <a href="https://stedolan.github.io/jq/">jq</a> (<a href="https://chocolatey.org/packages/jq">windows install instructions</a>), and <a href="https://github.com/helm/helm">kubernetes-helm</a>.

Access and download the <a href="https://github.com/techcto/quickstart-solodev-eks/blob/master/scripts/kcmd.sh">Solodev EKS custom kcmd.sh script</a>. Place the shell script inside a directory you will use to access your Kubernetes cluster.

Modify lines 8-9. The values will correspond to your stack's output.

<pre>
#GET VALUES FROM CLOUDFORMATION OUTPUT OF EKS STACK
export EKSClusterName=""
export SysOpsAdminRoleArn=""
</pre>

Modify lines 12-15. REGION corresponds to the <a href="https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/Concepts.RegionsAndAvailabilityZones.html">AWS Region</a> where your EKS cluster is located. USER_ARN corresponds to the User ARN of your <a href="https://docs.aws.amazon.com/IAM/latest/UserGuide/id_users.html">AWS IAM User</a>. KEY corresponds to the <a href="https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-key-pairs.html">EC2 Key Pair</a> specified during the EKS cluster launch. BASTION corresponds to the Bastion IP which can be found in the stack's output.

<pre>
export REGION=""
export USER_ARN=""
export KEY=""
export BASTION=""
</pre>

Configure a <a href="https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-profiles.html">AWS CLI profile</a> (if one has not already been created). From your terminal, run the following command. Change "PROFILENAME" to a unique profile name that you want to use with this project. AWS CLI will ask for the ACCESS and SECRET keys for your AWS IAM user as well as the region you want configured for the profile.

<pre>
aws configure --profile PROFILENAME
</pre>

With your AWS CLI profile created, modify line 17 to reference the PROFILENAME you've created.

<pre>
export AWS_PROFILE=""
</pre>

## Step 3: Connect to Kubernetes Dashboard
With the kcmd.sh script properly configured, you can initialize a kubeconfig file by running the following command. Run this from the root of the directory that stores your kcmd.sh file.

<pre>
./kcmd.sh init
</pre>

This will generate the necessary config file that the kcmd.sh script uses to connect to your EKS cluster. With the kubeconfig file in place, run the following command to install the Kubernetes dashboard and open up a proxy to the cluster itself. Run this likewise from the roof of the directory that stores your kcmd.sh file.

<pre>
./kcmd.sh proxy
</pre>

Keep the proxy running within your terminal (open another terminal window if you need to run additional commands) and access the Kubernetes dasboard by going to the following URL:

<pre>
 http://localhost:8080/#/overview?namespace=_all
</pre>

<table>
	<tr>
		<td><img src="https://raw.githubusercontent.com/solodev/aws/master/pages/images/install/kubernetes-dashboard-solodev-cms-eks.jpg" /></td>
	</tr>
</table>