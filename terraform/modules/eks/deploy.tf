# deploy.tf - EKS module kubernetes/helm components deployment for JARVICE

module "helm" {
    source = "../helm"

    # Traefik settings
    traefik_deploy = true
    traefik_values = <<EOF
#loadBalancerIP: {aws_eip.nat[0].public_ip}
replicas: 2
memoryRequest: 1Gi
memoryLimit: 1Gi
cpuRequest: 1
cpuLimit: 1

nodeSelector:
  kubernetes.io/arch: "amd64"
  #node-role.kubernetes.io/jarvice-system: "true"
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

dashboard:
  enabled: false

#service:
#  annotations:
#    service.beta.kubernetes.io/aws-load-balancer-type: nlb
#    service.beta.kubernetes.io/aws-load-balancer-cross-zone-load-balancing-enabled: "true"
#    service.beta.kubernetes.io/aws-load-balancer-eip-allocations: "{aws_eip.nat[0].id}"
    #service.beta.kubernetes.io/aws-load-balancer-backend-protocol: tcp
    #service.beta.kubernetes.io/aws-load-balancer-connection-idle-timeout: "60"
    #service.beta.kubernetes.io/aws-load-balancer-cross-zone-load-balancing-enabled: "true"
    #service.beta.kubernetes.io/aws-load-balancer-internal: 0.0.0.0/0
    #service.beta.kubernetes.io/aws-load-balancer-subnets: "${aws_security_group.jarvice.id}"

rbac:
  enabled: true
EOF

    # JARVICE settings
    jarvice = merge(var.eks.helm.jarvice, {"override_yaml_file"="${local.jarvice_override_yaml_file}"})
    global = var.global.helm.jarvice
    cluster_override_yaml_values = local.cluster_override_yaml_values

}

