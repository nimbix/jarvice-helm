# variables.tf - K8s module variable definitions

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

        auth = map(string)

        cluster_name = string

        helm = object({
            jarvice = map(string)
        })
    })
}

