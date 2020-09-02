# variables.tf - common module variable definitions

variable "global" {
    description = "Global Cluster Settings"
    type = object({
        meta = map(string)

        helm = map(
            map(string)
        )
    })
}

variable "cluster" {
    description = "Cluster Settings"
    type = object({
        enabled = bool

        auth = map(string)
        meta = map(string)

        location = object({
            region = string
            zones = list(string)
        })

        system_node_pool = object({
            nodes_type = string
            nodes_num = number
        })
        compute_node_pools = map(object({
            nodes_type = string
            nodes_disk_size_gb = number
            nodes_num = number
            nodes_min = number
            nodes_max = number
            meta = map(string)
        }))

        helm = map(
            map(string)
        )
    })
}

variable "system_nodes_type_upstream" {
    type = string
}

variable "system_nodes_type_downstream" {
    type = string
}

variable "storage_class_provisioner" {
    type = string
}

