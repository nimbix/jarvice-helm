# deploy.tf - EKS module kubernetes/helm components deployment for JARVICE

locals {
    charts = {
        "cluster-autoscaler" = {
            "values" = <<EOF
autoDiscovery:
  clusterName: ${var.cluster.meta["cluster_name"]}
  enabled: true

awsRegion: "${var.cluster.location["region"]}"

cloudProvider: aws

tolerations:
  - key: node-role.jarvice.io/jarvice-system
    effect: NoSchedule
    operator: Exists
  - key: node-role.kubernetes.io/jarvice-system
    effect: NoSchedule
    operator: Exists
nodeSelector:
  kubernetes.io/arch: "amd64"
  node-role.jarvice.io/jarvice-system: "true"

rbac:
  create: true
  serviceAccountAnnotations:
    eks.amazonaws.com/role-arn: "${module.iam_assumable_role_admin.this_iam_role_arn}"
EOF
        },
        "traefik" =  {
            "values" = <<EOF
# TODO: use eip allocations with NLB
#loadBalancerIP: {aws_eip.nat[0].public_ip}
replicas: 2
memoryRequest: 1Gi
memoryLimit: 1Gi
cpuRequest: 1
cpuLimit: 1

nodeSelector:
  kubernetes.io/arch: "amd64"
  node-role.jarvice.io/jarvice-system: "true"
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
        }
    }
}

module "helm" {
    source = "../helm"

    charts = local.charts

    # JARVICE settings
    jarvice = merge(var.cluster.helm.jarvice, {"values_file"="${local.jarvice_values_file}"})
    global = var.global.helm.jarvice
    cluster_values_yaml = local.cluster_values_yaml
}

