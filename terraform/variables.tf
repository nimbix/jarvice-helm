# variables.tf - root module variable definitions

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

variable "gke" {
    description = "Google GKE Settings"
    type = map(object({
        enabled = bool

        project = string
        credentials = string

        cluster_name = string
        kubernetes_version = string

        location = string

        ssh_public_key = string

        system_node_pool = object({
            machine_type = string
            num_nodes = number
        })
        compute_node_pools = list(object({
            machine_type = string
            disk_size_gb = number
            num_nodes = number
            min_nodes = number
            max_nodes = number
        }))

        helm = object({
            jarvice = map(string)
        })
    }))
    default = {}
}

variable "eks" {
    description = "Amazon EKS Settings"
    type = map(object({
        enabled = bool

        cluster_name = string
        kubernetes_version = string

        region = string
        availability_zones = list(string)

        ssh_public_key = string

        system_node_pool = object({
            instance_type = string
            asg_desired_capacity = number
        })
        compute_node_pools = list(object({
            instance_type = string
            root_volume_size = number
            asg_desired_capacity = number
            asg_min_size = number
            asg_max_size = number
        }))

        helm = object({
            jarvice = map(string)
        })
    }))
    default = {}
}

variable "aks" {
    description = "Azure AKS Settings"
    type = map(object({
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
    }))
    default = {}
}

