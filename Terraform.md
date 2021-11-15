# JARVICE Deployment with Terraform

This documentation describes how to deploy JARVICE using Terraform.
Provisioning and deploying to Google Kubernetes Engine (GKE),
Amazon Elastic Kubernetes Service (EKS), and
Microsoft Azure Kubernetes Service (AKS) clusters is supported.
Deploying JARVICE to previously provisioned Kubernetes clusters is also
supported.

See [README.md](https://github.com/nimbix/jarvice-helm/README.md) in the top level of this repository for more
in depth details on JARVICE Helm chart installations:
https://github.com/nimbix/jarvice-helm

------------------------------------------------------------------------------

## Table of Contents

* [Prerequisites](#prerequisites)
    - [Code repository](#code-repository)
    - [`kubectl`](#kubectl)
    - [`helm`](#helm)
    - [`terraform`](#terraform)
    - [Cloud provider command line interface (CLI)](#cloud-provider-command-line-interface-cli)
        - [GCP for GKE: `gcloud`](#gcp-for-gke-gcloud)
            - [GCP Credentials](#gcp-credentials)
        - [AWS for EKS: `aws`](#aws-for-eks-aws)
            - [AWS Credentials](#aws-credentials)
        - [Azure for AKS: `az`](#azure-for-aks-az)
            - [Azure Credentials](#azure-credentials)
* [Terraform Configuration](#terraform-configuration)
    - [Terraform variable definitions](#terraform-variable-definitions)
    - [JARVICE helm chart values](#jarvice-helm-chart-values)
    - [Ingress TLS certificate configuration](#ingress-tls-certificate-configuration)
        - [Using certificates via Let's Encrypt](#using-certificates-via-lets-encrypt)
            - [Let's Encrypt rate limits](#lets-encrypt-rate-limits)
        - [Using certificates issued by other certificate authorities](#using-certificates-issued-by-other-certificate-authorities)
    - [Ingress DNS configuration](#ingress-dns-configuration)
        - [Using a custom DNS domain (or subdomain)](#using-a-custom-dns-domain-or-subdomain)
        - [Manual DNS records management](#manual-dns-records-management)
        - [Automatic DNS records management](#automatic-dns-records-management)
            - [Google Cloud DNS](#google-cloud-dns)
            - [Azure DNS](#azure-dns)
    - [Arm64 (AArch64) cluster deployment](#arm64-aarch64-cluster-deployment)
        - [Arm64 on AWS](#arm64-on-aws)
* [Deploying JARVICE](#deploying-jarvice)
    - [Initialize `terraform`](#initialize-terraform)
    - [Configure `terraform` variables and `helm` values](#configure-terraform-variables-and-helm-values)
    - [Apply and create cluster definitions](#apply-and-create-cluster-definitions)
    - [Applying `terraform` configuration](#applying-terraform-configuration)
    - [Initialize JARVICE deployment(s) from the portal(s)](#initialize-jarvice-deployments-from-the-portals)
    - [Destroying the deployment(s) and cluster(s)](#destroying-the-deployments-and-clusters)
* [Additional Resources](#additional-resources)

------------------------------------------------------------------------------

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
version of Terraform on Linux amd64/x86_64 or arm64/aarch64 platforms.
Simply execute the following to install the `terraform` executable:
```bash
$ ./jarvice-helm/scripts/install-terraform
```

If installing on a different platform, visit the following link for the
latest Terraform releases:
https://www.terraform.io/downloads.html

**Note:**  Terraform 1.0.0 or newer is required.

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
set the appropriate permissions for the intended GCP project here:
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
the `aws` and `aws-iam-authenticator` executables.
Please visit the following link for more details:
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

**Note:**  Azure CLI version 2.23.0 or later is required

##### Azure Credentials

If you don't already have an Azure user with the appropriate permissions to
create AKS clusters, it will be necessary to add a user and
set the appropriate permissions here:
https://portal.azure.com/

Before using `terraform` to create a cluster, it will be necessary to sign into
Azure from the command line:

```bash
$ az login
```

See the following link for more details:
https://docs.microsoft.com/en-us/cli/azure/authenticate-azure-cli?view=azure-cli-latest

**Note:**  Creating an Azure service principal is no longer required.

------------------------------------------------------------------------------

## Terraform Configuration

The JARVICE terraform module can simultaneously manage an arbitrary number of
JARVICE deployments on an arbitrary number of kubernetes clusters over an
arbitrary number of locations.
The module does so by utilizing a configuration which leverages terraform
variable definitions.

### Terraform variable definitions

The `terraform.tfvars` file found in the `jarvice-helm/terraform`
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

* Global `values_file` (if file exists)
* Per cluster `values_file` (if file exists)
* Global `values_yaml` found in the `.tfvars` configuration(s)
* Per cluster `values_yaml` found in the `.tfvars` configuration(s)

**Note:**  The `terraform.tfvars` file already includes the most pertinent
values which might need to be modified for JARVICE deployments.  Additional
values only need to be included if the helm chart defaults require
modification.

Execute the following to view the default JARVICE helm chart `values.yaml`
for a particular JARVICE release:
```bash
$ version=3.0.0-1.XXXXXXXXXXXX
$ curl https://raw.githubusercontent.com/nimbix/jarvice-helm/$version/values.yaml
```

Visit the JARVICE helm chart releases page ([https://github.com/nimbix/jarvice-helm/releases](https://github.com/nimbix/jarvice-helm/releases))
to view the latest available release versions.

See [README.md](https://github.com/nimbix/jarvice-helm/README.md) in the top level of this repository for more
in depth details on JARVICE Helm chart settings:
https://github.com/nimbix/jarvice-helm

### Ingress TLS certificate configuration

In the `terraform.tfvars` file, the ingress TLS certificate
configuration can be set via the helm values on a global or per cluster basis.
If the ingress TLS settings are not configured, an unsigned TLS certificate
will be used by default.  It is strongly recommended that the ingress TLS
settings be configured for all JARVICE deployments.

The following `jarvice.ingress` stanza helm values can be uncommented and
configured in the global and/or individual cluster configurations:
```bash
  #ingress:
  #  tls:
  #    issuer:
  #      name: "letsencrypt-prod"  # "letsecrypt-staging" # "selfsigned"
  #      # An admin email is required when letsencrypt issuer is set. The first
  #      # JARVICE_MAIL_ADMINS email will be used if issuer.email is not set.
  #      email: # "admin@my-domain.com"
  #    # If crt and key values are provided, issuer settings will be ignored
  #    crt: # base64 encoded.  e.g. Execute: base64 -w 0 <site-domain>.pem
  #    key: # base64 encoded.  e.g. Execute: base64 -w 0 <site-domain>.key
```

#### Using certificates via Let's Encrypt

The simplest way to get started with a valid certificate is to allow
[Let's Encrypt](https://letsencrypt.org/) to automatically issue and sign it
for you.  A valid email address is all that is needed for this:
```bash
  ingress:
    tls:
      issuer:
        name: "letsencrypt-prod"  # "letsecrypt-staging" # "selfsigned"
        # An admin email is required when letsencrypt issuer is set. The first
        # JARVICE_MAIL_ADMINS email will be used if issuer.email is not set.
        email: "my-email@my-domain.com"
  #    # If crt and key values are provided, issuer settings will be ignored
  #    crt: # base64 encoded.  e.g. Execute: base64 -w 0 <site-domain>.pem
  #    key: # base64 encoded.  e.g. Execute: base64 -w 0 <site-domain>.key
```

##### Let's Encrypt rate limits

If you will be deploying clusters in your own domain, please be
aware that Let's Encrypt does have
[rate limits](https://letsencrypt.org/docs/rate-limits/).  This should not
present any issues unless you will be deploying and tearing down many JARVICE
deployments within a short time period.  In that case, you will want to use
the `letsecrypt-staging` issuer instead of `letsencrypt-prod`.

#### Using certificates issued by other certificate authorities

If you already have an issued certificate/key pair to use with your JARVICE
deployment(s), it must be `base64` encoded.  With your issued certificate/key
files, simply execute the following to encode them:
```bash
$ base64 -w 0 <crt-or-key-file>
```

The encoded strings must then be used for the `tls.crt` and `tls.key` values:
```bash
  ingress:
    tls:
  #    issuer:
  #      name: "letsencrypt-prod"  # "letsecrypt-staging" # "selfsigned"
  #      # An admin email is required when letsencrypt issuer is set. The first
  #      # JARVICE_MAIL_ADMINS email will be used if issuer.email is not set.
  #      email: # "admin@my-domain.com"
  #    # If crt and key values are provided, issuer settings will be ignored
      crt: <base64-encoded-cert>
      key: <base64-encoded-key>
```

### Ingress DNS configuration

By default, terraform JARVICE deployments will be deployed using a
wildcard DNS hostname via the `nip.io` ([https://nip.io/](https://nip.io/))
service.  This hostname will be mapped to the static IP address that was
issued to the ingress controller.  The hostname will be formatted as such:
```bash
https://<cluster_name>.<cluster_region>.<k8s_service>.jarvice.<ip_address>.nip.io/
```

Here is an example hostname that might be used by default for an EKS deployed
cluster in the `us-west-2` region:
```bash
https://tf-jarvice.us-west-2.eks.jarvice.54.212.96.156.nip.io/
```

#### Using a custom DNS domain (or subdomain)

In order to use a custom DNS domain, the `ingressHost` of the appropriate
service(s) must be set.  Here is an example:
```bash
jarvice_api:
  ingressHost: jarvice.eks.my-domain.com
  ingressPath: "/api"  # Valid values are "/" (default) or "/api"

jarvice_mc_portal:
  ingressHost: jarvice.eks.my-domain.com
  ingressPath: "/"  # Valid values are "/" (default) or "/portal"
```

**Note:**  If using a subdomain, the apex domain must have a corresponding
`NS` record which points to the subdomain.  The details of DNS management
and configuring `NS` records is beyond the scope of this document.

#### Manual DNS records management

If you will be manually managing DNS records for your terraform JARVICE
deployments, manually assigned IP addresses are not currently supported.
It will be necessary to update your DNS records after the IP addresses are
issued for your terraform JARVICE deployment(s).

#### Automatic DNS records management

The terraform JARVICE configuration can automatically manage DNS records of
your JARVICE deployment(s) if a DNS zone is being managed by the same
cloud service that the JARVICE cluster is being deployed on.  In order to
enable this, simply uncomment `dns_manage_records` in the cluster's `meta`
configuration section and be sure that it is set to `true`.

**Note:**  Terraform JARVICE deployments will not overwrite DNS records that
it itself did not create.  If a DNS record was already created for the
desired hostname, it must be deleted before it can be automatically managed
with terraform JARVICE.

##### Google Cloud DNS

If your Google Cloud DNS zone is not being managed in the same project as
the terraform JARVICE deployment, the `dns_zone_project` must be set in the
cluster's `meta` configuration section.

##### Azure DNS

Azure DNS requires that the `dns_zone_resource_group` be set in cluster's
`meta` configuration section.  This must match the resource group that
the managed DNS zone is in.

### Arm64 (AArch64) cluster deployment

In addition to AMD64 (x86_64), Terraform deployments are supported for
Arm64 clusters.  As of this writing, only EKS on AWS has support
for the Arm64 architecture.

#### Arm64 on AWS

In order to deploy an Arm64 cluster, it will be necessary to set/uncomment
the appropriate EKS cluster configuration options.

Firstly, in the `.tfvars` configuration(s), the `arch` setting in the
`meta` section must be set to `arm64`:
```bash
        meta = {
            cluster_name = "tf-jarvice"
            kubernetes_version = "1.16"
            arch = "arm64"  # Uncomment to deploy an arm64 cluster
...
```

In addition, Arm64 node types will need to be used.  Use the
[AWS Instance Type Explorer](https://aws.amazon.com/ec2/instance-explorer/?ec2-instances-cards.sort-by=item.additionalFields.category-order&ec2-instances-cards.sort-order=asc&awsf.ec2-instances-filter-processors=processors%23aws) to
find instance types which use the Arm-based AWS Graviton2 processors.
Here is an example compute node pool configuration using `c6g.16xlarge`:
```bash
        compute_node_pools = {
            jxecompute00 = {
                nodes_type = "c6g.16xlarge"
                nodes_disk_size_gb = 100
...
```
**Note:**  It is not currently possible to mix node pool architectures in
a single cluster deployment.  If a multi-architecture cluster is desired,
it will be necessary to deploy an additional downstream cluster to add
another architecture.

------------------------------------------------------------------------------

## Deploying JARVICE

### Initialize `terraform`

On the first run, it will be necessary to download and initialize the required
`terraform` providers and modules.  Execute the following from within the
`jarvice-helm/terraform` directory to do so:

```bash
$ terraform init
```

If executing `terraform` from outside of the `jarvice-helm/terraform`
directory, it will be necessary to specify the path to that directory with
any `terraform` commands being executed:
```bash
$ terraform init <jarvice-helm-path>/terraform
```

**Note:**  Whenever a `git pull` on this repository is done to get the latest
updates, it may also be necessary to execute
`terraform init -upgrade=true` before applying any cluster updates.

### Configure `terraform` variables and `helm` values

If you have not already done so, configure the `terraform` variable
definitions and `helm` chart settings mentioned above.

### Apply and create cluster definitions

After each update to the `.tfvars` configuration(s), it will be necessary to
create (or re-create) the cluster definitions file and make sure the required
providers and modules are initialized.  Execute the following to do so:

```bash
$ terraform apply -target=local_file.clusters -auto-approve -compact-warnings && terraform init
```

### Applying `terraform` configuration

Once your configuration is in place, execute the following to deploy JARVICE:

```bash
$ terraform apply
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

https://tf-jarvice.us-west-2.eks.jarvice.54.212.96.156.nip.io/

===============================================================================
```

**Note:**  It may take several minutes before the portal(s) become available.

### Initialize JARVICE deployment(s) from the portal(s)

After successfully deploying JARVICE, visit the portal URL(s) provided above
and initialize the new deployment(s).

### Destroying the deployment(s) and cluster(s)

To remove **all** of the cluster(s) that you are managing with `terraform`
and delete all of their provisioned resources, execute the
following to destroy the cluster(s):

```bash
$ terraform destroy
```

In order to destroy only one of the `terraform` managed clusters, it will be
necessary to specify the targeted cluster module directly.  Execute a command
similar to the following to do so:

```bash
$ cluster_config=aks_cluster_00
$ terraform destroy -target=module.$cluster_config
```

After destroying an individual cluster, be sure to disable it in your
`.tfvars` configuration(s) and re-create the cluster definitions file:

```bash
$ terraform apply -target=local_file.clusters -auto-approve -compact-warnings
```

**Warning:**  When destroying clusters which were provisioned using managed
kubernetes services, the associated volumes/disks will also be deleted.  Be
sure to backup any essential data from those volumes/disks before running
`destroy` on those clusters.

------------------------------------------------------------------------------

## Additional Resources

- JARVICE cloud platform helm chart [README.md](https://github.com/nimbix/jarvice-helm/README.md)

