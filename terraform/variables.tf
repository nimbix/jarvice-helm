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

variable "k8s" {
    description = "Cluster K8s Settings"
    type = map(object({
        enabled = bool

        auth = map(string)

        cluster_name = string

        helm = object({
            jarvice = map(string)
        })
    }))
    default = {}
}

variable "gke" {
    description = "Google GKE Settings"
    type = map(object({
        enabled = bool

        auth = map(string)

        cluster_name = string
        location = string

        kubernetes_version = string

        ssh_public_key = string

        system_node_pool = object({
            nodes_type = string
            nodes_num = number
        })
        compute_node_pools = list(object({
            nodes_type = string
            nodes_disk_size_gb = number
            nodes_num = number
            nodes_min = number
            nodes_max = number
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

        auth = map(string)

        cluster_name = string
        region = string
        availability_zones = list(string)

        kubernetes_version = string

        ssh_public_key = string

        system_node_pool = object({
            nodes_type = string
            nodes_num = number
        })
        compute_node_pools = list(object({
            nodes_type = string
            nodes_disk_size_gb = number
            nodes_num = number
            nodes_min = number
            nodes_max = number
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

        auth = map(string)

        cluster_name = string
        location = string
        availability_zones = list(string)

        kubernetes_version = string

        ssh_public_key = string

        system_node_pool = object({
            nodes_type = string
            nodes_num = number
        })
        compute_node_pools = list(object({
            nodes_type = string
            nodes_disk_size_gb = number
            nodes_num = number
            nodes_min = number
            nodes_max = number
        }))

        helm = object({
            jarvice = map(string)
        })
    }))
    default = {}
}

