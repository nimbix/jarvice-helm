
variable "kube_config" {
    type = map(string)
}

variable "traefik_deploy" {
    type = bool
}

variable "traefik_values" {
    type = string
}

variable "jarvice" {
    type = map(string)
}

variable "cluster_override_yaml" {
    type = string
}

