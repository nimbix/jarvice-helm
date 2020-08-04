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
    })
}

