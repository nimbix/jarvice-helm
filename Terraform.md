# JARVICE deployment with Terraform

This documentation describes how to deploy JARVICE using Terraform.
As of this writing, only the Azure Kubernetes Service (AKS) clusters on the
Microsoft Azure cloud platform is supported.

See [README.md](README.md) in the top level of this repository for more
in depth details on JARVICE Helm chart installations:
https://github.com/nimbix/jarvice-helm

## Code repository of the JARVICE helm chart

It is first necessary to clone this git repository to a client machine:

```bash
$ git clone https://github.com/nimbix/jarvice-helm.git
```

## Install required software

### Install `kubectl`

The `install-kubectl` helper script can be used to install the latest
version of `kubectl`.
Simply execute the following to install the `kubectl` executable:
```bash
$ ./jarvice-helm/scripts/install-kubectl
```

### Install `helm`

The `install-helm` helper script can be used to install the latest
version of `helm`.
Simply execute the following to install the `helm` executable:
```bash
$ ./jarvice-helm/scripts/install-helm
```

### Install `terraform`

The `install-terraform` helper script can be used to install the latest
version of Terraform on Linux amd64/x86_64 platforms.
Simply execute the following to install the `terraform` executable:
```bash
$ ./jarvice-helm/scripts/install-terraform
```

If installing to a different platform, visit the following link for the
latest Terraform releases:
https://www.terraform.io/downloads.html

### Install Azure CLI

If deploying JARVICE to Microsoft Azure AKS, it will be necessary to install
the `az` executable and log in to your Azure account.  Please visit the
following link for more details:
https://docs.microsoft.com/en-us/cli/azure/install-azure-cli

## Configuration

### Microsoft Azure Kubernetes Service (AKS)

#### Creating a Service Principal using the Azure CLI

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

### Terraform variables

The `terraform.tfvars` file found in the top level of the `jarvice-helm`
directory provides the variable settings which are used to configure
the cluster creation and deployment with `terraform`.

It is recommended that `terraform.tfvars` be copied to `terraform.auto.tfvars`.
Customizations can then be made by editing `terraform.auto.tfvars`.

### `override.yaml`

The `values.yaml` file found in the top level of the `jarvice-helm`
directory provides the settings which are used to configure the JARVICE helm
chart deployment used with `terraform`.

The default `terraform` configuration provided requires that `values.yaml` be
copied to `override.yaml`.
Helm chart value customizations can then be made by editing `override.yaml`.

## Deploying JARVICE

### Configure `terraform` variables and `helm` values

If you have not already done so, configure the `terraform` variables and
`helm` chart settings files mentioned above.

### Initialize `terraform`

Execute the following to initialize the `terraform` providers:

```bash
$ terraform init ./terraform
```

### Applying `terraform` configuration

Once your configuration is in place, execute the following from the top level
directory of `jarvice-helm` to deploy JARVICE:

```bash
$ terraform apply ./terraform
```

This will `apply` the configuration to the infrastructure and deploy JARVICE.

Upon success, you will see output similar to the following:
```
Execute the following to begin using kubectl/helm with the new cluster:

export KUBECONFIG=~/.kube/config.jarvice.tf.aks

Execute the following to get the JARVICE portal URL:

echo "http://$(kubectl -n jarvice-system get services jarvice-mc-portal-lb -o jsonpath='{.status.loadBalancer.ingress[0].ip}'):8080"
```

### Initialize JARVICE from the portal

After successfully deploying JARVICE, visit the portal URL provided above
and initialize the new deployment.

### Destroying the cluster

To remove the cluster and delete it's resources, execute the following from
the top level directory of `jarvice-helm` to deploy JARVICE:

```bash
$ terraform destroy ./terraform
```

