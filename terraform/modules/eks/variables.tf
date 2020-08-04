# variables.tf - AKS module variable definitions

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
    })
}

