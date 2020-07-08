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
}

