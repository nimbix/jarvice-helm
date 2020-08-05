# variables.tf - EKS module variable definitions

variable "global" {
    description = "Global Cluster Settings"
    type = object({
        ssh_public_key = string

        helm = object({
            jarvice = map(string)
        })
    })
}

variable "cluster" {
    description = "Cluster Settings"
    type = object({
        enabled = bool

        project = string
        credentials = string

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
    })
}

