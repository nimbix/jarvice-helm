# Terraform will automatically load variable definitions from here

# Visit the following link for service principal creation information:
# https://github.com/nimbix/jarvice-helm/blob/testing/Terraform.md#creating-a-service-principal-using-the-azure-cli

# terraform will prompt for these values if not provided
#azure_service_principal_client_id = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
#azure_service_principal_client_secret = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"

location = "Central US"
availability_zones = ["1"]
cluster_name = "jarvice"
kubernetes_version = "1.15.10"
ssh_public_key = "~/.ssh/id_rsa.pub"

compute_node_vm_size = "Standard_D32_v3"
compute_node_os_disk_size_gb = 100
compute_node_count = 2
compute_node_min_count = 1
compute_node_max_count = 16

override_yaml = "override.yaml"

# These values will take precedence over values/override yaml settings
JARVICE_PVC_VAULT_SIZE = "10"
JARVICE_PVC_VAULT_NAME = "persistent"
JARVICE_PVC_VAULT_STORAGECLASS = "jarvice-user"
JARVICE_PVC_VAULT_ACCESSMODES = "ReadWriteOnce"


