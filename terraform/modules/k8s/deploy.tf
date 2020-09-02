# deploy.tf - K8s module kubernetes/helm components deployment for JARVICE

module "common" {
    source = "../common"

    global = var.global
    cluster = var.cluster
}

module "helm" {
    source = "../helm"

    # JARVICE settings
    jarvice = merge(var.cluster.helm.jarvice, {"values_file"="${module.common.jarvice_values_file}"})
    global = var.global.helm.jarvice
    cluster_values_yaml = <<EOF
# K8s cluster override values
EOF
}

