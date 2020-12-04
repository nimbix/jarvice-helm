# deploy.tf - GKE module kubernetes/helm components deployment for JARVICE

module "common" {
    source = "../common"

    global = var.global
    cluster = var.cluster

    system_nodes_type_upstream = "n1-standard-8"
    system_nodes_type_downstream = "n1-standard-4"
    storage_class_provisioner = "kubernetes.io/gce-pd"
}

locals {
    charts = {
        "traefik" = {
            "values" = <<EOF
replicas: 2
memoryRequest: 1Gi
memoryLimit: 1Gi
cpuRequest: 1
cpuLimit: 1

nodeSelector:
  node-role.jarvice.io/jarvice-system: "true"
tolerations:
  - key: node-role.jarvice.io/jarvice-system
    effect: NoSchedule
    operator: Exists
  - key: node-role.kubernetes.io/jarvice-system
    effect: NoSchedule
    operator: Exists

ssl:
  enabled: true
  enforced: true
  permanentRedirect: true
  insecureSkipVerify: true
  generateTLS: true

dashboard:
  enabled: false

rbac:
  enabled: true
EOF
        }
    }
}

module "helm" {
    source = "../helm"

    charts = local.charts

    # JARVICE settings
    jarvice = merge(var.cluster.helm.jarvice, {"values_file"="${module.common.jarvice_values_file}"})
    global = var.global.helm.jarvice
    cluster_values_yaml = <<EOF
${module.common.cluster_values_yaml}

# GKE cluster override values
${local.jarvice_ingress}
EOF
}

