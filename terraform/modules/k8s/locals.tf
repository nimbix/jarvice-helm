# locals.tf - K8s module local variable definitions

locals {
    kube_config = {
        "config_path" = var.cluster["auth"]["kube_config"],
        "host" = null,
        "cluster_ca_certificate" = null,
        "client_certificate" = null,
        "client_key" = null,
        "token" = null,
        "username" = null,
        "password" = null
    }
}

locals {
    jarvice_ingress_name = module.common.jarvice_cluster_type == "downstream" ? "jarvice-k8s-scheduler" : "jarvice-mc-portal"

    jarvice_config = {
        "ingress_host_path" = "~/.terraform-jarvice/ingress-tf.k8s.${var.cluster.meta["cluster_name"]}"
        "loadbalancer_host_path" = "~/.terraform-jarvice/loadbalancer-tf.k8s.${var.cluster.meta["cluster_name"]}"
    }
}

