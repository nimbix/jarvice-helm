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
an EKS cluster.  That process will take approximately 15 minutes.  That may
vary depending on the settings chosen for the number of EKS nodes and the
accompanying volume sizes.

Next, it will install kubernetes plugins and initialize/configure Tiller
to enable installation of the JARVICE helm chart into the cluster.  Lastly,
it will `helm install` the JARVICE chart and print out URLs for accessing
the JARVICE installation.  It will take around five minutes for the JARVICE
installation and deployment rollout.  The entire process combined,
from start to finish, will be approximately 20 minutes.

Execute `jarvice-deploy2eks` with `--help` to see all of the current command
line options:
```bash
Usage:
  ./scripts/jarvice-deploy2eks [global_options] [deploy_or_delete_options]

Available [global_options]:
  --jarvice-chart-dir <path>        Alternative JARVICE helm chart directory
                                    (Default: .)
  --config-file <filename>          Alternative cluster config file
                                    (Default: ./eks-cluster.yaml)

Available [delete_options]:
  --eks-cluster-delete              Delete the EKS cluster
  --database-vol-delete             Delete the database volume on cluster delete
  --vault-vols-delete               Delete the vault volumes on cluster delete
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

If the kubeconfig file exists, a new context for the EKS cluster will be added
to it.  If the kubeconfig file doesn't exist, it will be created.

### Cluster configuration file

`jarvice-deploy2eks` will use `./scripts/eks-cluster.yaml` as the default
EKS cluster configuration file.  The `--config-file` option can be used to
select another configuration file.

At a minimum, to bring up an EKS cluster with JARVICE, it will be necessary
to use an edited configuration so as to provide credentials in the `jarvice`
stanza.

### Execution example

After copying and editing the default configuration file, a cluster can be
brought up with a simple command line:
```bash
$ ./scripts/jarvice-deploy2eks --config-file ./scripts/jarvice-cluster.yaml
```

### Cluster removal

In order to remove the EKS cluster, use the `--eks-cluster-delete` flag:
```bash
$ ./scripts/jarvice-deploy2eks --config-file ./scripts/jarvice-cluster.yaml \
    --eks-cluster-delete
```

To delete the JARVICE database and/or user vault EBS volumes along with the
cluster, the `--database-vol-delete` and/or `--vault-vols-delete` flags must
be explicitly provided:
```bash
$ ./scripts/jarvice-deploy2eks --config-file ./scripts/jarvice-cluster.yaml \
    --eks-cluster-delete --database-vol-delete --vault-vols-delete
```
Note:  Preserved JARVICE database and user vault EBS volumes will be reused
if an EKS cluster of the same name is recreated in the same AWS region and
availability zone.

If you had a previous kubeconfig file, the installation will have changed the
`current-context`.  Use `kubectl config get-contexts` to see the available
contexts in the kubeconfig.  Then, if desired, revert the `current-context`
with the following command:
```bash
$ kubectl config set current-context <context_name>
```

### Troubleshooting

If an error occurs while `jarvice-deploy2eks` is creating the cluster, it is
most likely due to an error during creation of the CloudFormation stacks.
The stacks can be viewed via the CloudFormation Stacks link provided below.

If the stack creation complains of a lack of resources, it may recommend a
list of zones which can be used to access the necessary resources.  If so,
update the cluster configuration with the zone recommendations and
re-run `jarvice-deploy2eks`.

If the error was due to a previously existing Virtual Private Cloud (VPC)
stack of the same name, it will be necessary to delete it manually (see the
VPC management console link below).

If the EC2 load balancers and matching elastic load balancer (ELB) security
groups associated with the Virtual Private Cloud (VPC) of a previous cluster
deployment were not properly cleaned up on cluster deletion, the VPCs
will not be subsequently deleted.  This may cause the allotted VPC limit for
the AWS account to be reached.  In that case, AWS will not allow further VPC
creation during the bring up of new EKS clusters.  Use the the EC2 and VPC
management console links below to manually delete the load balancers and
security groups before deleting the associated VPCs.

### AWS resource links

The `jarvice-deploy2eks` creates a number of AWS resources.  They can be
viewed via the following links.

IAM roles:
https://console.aws.amazon.com/iam/home?#/roles

CloudFormation Stacks (select alternative region if necessary):
https://us-west-2.console.aws.amazon.com/cloudformation/home?#/stacks?filter=active

EKS clusters (select alternative region if necessary):
https://us-west-2.console.aws.amazon.com/eks/home?#/clusters

VPC management console (select alternative region if necessary):
https://us-west-2.console.aws.amazon.com/vpc/home

EC2 Management Console (select alternative region if necessary):
https://us-west-2.console.aws.amazon.com/ec2/v2/home

