# variables.tf - CAPG module variables

variable "enabled" {
    description = "Whether the CAPG cluster is enabled"
    type = bool
}

variable "auth" {
    description = "Authentication settings"
    type = map(string)
}

variable "meta" {
    description = "Cluster metadata"
    type = map(string)
}

variable "location" {
    description = "Cluster location settings"
    type = object({
        region = string
        zones = list(string)
    })
}

variable "system_node_pool" {
    description = "System node pool configuration"
    type = object({
        nodes_type = string
        nodes_num = number
    })
}

variable "compute_node_pools" {
    description = "Compute node pools configuration"
    type = map(any)
}

variable "helm" {
    description = "Helm configuration"
    type = map(any)
}

variable "global" {
    description = "Global settings for the CAPG cluster"
    type = object({
        meta = map(string)

        helm = map(
            map(string)
        )
    })
}

variable "cluster" {
    description = "CAPG-specific cluster configuration"
    type = any  # Flexible structure for CAPG cluster API configuration
}

variable "dockerbuild_node_pool" {
    description = "Docker build node pool configuration"
    type = object({
        nodes_type = string
        nodes_num = number
        nodes_min = number
        nodes_max = number
    })
}
