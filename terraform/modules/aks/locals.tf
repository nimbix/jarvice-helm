# locals.tf - AKS module local variable definitions

locals {
    kube_config = {
        "config_path" = "~/.kube/config-tf.aks.${azurerm_kubernetes_cluster.jarvice.location}.${var.cluster.meta["cluster_name"]}",
        "host" = azurerm_kubernetes_cluster.jarvice.kube_config[0].host
        "cluster_ca_certificate" = azurerm_kubernetes_cluster.jarvice.kube_config[0].cluster_ca_certificate,
        "client_certificate" = azurerm_kubernetes_cluster.jarvice.kube_config[0].client_certificate,
        "client_key" = azurerm_kubernetes_cluster.jarvice.kube_config[0].client_key,
        "token" = null,
        "username" = null,
        "password" = null
    }
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

    jarvice_ingress = module.common.jarvice_cluster_type == "downstream" ? local.jarvice_ingress_downstream : local.jarvice_ingress_upstream
}

