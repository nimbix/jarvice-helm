
provider "helm" {
    version = "~> 1.2"

    kubernetes {
        #config_path = "~/.kube/config"
        load_config_file = false

        client_certificate = base64decode(var.kube_config.client_certificate)
        client_key = base64decode(var.kube_config.client_key)
        cluster_ca_certificate = base64decode(var.kube_config.cluster_ca_certificate)
        host = var.kube_config.host
    }
}

resource "helm_release" "traefik" {
  name = "traefik"
  repository = "https://kubernetes-charts.storage.googleapis.com"
  chart = "traefik"
  #version = "1.85.0"
  namespace = "kube-system"
  reuse_values = false
  reset_values = true

  values = [var.traefik_values]
}

locals {
  jarvice_override_yaml = yamldecode("${file("${var.jarvice["override_yaml_file"]}")}")
  jarvice_override_values = <<EOF
# Helm module override values
jarvice:
  nodeSelector: '${local.jarvice_override_yaml["jarvice"]["nodeSelector"] == null ? "{\"node-role.kubernetes.io/jarvice-system\": \"true\"}" : local.jarvice_override_yaml["jarvice"]["nodeSelector"]}'

  JARVICE_PVC_VAULT_NAME: ${local.jarvice_override_yaml["jarvice"]["JARVICE_PVC_VAULT_NAME"] == null ? "persistent" : local.jarvice_override_yaml["jarvice"]["JARVICE_PVC_VAULT_NAME"]}
  JARVICE_PVC_VAULT_STORAGECLASS: ${local.jarvice_override_yaml["jarvice"]["JARVICE_PVC_VAULT_STORAGECLASS"] == null ? "jarvice-user" : local.jarvice_override_yaml["jarvice"]["JARVICE_PVC_VAULT_STORAGECLASS"]}
  JARVICE_PVC_VAULT_ACCESSMODES: ${local.jarvice_override_yaml["jarvice"]["JARVICE_PVC_VAULT_ACCESSMODES"] == null ? "ReadWriteOnce" : local.jarvice_override_yaml["jarvice"]["JARVICE_PVC_VAULT_ACCESSMODES"]}
  JARVICE_PVC_VAULT_SIZE: ${local.jarvice_override_yaml["jarvice"]["JARVICE_PVC_VAULT_SIZE"] == null ? 10 : local.jarvice_override_yaml["jarvice"]["JARVICE_PVC_VAULT_SIZE"]}
EOF
}

resource "helm_release" "jarvice" {
  name = "jarvice"
  chart = "./"
  #version = "3.0.0"
  namespace = var.jarvice["namespace"]
  create_namespace = true
  reuse_values = false
  reset_values = true
  render_subchart_notes = true
  timeout = 600

  values = [
    "# values.yaml\n\n${file("values.yaml")}",
    "# ${var.jarvice["override_yaml_file"]}\n\n${file("${var.jarvice["override_yaml_file"]}")}",
    "${local.jarvice_override_values}",
    "${var.jarvice["override_yaml_values"]}",
    "${var.cluster_override_yaml}"
  ]
}

