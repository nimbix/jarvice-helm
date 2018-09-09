# JARVICE Helm chart deployment scripts

This directory contains helper scripts for JARVICE Helm chart deployments.

See README.md in the top level of this repository for more in depth details
on JARVICE Helm chart installations:
https://github.com/nimbix/jarvice-helm

------------------------------------------------------------------------------

## Code repository of the JARVICE helm chart

It is first necessary to clone this git repository to a client machine:

```bash
$ git clone https://github.com/nimbix/jarvice-helm.git
```

## `jarvice-deploy2eks`

The `jarvice-deploy2eks` script can be used to quickly deploy JARVICE into
an Amazon EKS cluster with a single command line.

It will first verify and, if needed, install software components needed for
interacting with AWS and EKS.  Subsequently, it will create and initialize
an EKS cluster.  That process will take approximately 15 minutes.

Next, it will install kubernetes plugins and initialize/configure Tiller
to enable installation of the JARVICE helm chart into the cluster.  Lastly,
it will `helm install` the JARVICE chart and print out URLs for accessing
the JARVICE installation.  It will take around five minutes for the JARVICE
installation and deployment rollout.  The entire process combined,
from start to finish, will be approximately 20 minutes.

Execute `jarvice-deploy2eks` with `--help` to see all of the current command
line options:
```bash
$ ./scripts/jarvice-deploy2eks --help
Usage: ./scripts/jarvice-deploy2eks [options]

Available [options]:
  --registry-username <username>    Docker registry username for JARVICE system
                                    images
  --registry-password <password>    Docker registry password for JARVICE system
                                    images
  --jarvice-license <license_key>   JARVICE license key
  --jarvice-username <username>     JARVICE platform username for app
                                    synchronization
  --jarvice-apikey <apikey>         JARVICE platform apikey for app
                                    synchronization
  --jarvice-chart-dir <path>        Alternative JARVICE helm chart directory
                                    (optional)
  --eks-cluster-name <name>         EKS cluster name
                                    (default: jarvice)
  --eks-node-type <node_type>       EC2 instance types for EKS nodes
                                    (default: c5.9xlarge)
  --install-nvidia-plugin           Install kubernetes device plugin if
                                    --eks-node-type has Nvidia GPUs
  --eks-nodes <number>              Number of EKS cluster nodes
                                    (default: 4)
  --eks-nodes-max <number>          Autoscale up to maximum number of nodes
                                    (must be greater than --eks-nodes)
  --aws-region <aws_region>         AWS region for EKS cluster
                                    (default: us-west-2)
  --aws-zones <aws_zone_list>       Comma separated zone list for --aws-region
                                    (optional)
  --helm-name <app_release_name>    Helm app release name
                                    (default: jarvice)
  --helm-namespace <k8s_namespace>  Cluster namepace to install release into
                                    (default: jarvice-system)

See the following link for available EC2 instance types (--eks-node-type):
https://aws.amazon.com/ec2/instance-types/

Example (minimal) deploy command:
$ ./scripts/jarvice-deploy2eks \
    --registry-username <username> \
    --registry-password <password> \
    --jarvice-license <license_key> \
    --jarvice-username <username> \
    --jarvice-apikey <apikey>
```

### AWS Credentials

If you don't already have an AWS user and/or access key, create a user with
the appropriate permissions and/or an access key in the AWS console:
https://console.aws.amazon.com/iam/home?#/users

Before using this script, it will be necessary to set your AWS credentials
with environment variables or put them in the AWS credentials config file:

```bash
$ export AWS_ACCESS_KEY_ID=<aws_access_key>
$ export AWS_SECRET_ACCESS_KEY=<aws_secret_key>
```

```bash
$ mkdir -p ~/.aws
$ cat >~/.aws/credentials <<EOF
[default]
aws_access_key_id = <aws_access_key>
aws_secret_access_key = <aws_secret_key>
EOF
```

See the following link for more details:
https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-getting-started.html

### KUBECONFIG

`jarvice-deploy2eks` will use `~/.kube/config` as the default kubeconfig file.
Set the `KUBECONFIG` environment variable to change the default:
```bash
$ export KUBECONFIG=~/.kube/config.eks
```

### Execution examples

As seen in the `--help` output, this is the minimal command line one can use
to deploy JARVICE to an EKS cluster:
```bash
$ ./scripts/jarvice-deploy2eks \
    --registry-username <username> \
    --registry-password <password> \
    --jarvice-license <license_key> \
    --jarvice-username <username> \
    --jarvice-apikey <apikey>
```

To deploy a cluster with 10 static EKS nodes:
```bash
$ ./scripts/jarvice-deploy2eks \
    --registry-username <username> \
    --registry-password <password> \
    --jarvice-license <license_key> \
    --jarvice-username <username> \
    --jarvice-apikey <apikey> \
    --eks-nodes 10
```

To deploy a cluster with an autoscaling group of 10-20 nodes, use
`--eks-nodes-max`:
```bash
$ ./scripts/jarvice-deploy2eks \
    --registry-username <username> \
    --registry-password <password> \
    --jarvice-license <license_key> \
    --jarvice-username <username> \
    --jarvice-apikey <apikey> \
    --eks-nodes 10 \
    --eks-nodes-max 20
```

To deploy a cluster with an autoscaling group of 10-20 `p3.2xlarge`
(Nvidia GPU enabled) nodes:
```bash
$ ./scripts/jarvice-deploy2eks \
    --registry-username <username> \
    --registry-password <password> \
    --jarvice-license <license_key> \
    --jarvice-username <username> \
    --jarvice-apikey <apikey> \
    --eks-nodes 10 \
    --eks-nodes-max 20 \
    --eks-node-type p3.2xlarge \
    --install-nvidia-plugin
```

To do all of the above in the `us-east-1` region with a specific list of zones:
```bash
$ ./scripts/jarvice-deploy2eks \
    --registry-username <username> \
    --registry-password <password> \
    --jarvice-license <license_key> \
    --jarvice-username <username> \
    --jarvice-apikey <apikey> \
    --eks-nodes 10 \
    --eks-nodes-max 20 \
    --eks-node-type p3.2xlarge \
    --install-nvidia-plugin \
    --aws-region us-east-1 \
    --aws-zones us-east-1a,us-east-1b,us-east-1e
```

### Cluster removal

In order to remove the EKS cluster, use the `eksctl delete cluster` command:
```bash
$ eksctl delete cluster --name=jarvice --region=us-west-2
```

If you had a previous kubeconfig file, the installation will have changed the
`current-context`.  Use `kubectl config get-contexts` to see the available
contexts in the kubeconfig.  Then, if desired, revert the `current-context`
with the fllowing command:
```bash
$ kubectl config set current-context <context_name>
```

### Troubleshooting

If an error occurs while `jarvice-deploy2eks` is creating the cluster, it is
most likely due to an error occuring while creating the CloudFormation stacks.
The CloudFormation stacks can be viewed here (select the approprate region if
 not using `us-west-2` default):
https://us-west-2.console.aws.amazon.com/cloudformation/home?#/stacks?filter=active

If the stack creation complains of a lack of resources, it may recommend a
list of zones which can be used to access the necessary resources.  If so, try
re-running `jarvice-deploy2eks` with the `--aws-zones` flag to request those
zones.

If the error was due to a previously existing Virtual Private Cloud (VPC)
stack of the same name, it will be necessary to delete it manually.  If the
stack previously failed to delete, manually select to retain the previous
resources associated with the stack when retrying the deletion.

### AWS resources links

The `jarvice-deploy2eks` creates a number of AWS resources.  They can be
viewed via the following links.

IAM roles:
https://console.aws.amazon.com/iam/home?#/roles

CloudFormation Stacks (select alternative region if necessary):
https://us-west-2.console.aws.amazon.com/cloudformation/home?#/stacks?filter=active

EKS clusters (select alternative region if necessary):
https://us-west-2.console.aws.amazon.com/eks/home?#/clusters

