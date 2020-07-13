# variables.tf - helm module variable definitions

variable "cluster_autoscaler_values" {
    type = string
    default = null
}

variable "external_dns_values" {
    type = string
    default = null
}

variable "traefik_values" {
    type = string
    default = null
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

