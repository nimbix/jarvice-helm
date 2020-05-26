# Terraform will automatically load values from this variable definitions file
# and then any *.auto.tfvars files.  Visit the following link for more info:
# https://www.terraform.io/docs/configuration/variables.html#variable-definitions-tfvars-files

###########################
### Kubernetes settings ###
###########################
#k8s = [
#    {
#    },
#]

#################################
### Google Cloud GKE Settings ###
#################################
#gke = [
#    {
#    },
#]

###########################
### Amazon EKS Settings ###
###########################
#eks = [
#    {
#    },
#]

##########################
### Azure AKS settings ###
##########################
aks = [
    {
        enabled = false

        # Visit the following link for service principal creation information:
        # https://github.com/nimbix/jarvice-helm/blob/testing/Terraform.md#creating-a-service-principal-using-the-azure-cli
        service_principal_client_id = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
        service_principal_client_secret = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"

        cluster_name = "jarvice"
        kubernetes_version = "1.15.10"

        location = "Central US"
        availability_zones = ["1"]

        ssh_public_key = "~/.ssh/id_rsa.pub"

        # Visit the following link for Azure node size specs:
        # https://docs.microsoft.com/en-us/azure/cloud-services/cloud-services-sizes-specs
        system_node_pool = {
            node_vm_size = "Standard_DS4_v2"
            node_count = 3
        }
        compute_node_pools = [
            {
                node_vm_size = "Standard_D32_v3"
                node_os_disk_size_gb = 100
                node_count = 2
                node_min_count = 1
                node_max_count = 16
            },
            #{
            #    node_vm_size = "Standard_D32_v3"
            #    node_os_disk_size_gb = 100
            #    node_count = 2
            #    node_min_count = 1
            #    node_max_count = 16
            #}
        ]

        helm = {
            override_yaml = "override.aks.yaml"
            JARVICE_PVC_VAULT_SIZE = "10"
            JARVICE_PVC_VAULT_NAME = "persistent"
            JARVICE_PVC_VAULT_STORAGECLASS = "jarvice-user"
            JARVICE_PVC_VAULT_ACCESSMODES = "ReadWriteOnce"
        }
    },
]

