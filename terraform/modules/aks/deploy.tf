# deploy.tf - AKS module kubernetes/helm components deployment for JARVICE

module "common" {
    source = "../common"

    global = var.global
    cluster = var.cluster

    system_nodes_type_upstream = "Standard_D5_v2"
    system_nodes_type_downstream = "Standard_D3_v2"
    storage_class_provisioner = "kubernetes.io/azure-disk"
}

data "azurerm_subscription" "current" {
}

#data "azurerm_client_config" "current" {
#}

#data "azurerm_user_assigned_identity" "current" {
#    name = "${azurerm_kubernetes_cluster.jarvice.name}-agentpool"
#    resource_group_name = azurerm_kubernetes_cluster.jarvice.node_resource_group
#}

resource "azurerm_role_assignment" "network_contributor" {
    scope = "/subscriptions/${data.azurerm_subscription.current.subscription_id}"
    role_definition_name = "Network Contributor"
    principal_id = azurerm_kubernetes_cluster.jarvice.identity[0].principal_id
    #skip_service_principal_aad_check = true
}

resource "azurerm_role_assignment" "virtual_machine_contributor" {
    scope = "/subscriptions/${data.azurerm_subscription.current.subscription_id}"
    role_definition_name = "Virtual Machine Contributor"
    principal_id = azurerm_kubernetes_cluster.jarvice.identity[0].principal_id
    #skip_service_principal_aad_check = true
}

resource "azurerm_role_assignment" "dns_zone_contributor" {
    scope = "/subscriptions/${data.azurerm_subscription.current.subscription_id}"
    role_definition_name = "DNS Zone Contributor"
    principal_id = azurerm_kubernetes_cluster.jarvice.kubelet_identity[0].object_id
    #skip_service_principal_aad_check = true
}

resource "azurerm_role_assignment" "private_dns_zone_contributor" {
    scope = "/subscriptions/${data.azurerm_subscription.current.subscription_id}"
    role_definition_name = "Private DNS Zone Contributor"
    principal_id = azurerm_kubernetes_cluster.jarvice.kubelet_identity[0].object_id
    #skip_service_principal_aad_check = true
}

locals {
    charts = {
        "external-dns" = {
            "values" = <<EOF
image:
  registry: us.gcr.io
  repository: k8s-artifacts-prod/external-dns/external-dns
  tag: v0.8.0

sources:
  - ingress

provider: azure

azure:
  #cloud: "AzureCloud"
  resourceGroup: "${lookup(var.cluster["meta"], "dns_zone_resource_group", "tf-jarvice-dns")}"
  tenantId: "${azurerm_kubernetes_cluster.jarvice.identity[0].tenant_id}"
  subscriptionId: "${data.azurerm_subscription.current.subscription_id}"
  useManagedIdentityExtension: true
  userAssignedIdentityID: "${azurerm_kubernetes_cluster.jarvice.kubelet_identity[0].client_id}"

dryRun: ${lookup(var.cluster["meta"], "dns_manage_records", "false") != "true" ? "true" : "false" }

logLevel: info

txtOwnerId: "${var.cluster.meta["cluster_name"]}.${var.cluster.location["region"]}"

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
EOF
        },
        "cert-manager" = {
            "values" = <<EOF
installCRDs: true

#ingressShim:
#  defaultIssuerName: letsencrypt-prod
#  defaultIssuerKind: ClusterIssuer
#  defaultIssuerGroup: cert-manager.io

prometheus:
  enabled: false

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

webhook:
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

cainjector:
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
EOF
        },
        "traefik" = {
            "values" = <<EOF
imageTag: "1.7"

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

kubernetes:
  ingressEndpoint:
    useDefaultPublishedService: true

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

    depends_on = [azurerm_kubernetes_cluster.jarvice, azurerm_kubernetes_cluster_node_pool.jarvice_system, resource.azurerm_role_assignment.network_contributor, resource.azurerm_role_assignment.virtual_machine_contributor, resource.azurerm_role_assignment.dns_zone_contributor, resource.azurerm_role_assignment.private_dns_zone_contributor, local_file.kube_config]
}

