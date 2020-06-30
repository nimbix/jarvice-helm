# variables.tf - AKS module variable definitions

variable "global" {
    description = "Global Cluster Settings"
    type = object({
        ssh_public_key = string

        helm = object({
            jarvice = map(string)
        })
    })
    default = {
        ssh_public_key = "~/.ssh/id_rsa.pub"

        helm = {
            jarvice = {
                override_yaml_values = <<EOF
# global override_yaml_values - Uncomment or add any values that should be
# applied to all defined clusters.
EOF
            }
        }
    }
}

variable "aks" {
    description = "Azure AKS Settings"
    type = object({
        enabled = bool

        service_principal_client_id = string
        service_principal_client_secret = string

        cluster_name = string
        kubernetes_version = string

        location = string
        availability_zones = list(string)

        ssh_public_key = string

        system_node_pool = object({
            node_vm_size = string
            node_count = number
        })
        compute_node_pools = list(object({
            node_vm_size = string
            node_os_disk_size_gb = number
            node_count = number
            node_min_count = number
            node_max_count = number
        }))

        helm = object({
            jarvice = map(string)
        })
    })
    default = {
        enabled = false

        service_principal_client_id = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
        service_principal_client_secret = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"

        cluster_name = "jarvice"
        kubernetes_version = "1.15.10"

        location = "Central US"
        availability_zones = ["1"]

        ssh_public_key = null

        system_node_pool = {
            node_vm_size = null
            node_count = null
        }
        compute_node_pools = [
            {
                node_vm_size = "Standard_D32_v3"
                node_os_disk_size_gb = 100
                node_count = 2
                node_min_count = 1
                node_max_count = 16
            },
        ]

        helm = {
            jarvice = {
                namespace = "jarvice-system"
                override_yaml_file = "override-tf.aks.<location>.<cluster_name>.yaml"
                override_yaml_values = <<EOF
# override_yaml_values - takes precedence over override_yaml_file and
# global override_yaml_values
EOF
            }
        }
    }
}

