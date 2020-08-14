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

variable "cluster_override_yaml_values" {
    type = string
}

