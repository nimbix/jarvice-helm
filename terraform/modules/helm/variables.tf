# variables.tf - helm module variable definitions

variable "charts" {
    type = map(
        map(string)
    )
    default = {}
}

variable "global" {
    type = map(string)
}

variable "jarvice" {
    type = map(string)
}

variable "common_values_yaml" {
    type = string
}

variable "cluster_values_yaml" {
    type = string
}

