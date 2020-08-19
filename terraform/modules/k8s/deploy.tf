# deploy.tf - K8s module kubernetes/helm components deployment for JARVICE

module "helm" {
    source = "../helm"

    # JARVICE settings
    jarvice = merge(var.cluster.helm.jarvice, {"values_file"="${local.jarvice_values_file}"})
    global = var.global.helm.jarvice
    cluster_values_yaml = local.cluster_values_yaml
}

