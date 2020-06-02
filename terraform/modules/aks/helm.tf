module "kubernetes" {
    source = "../modules/kubernetes"

    kube_config = azurerm_kubernetes_cluster.jarvice.kube_config[0]
}

module "helm" {
    source = "../modules/helm"

    kube_config = azurerm_kubernetes_cluster.jarvice.kube_config[0]

    # Traefik settings
    traefik_deploy = true
    traefik_values = <<EOF
loadBalancerIP: ${azurerm_public_ip.jarvice.ip_address}
replicas: 2
memoryRequest: 1Gi
memoryLimit: 1Gi
cpuRequest: 1
cpuLimit: 1

nodeSelector:
  kubernetes.io/arch: "amd64"
  node-role.kubernetes.io/jarvice-system: "true"
tolerations:
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
    service.beta.kubernetes.io/azure-load-balancer-resource-group: ${azurerm_kubernetes_cluster.jarvice.node_resource_group}

rbac:
  enabled: true
EOF

    # JARVICE settings
    jarvice = var.aks.helm.jarvice

    cluster_override_yaml = <<EOF
# AKS cluster override yaml
jarvice_api:
  ingressHost: ${azurerm_public_ip.jarvice.fqdn}
  ingressPath: "/api"

jarvice_mc_portal:
  ingressHost: ${azurerm_public_ip.jarvice.fqdn}
  ingressPath: "/"
EOF

}

