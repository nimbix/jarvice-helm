# JARVICE Deployment with Terraform

This documentation describes how to deploy JARVICE using Terraform.
Provisioning and deploying to Google Kubernetes Engine (GKE),
Amazon Elastic Kubernetes Service (EKS), and
Microsoft Azure Kubernetes Service (AKS) clusters is supported.
Deploying JARVICE to previously provisioned Kubernetes clusters is also
supported.

See [README.md](README.md) in the top level of this repository for more
in depth details on JARVICE Helm chart installations:
https://github.com/nimbix/jarvice-helm

## Prerequisites

### Code repository

Clone this git repository to a client machine in order to begin using
`terraform` to deploy JARVICE:

```bash
$ git clone https://github.com/nimbix/jarvice-helm.git
```

### `kubectl`

The `install-kubectl` helper script can be used to install the latest
version of `kubectl`.
Simply execute the following to install the `kubectl` executable:
```bash
$ ./jarvice-helm/scripts/install-kubectl
```

### `helm`

The `install-helm` helper script can be used to install the latest
version of `helm`.
Simply execute the following to install the `helm` executable:
```bash
$ ./jarvice-helm/scripts/install-helm
```

### `terraform`

The `install-terraform` helper script can be used to install the latest
version of Terraform on Linux amd64/x86_64 platforms.
Simply execute the following to install the `terraform` executable:
```bash
$ ./jarvice-helm/scripts/install-terraform
```

If installing on a different platform, visit the following link for the
latest Terraform releases:
https://www.terraform.io/downloads.html

**Note:**  Terraform 0.12.9 or newer is required.  That will soon change to 0.13.0 or newer.

### Cloud provider command line interface (CLI)

It will be necessary to install the CLI binaries for the appropriate cloud
service(s) that will be hosting JARVICE deployments.
These binaries will not be necessary if deploying JARVICE to an already
existing kubernetes cluster.

#### GCP for GKE: `gcloud`

If deploying JARVICE to GKE on Google Cloud, it will be necessary to install
the `gcloud` executable and log in to your GCP account.  Please visit the
following link for more details:
https://cloud.google.com/sdk/install

##### GCP Credentials

If you don't already have a GCP user with the appropriate permissions to create
GKE clusters, it will be necessary to add a user and
set the appropriate permissions for the indented GCP project here:
https://console.cloud.google.com/iam-admin/iam

It may also be desirable to set the default `gcloud` `account`, `project`,
and compute `zone`:

```bash
$ gcloud config set account <gcloud_account>
$ gcloud config set project <gcloud_project>
$ gcloud config set compute/zone <gcloud_compute_zone>
```

See the following link for more details:
https://cloud.google.com/sdk/gcloud/reference/config/set

#### AWS for EKS: `aws`

If deploying JARVICE to EKS on AWS, it will be necessary to install
the `az` executable and log in to your Azure account.  Please visit the
following link for more details:
https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-install.html

##### AWS Credentials

If you don't already have an AWS user and/or access key, create a user with
the appropriate permissions and/or an access key in the AWS console:
https://console.aws.amazon.com/iam/home?#/users

It may also be desirable to set your AWS credentials
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

#### Azure for AKS: `az`

If deploying JARVICE to AKS on Microsoft Azure, it will be necessary to install
the `az` executable and log in to your Azure account.  Please visit the
following link for more details:
https://docs.microsoft.com/en-us/cli/azure/install-azure-cli

##### Azure Credentials

If you don't already have an Azure user with the appropriate permissions to
create AKS clusters, it will be necessary to add a user and
set the appropriate permissions here:
https://portal.azure.com/

Before using `terraform` to create cluster, it will be necessary to sign into
Azure from the command line:

```bash
$ az login
```

See the following link for more details:
https://docs.microsoft.com/en-us/cli/azure/authenticate-azure-cli?view=azure-cli-latest

###### Creating a Service Principal using the Azure CLI

Execute the following to create a service principal which can be used for
deploying JARVICE to Azure:
```bash
$ az ad sp create-for-rbac --name jarvice-terraform
```

The above command will output an `appId` and `password`.  Be sure to save
those values.  They will be used when configuring the
`azure_service_principal_client_id` and
`azure_service_principal_client_secret` variables respectively.

See the following link for more details regarding Azure service principal
creation:
https://www.terraform.io/docs/providers/azurerm/guides/service_principal_client_secret.html

## Terraform Configuration

The JARVICE terraform module can simultaneously manage an arbitrary number of
JARVICE deployments on an arbitrary number of kubernetes clusters over an
arbitrary number of locations.
The module does so by utilizing a configuration which leverages terraform
variable definitions.

### Terraform variable definitions

The `terraform.tfvars` file found in the top level of the `jarvice-helm`
directory provides the variable settings which are used to configure
the cluster(s) for creation and deployment with `terraform`.

It is recommended that `terraform.tfvars` be copied to `override.auto.tfvars`.
Customizations can then be made by editing `override.auto.tfvars`.

Visit the following link for more information on how terraform handles
variable definitions:
https://www.terraform.io/docs/configuration/variables.html#variable-definitions-tfvars-files

### JARVICE helm chart values

For each cluster `enabled` in the `.tfvars` configuration(s), the helm
chart values are passed to the helm deployment in the following order
(listed from least to highest precedence):

* Local `values.yaml` file
* Per cluster `override_yaml_file` (if the cluster `override_yaml_file` file exists)
* Global `override_yaml_values` found in the `.tfvars` configuration(s)
* Per cluster `override_yaml_values` found in the `.tfvars` configuration(s)

See [README.md](README.md) in the top level of this repository for more
in depth details on JARVICE Helm chart settings:
https://github.com/nimbix/jarvice-helm

## Deploying JARVICE

### Initialize `terraform`

On the first run, it will be necessary to download and initialize the required
`terraform` providers and modules.  Execute the following to do so:

```bash
$ terraform init ./terraform
```

### Configure `terraform` variables and `helm` values

If you have not already done so, configure the `terraform` variable
definitions and `helm` chart settings mentioned above.

### Apply and create cluster definitions

After each update to the `.tfvars` configuration(s), it will be necessary to
create (or re-create) the cluster definitions file and make sure the required
providers and modules are initialized.  Execute the following to do so:

```bash
$ terraform apply -target=local_file.clusters -auto-approve -compact-warnings ./terraform && terraform init ./terraform
```

### Applying `terraform` configuration

Once your configuration is in place, execute the following from the top level
directory of `jarvice-helm` to deploy JARVICE:

```bash
$ terraform apply ./terraform
```

This will `apply` the configuration which will provision the cluster
infrastructure and deploy JARVICE.

Upon success, you will see output similar to the following:
```
EKS Cluster Configuration: eks_cluster_00
===============================================================================

    EKS cluster name: tf-jarvice
EKS cluster location: us-west-2

Execute the following to begin using kubectl/helm with the new cluster:

export KUBECONFIG=~/.kube/config-tf.eks.us-west-2.tf-jarvice

Open the portal URL to initialize JARVICE:

https://a568758ba79d641f0b08fce671e9a693-115733088.us-west-2.elb.amazonaws.com/

===============================================================================
```

**Note:**  It may take several minutes before the portal to become available.

### Initialize JARVICE from the portal

After successfully deploying JARVICE, visit the portal URL provided above
and initialize the new deployment.

### Destroying the deployments and cluster(s)

To remove the cluster(s) and delete all provisioned resources, execute the
following from the top level directory of `jarvice-helm` to deploy JARVICE:

```bash
$ terraform destroy ./terraform
```

**Warning:**  When destroying clusters which were provisioned using managed
kubernetes services, the associated volumes/disks will also be deleted.  Be
sure to backup any essential data from those volumes/disks before running
`destroy` on those clusters.

