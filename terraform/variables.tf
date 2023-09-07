# variables.tf - root module variable definitions

variable "global" {
    description = "Global Cluster Settings"
    type = object({
        meta = map(string)

        helm = map(
            map(string)
        )
    })
    default = {
        meta = {
            ssh_public_key = "~/.ssh/id_rsa.pub"
        }

        helm = {
            jarvice = {
                values_yaml = <<EOF
# global values_yaml - Uncomment or add any values that should be
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
        meta = map(string)

        helm = map(
            map(string)
        )
    }))
    default = {}
}

variable "gke" {
    description = "Google GKE Settings"
    type = map(object({
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
        dockerbuild_node_pool = object({
            nodes_type = string
            nodes_num = number
            nodes_min = number
            nodes_max = number
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
    }))
    default = {}
}

variable "gkev2" {
    description = "Google GKE Settings"
    type = map(object({
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
        dockerbuild_node_pool = object({
            nodes_type = string
            nodes_num = number
            nodes_min = number
            nodes_max = number
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
    }))
    default = {}
}

variable "eks" {
    description = "Amazon EKS Settings"
    type = map(object({
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
        dockerbuild_node_pool = object({
            nodes_type = string
            nodes_num = number
            nodes_min = number
            nodes_max = number
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
    }))
    default = {}
}

variable "eksv2" {
    description = "Amazon EKS Settings"
    type = map(object({
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
        dockerbuild_node_pool = object({
            nodes_type = string
            nodes_num = number
            nodes_min = number
            nodes_max = number
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
    }))
    default = {}
}

variable "aks" {
    description = "Azure AKS Settings"
    type = map(object({
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
        dockerbuild_node_pool = object({
            nodes_type = string
            nodes_num = number
            nodes_min = number
            nodes_max = number
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
    }))
    default = {}
}

