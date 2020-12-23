# deploy.tf - AKS module kubernetes/helm components deployment for JARVICE

module "common" {
    source = "../common"

    global = var.global
    cluster = var.cluster

    system_nodes_type_upstream = "Standard_D5_v2"
    system_nodes_type_downstream = "Standard_D3_v2"
    storage_class_provisioner = "kubernetes.io/azure-disk"
}

locals {
    charts = {
        "traefik" = {
            "values" = <<EOF
loadBalancerIP: ${azurerm_public_ip.jarvice.ip_address}
replicas: 2
memoryRequest: 1Gi
memoryLimit: 1Gi
cpuRequest: 1
cpuLimit: 1

affinity:
  nodeAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      nodeSelectorTerms:
      - matchExpressions:
        - key: node-role.jarvice.io/jarvice-system
          operator: Exists
      - matchExpressions:
        - key: node-role.kubernetes.io/jarvice-system
          operator: Exists

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

service:
  annotations:
    service.beta.kubernetes.io/azure-load-balancer-resource-group: ${azurerm_resource_group.jarvice.name}

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
    jarvice = merge(var.cluster.helm.jarvice, {"values_file"=module.common.jarvice_values_file})
    global = var.global.helm.jarvice
    common_values_yaml = <<EOF
${module.common.cluster_values_yaml}
EOF
    cluster_values_yaml = <<EOF
# AKS cluster override values
${local.jarvice_ingress}
EOF

    depends_on = [azurerm_kubernetes_cluster.jarvice, azurerm_kubernetes_cluster_node_pool.jarvice_system]
}

