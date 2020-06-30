# deploy.tf - AKS module kubernetes/helm components deployment for JARVICE

module "helm" {
    source = "../helm"

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
    jarvice = merge(var.aks.helm.jarvice, {"override_yaml_file"="${local.jarvice_override_yaml_file}"})
    global = var.global.helm.jarvice
    cluster_override_yaml_values = local.cluster_override_yaml_values

}

