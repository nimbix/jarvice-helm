# deploy.tf - EKS module kubernetes/helm components deployment for JARVICE

module "helm" {
    source = "../helm"

    # depends_on for modules is coming with terraform v0.13.0
    #depends_on = [module.iam_assumable_role_admin.this_iam_role_arn]

    # Cluster autoscaler settings
    cluster_autoscaler_enabled = true
    cluster_autoscaler_values = <<EOF
autoDiscovery:
  clusterName: ${var.eks["cluster_name"]}
  enabled: true

awsRegion: "${var.eks["region"]}"

cloudProvider: aws

tolerations:
  - key: node-role.kubernetes.io/jarvice-system
    effect: NoSchedule
    operator: Exists
nodeSelector:
  kubernetes.io/arch: "amd64"
  node-role.kubernetes.io/jarvice-system: "true"

rbac:
  create: true
  serviceAccountAnnotations:
    eks.amazonaws.com/role-arn: "${module.iam_assumable_role_admin.this_iam_role_arn}"
EOF

    # Traefik settings
    traefik_values = <<EOF
# TODO: use eip allocations with NLB
#loadBalancerIP: {aws_eip.nat[0].public_ip}
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

dashboard:
  enabled: false

# TODO: use eip allocations with NLB
#service:
#  annotations:
#    service.beta.kubernetes.io/aws-load-balancer-type: nlb
#    service.beta.kubernetes.io/aws-load-balancer-cross-zone-load-balancing-enabled: "true"
#    service.beta.kubernetes.io/aws-load-balancer-eip-allocations: "{aws_eip.nat[0].id}"
#    service.beta.kubernetes.io/aws-load-balancer-backend-protocol: tcp
#    service.beta.kubernetes.io/aws-load-balancer-connection-idle-timeout: "60"

rbac:
  enabled: true
EOF

    # JARVICE settings
    jarvice = merge(var.eks.helm.jarvice, {"override_yaml_file"="${local.jarvice_override_yaml_file}"})
    global = var.global.helm.jarvice
    cluster_override_yaml_values = local.cluster_override_yaml_values
}

