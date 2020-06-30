# variables.tf - helm module variable definitions

variable "traefik_deploy" {
    type = bool
    default = true
}

variable "traefik_values" {
    type = string
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

