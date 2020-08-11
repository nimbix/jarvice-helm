# deploy.tf - K8s module kubernetes/helm components deployment for JARVICE

module "helm" {
    source = "../helm"

    # JARVICE settings
    jarvice = merge(var.cluster.helm.jarvice, {"override_yaml_file"="${local.jarvice_override_yaml_file}"})
    global = var.global.helm.jarvice
    cluster_override_yaml_values = local.cluster_override_yaml_values
}

