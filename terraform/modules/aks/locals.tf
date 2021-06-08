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
    cluster_values_yaml = <<EOF
jarvice:
  JARVICE_JOBS_DOMAIN: "lookup/job$"
  daemonsets:
    nvidia:
      enabled: true
      nodeAffinity: '{"requiredDuringSchedulingIgnoredDuringExecution": {"nodeSelectorTerms": [{"matchExpressions": [{"key": "accelerator", "operator": "In", "values": ["nvidia"]}]}] }}'
    flex_volume_plugin_nfs_nolock_install:
      enabled: true
      env:
        KUBELET_PLUGIN_DIR: /etc/kubernetes/volumeplugins
EOF
    jarvice_ingress_upstream = <<EOF
${local.cluster_values_yaml}

# AKS cluster upstream ingress related settings
jarvice_license_manager:
  #ingressHost: "${var.cluster.meta["cluster_name"]}.${var.cluster.location["region"]}.aks.jarvice.${azurerm_public_ip.jarvice.ip_address}.nip.io"
  #ingressPath: "/license-manager"
  nodeAffinity: '{"requiredDuringSchedulingIgnoredDuringExecution": {"nodeSelectorTerms": [{"matchExpressions": [{"key": "node-role.jarvice.io/jarvice-system", "operator": "Exists"}, {"key": "kubernetes.io/arch", "operator": "In", "values": ["amd64"]}]}] }}'

jarvice_api:
  ingressHost: "${var.cluster.meta["cluster_name"]}.${var.cluster.location["region"]}.aks.jarvice.${azurerm_public_ip.jarvice.ip_address}.nip.io"
  ingressPath: "/api"

jarvice_mc_portal:
  ingressHost: "${var.cluster.meta["cluster_name"]}.${var.cluster.location["region"]}.aks.jarvice.${azurerm_public_ip.jarvice.ip_address}.nip.io"
  ingressPath: "/"
EOF

    jarvice_ingress_downstream = <<EOF
${local.cluster_values_yaml}

# AKS cluster downstream ingress related settings
jarvice_k8s_scheduler:
  ingressHost: "${var.cluster.meta["cluster_name"]}.${var.cluster.location["region"]}.aks.jarvice.${azurerm_public_ip.jarvice.ip_address}.nip.io"
EOF

    jarvice_ingress = module.common.jarvice_cluster_type == "downstream" ? local.jarvice_ingress_downstream : local.jarvice_ingress_upstream
}

