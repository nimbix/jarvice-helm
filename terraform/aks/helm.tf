provider "kubernetes" {
  version = "~> 1.11"

  load_config_file = "false"
  client_certificate = base64decode(azurerm_kubernetes_cluster.jarvice[0].kube_config.0.client_certificate)
  client_key = base64decode(azurerm_kubernetes_cluster.jarvice[0].kube_config.0.client_key)
  cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.jarvice[0].kube_config.0.cluster_ca_certificate)
  host = azurerm_kubernetes_cluster.jarvice[0].kube_config.0.host
}

resource "kubernetes_storage_class" "jarvice-db" {
  count = var.aks["enabled"] ? 1 : 0

  metadata {
    name = "jarvice-db"
    labels = {"storage-role.jarvice.io/jarvice-db" = "${var.aks["cluster_name"]}"}
  }
  storage_provisioner = "kubernetes.io/azure-disk"
  reclaim_policy      = "Retain"
  parameters = {
    cachingmode = "ReadOnly"
    kind = "Managed"
    #storageaccounttype = "Premium_LRS"
    storageaccounttype = "StandardSSD_LRS"
  }
}

resource "kubernetes_storage_class" "jarvice-user" {
  count = var.aks["enabled"] ? 1 : 0

  metadata {
    name = "jarvice-user"
    labels = {"storage-role.jarvice.io/jarvice-user" = "${var.aks["cluster_name"]}"}
  }
  storage_provisioner = "kubernetes.io/azure-disk"
  reclaim_policy = "Retain"
  parameters = {
    cachingmode = "ReadOnly"
    kind = "Managed"
    #storageaccounttype = "Premium_LRS"
    storageaccounttype = "StandardSSD_LRS"
  }
}


provider "helm" {
  version = "~> 1.2"

  kubernetes {
    #config_path = "~/.kube/config"
    load_config_file = false

    client_certificate = base64decode(azurerm_kubernetes_cluster.jarvice[0].kube_config.0.client_certificate)
    client_key = base64decode(azurerm_kubernetes_cluster.jarvice[0].kube_config.0.client_key)
    cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.jarvice[0].kube_config.0.cluster_ca_certificate)
    host = azurerm_kubernetes_cluster.jarvice[0].kube_config.0.host
  }
}

#resource "helm_release" "traefik" {
#  name = "traefik"
#  repository = "https://kubernetes-charts.storage.googleapis.com"
#  chart = "traefik"
#  #version = "1.85.0"
#  namespace = "kube-system"
#  reuse_values = false
#  reset_values = true
#
#  values = [<<EOF
#rbac:
#  enabled: true
#nodeSelector:
#  kubernetes.io/arch: "amd64"
#  node-role.kubernetes.io/jarvice-system: "true"
#tolerations:
#  - key: node-role.kubernetes.io/jarvice-system
#    effect: NoSchedule
#    operator: Exists
#loadBalancerIP: ${azurerm_public_ip.jarvice.ip_address}
#ssl:
#  enabled: true
#  enforced: true
#  permanentRedirect: true
#  insecureSkipVerify: true
#  generateTLS: true
#replicas: 2
#memoryRequest: 1Gi
#memoryLimit: 1Gi
#cpuRequest: 1
#cpuLimit: 1
#EOF
#  ]
#
#  depends_on = [azurerm_public_ip.jarvice]
#}

resource "helm_release" "jarvice" {
  name = "jarvice"
  chart = "./"
  #version = "3.0.0"
  namespace = "jarvice-system"
  create_namespace = true
  reuse_values = false
  reset_values = true
  render_subchart_notes = true
  timeout = 600

  values = [
    "${file("values.yaml")}",
    "${file("${var.aks.helm["override_yaml"]}")}",
<<EOF
jarvice:
  nodeSelector: '{"node-role.kubernetes.io/jarvice-system": "true"}'

  JARVICE_PVC_VAULT_SIZE: ${var.aks.helm["JARVICE_PVC_VAULT_SIZE"]}
  JARVICE_PVC_VAULT_NAME: ${var.aks.helm["JARVICE_PVC_VAULT_NAME"]}
  JARVICE_PVC_VAULT_STORAGECLASS: ${var.aks.helm["JARVICE_PVC_VAULT_STORAGECLASS"]}
  JARVICE_PVC_VAULT_ACCESSMODES: ${var.aks.helm["JARVICE_PVC_VAULT_ACCESSMODES"]}

#jarvice_api:
#  ingressHost: {azurerm_public_ip.jarvice.fqdn}
#  ingressPath: "/api"
#
#jarvice_mc_portal:
#  ingressHost: {azurerm_public_ip.jarvice.fqdn}
#  ingressPath: "/"
EOF
  ]

  #depends_on = [azurerm_public_ip.jarvice]
}

