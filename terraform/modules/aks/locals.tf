locals {
    jarvice_helm_override_yaml = fileexists(var.aks.helm.jarvice["override_yaml_file"]) ? "${file("${var.aks.helm.jarvice["override_yaml_file"]}")}" : ""

    jarvice_helm_values = merge(lookup(yamldecode("XXXdummy: value\n\n${file("values.yaml")}"), "jarvice", {}), lookup(yamldecode("XXXdummy: value\n\n${local.jarvice_helm_override_yaml}"), "jarvice", {}), lookup(yamldecode("XXXdummy: value\n\n${var.global.helm.jarvice["override_yaml_values"]}"), "jarvice", {}), lookup(yamldecode("XXXdummy: value\n\n${var.aks.helm.jarvice["override_yaml_values"]}"), "jarvice", {}))

    jarvice_cluster_type = local.jarvice_helm_values["JARVICE_CLUSTER_TYPE"] == "downstream" ? "downstream" : "upstream"
}

locals {
    system_node_vm_size = local.jarvice_cluster_type == "downstream" ? "Standard_D3_v2" : "Standard_D5_v2"
    system_node_vm_count = local.jarvice_cluster_type == "downstream" ? 2 : 3
}

locals {
    kube_config = "~/.kube/config-tf.aks.${azurerm_kubernetes_cluster.jarvice.location}.${var.aks["cluster_name"]}"
}

locals {
    jarvice_ingress_upstream = <<EOF
# AKS cluster override yaml
jarvice_api:
  ingressHost: ${azurerm_public_ip.jarvice.fqdn}
  ingressPath: "/api"

jarvice_mc_portal:
  ingressHost: ${azurerm_public_ip.jarvice.fqdn}
  ingressPath: "/"
EOF
    jarvice_ingress_downstream = <<EOF
# AKS cluster override yaml
jarvice_k8s_scheduler:
  ingressHost: ${azurerm_public_ip.jarvice.fqdn}
EOF
    jarvice_ingress = local.jarvice_cluster_type == "downstream" ? local.jarvice_ingress_downstream : local.jarvice_ingress_upstream

    cluster_override_yaml_values = <<EOF
# AKS cluster override values
jarvice:
  nodeSelector: '${local.jarvice_helm_values["nodeSelector"] == null ? "{\"node-role.kubernetes.io/jarvice-system\": \"true\"}" : local.jarvice_helm_values["nodeSelector"]}'

  JARVICE_PVC_VAULT_NAME: ${local.jarvice_helm_values["JARVICE_PVC_VAULT_NAME"] == null ? "persistent" : local.jarvice_helm_values["JARVICE_PVC_VAULT_NAME"]}
  JARVICE_PVC_VAULT_STORAGECLASS: ${local.jarvice_helm_values["JARVICE_PVC_VAULT_STORAGECLASS"] == null ? "jarvice-user" : local.jarvice_helm_values["JARVICE_PVC_VAULT_STORAGECLASS"]}
  JARVICE_PVC_VAULT_ACCESSMODES: ${local.jarvice_helm_values["JARVICE_PVC_VAULT_ACCESSMODES"] == null ? "ReadWriteOnce" : local.jarvice_helm_values["JARVICE_PVC_VAULT_ACCESSMODES"]}
  JARVICE_PVC_VAULT_SIZE: ${local.jarvice_helm_values["JARVICE_PVC_VAULT_SIZE"] == null ? 10 : local.jarvice_helm_values["JARVICE_PVC_VAULT_SIZE"]}

${local.jarvice_ingress}
EOF
}

locals {
    cluster_output_message = local.jarvice_cluster_type == "downstream" ? "Add the downstream cluster URL to an upstream JARVICE cluster" : "Open the portal URL to initialize JARVICE"
}

