# variables.tf - K8s module variable definitions

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

        helm = map(
            map(string)
        )
    })
}

