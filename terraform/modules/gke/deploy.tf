# deploy.tf - GKE module kubernetes/helm components deployment for JARVICE

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
  kubernetes.io/arch: "amd64"
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
    jarvice = merge(var.cluster.helm.jarvice, {"override_yaml_file"="${local.jarvice_override_yaml_file}"})
    global = var.global.helm.jarvice
    cluster_override_yaml_values = local.cluster_override_yaml_values
}

