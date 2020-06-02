# Terraform will automatically load values from this variable definitions file
# and then any *.auto.tfvars files.  Visit the following link for more info:
# https://www.terraform.io/docs/configuration/variables.html#variable-definitions-tfvars-files

#######################
### Global settings ###
#######################
global_override_yaml_values = <<EOF
# global_override_yaml_values - applied to all defined clusters.
# Update per cluster override_yaml_values to override global values.
#jarvice:
  # imagePullSecret is base64 encoded.
  #imagePullSecret: # echo "_json_key:$(cat gcr.io.json)" | base64 -w 0
  #JARVICE_LICENSE_LIC:
EOF

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
        #enabled = false # (currently a no-op, may be required in next release)

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
            node_vm_size = "Standard_D5_v2"
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
            #},
        ]

        helm = {
            jarvice = {
                namespace = "jarvice-system"
                override_yaml_file = "override.aks.yaml"
                # global_override_yaml_values take precedence over
                # override_yaml_file.
                override_yaml_values = <<EOF
# override_yaml_values - takes precedence over all above values.

#jarvice:
  # imagePullSecret is base64 encoded.
  #imagePullSecret: # echo "_json_key:$(cat gcr.io.json)" | base64 -w 0
  #JARVICE_LICENSE_LIC:

  #nodeSelector: '{"node-role.kubernetes.io/jarvice-system": "true"}'

  #JARVICE_PVC_VAULT_NAME: persistent
  #JARVICE_PVC_VAULT_STORAGECLASS: jarvice-user
  #JARVICE_PVC_VAULT_ACCESSMODES: ReadWriteOnce
  #JARVICE_PVC_VAULT_SIZE: 10
EOF
            }
        }
    },
]

