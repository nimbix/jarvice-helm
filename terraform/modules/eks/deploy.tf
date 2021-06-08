# deploy.tf - EKS module kubernetes/helm components deployment for JARVICE

module "common" {
    source = "../common"

    global = var.global
    cluster = var.cluster

    system_nodes_type_upstream = lookup(var.cluster.meta, "arch", "") == "arm64" ? "m6g.4xlarge" : "m5.4xlarge"
    system_nodes_type_downstream = lookup(var.cluster.meta, "arch", "") == "arm64" ? "m6g.xlarge" : "m5.xlarge"
    storage_class_provisioner = "kubernetes.io/aws-ebs"
}

resource "aws_eip" "jarvice" {
    count = length(module.vpc.public_subnets)

    vpc = true

    tags = {
        cluster_name = var.cluster.meta["cluster_name"]
        load_balancer = "traefik"
    }

    depends_on = [module.vpc]
}

locals {
    charts = {
        "aws-load-balancer-controller" = {
            "values" = <<EOF
clusterName: ${var.cluster.meta["cluster_name"]}

serviceAccount:
  name: aws-load-balancer-controller
  annotations:
    eks.amazonaws.com/role-arn: "${module.iam_assumable_role_admin_aws_load_balancer_controller.iam_role_arn}"

tolerations:
  - key: node-role.jarvice.io/jarvice-system
    effect: NoSchedule
    operator: Exists
  - key: node-role.kubernetes.io/jarvice-system
    effect: NoSchedule
    operator: Exists

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

region: "${var.cluster.location["region"]}"

vpcId: "${module.vpc.vpc_id}"

podDisruptionBudget:
  maxUnavailable: 1
EOF
        },
        "cluster-autoscaler" = {
            "values" = <<EOF
autoDiscovery:
  clusterName: ${var.cluster.meta["cluster_name"]}
  enabled: true

awsRegion: "${var.cluster.location["region"]}"

cloudProvider: aws

image:
  repository: gcr.io/jarvice/cluster-autoscaler
  tag: v1.17.4
  pullPolicy: IfNotPresent

tolerations:
  - key: node-role.jarvice.io/jarvice-system
    effect: NoSchedule
    operator: Exists
  - key: node-role.kubernetes.io/jarvice-system
    effect: NoSchedule
    operator: Exists

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

rbac:
  create: true
  serviceAccountAnnotations:
    eks.amazonaws.com/role-arn: "${module.iam_assumable_role_admin_cluster_autoscaler.iam_role_arn}"
EOF
        },
        "metrics-server" = {
            "values" = <<EOF
image:
  repository: gcr.io/k8s-staging-metrics-server/metrics-server
  tag: v0.4.1
  pullPolicy: IfNotPresent

tolerations:
  - key: node-role.jarvice.io/jarvice-system
    effect: NoSchedule
    operator: Exists
  - key: node-role.kubernetes.io/jarvice-system
    effect: NoSchedule
    operator: Exists

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

priorityClassName: system-node-critical

args:
  - --kubelet-preferred-address-types=InternalIP
  - --kubelet-insecure-tls

service:
  labels:
    kubernetes.io/cluster-service: "true"
    kubernetes.io/name: "Metrics-server"
EOF
        },
        "external-dns" = {
            "values" = <<EOF
sources:
  - ingress

provider: aws

aws:
  region: "${var.cluster.location["region"]}"
  zoneType: "public"
  #evaluateTargetHealth: "true"

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

serviceAccount:
  annotations:
    eks.amazonaws.com/role-arn: "${module.iam_assumable_role_admin_external_dns.iam_role_arn}"
EOF
        },
        "cert-manager" = {
            "values" = <<EOF
installCRDs: true

#ingressShim:
#  defaultIssuerName: letsencrypt-prod
#  defaultIssuerKind: ClusterIssuer
#  defaultIssuerGroup: cert-manager.io

podDnsPolicy: "None"
podDnsConfig:
  nameservers:
    - "169.254.169.253"
    #- "1.1.1.1"
    #- "8.8.8.8"

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
        "traefik" =  {
            "values" = <<EOF
imageTag: "1.7"

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

dashboard:
  enabled: false

service:
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-type: external
    service.beta.kubernetes.io/aws-load-balancer-nlb-target-type: ip
    service.beta.kubernetes.io/aws-load-balancer-scheme: internet-facing
    service.beta.kubernetes.io/aws-load-balancer-eip-allocations: ${join(",", aws_eip.jarvice.*.id)}
    service.beta.kubernetes.io/aws-load-balancer-additional-resource-tags: cluster=${var.cluster.meta["cluster_name"]},traefik=true
    #service.beta.kubernetes.io/aws-load-balancer-cross-zone-load-balancing-enabled: "true"
    #service.beta.kubernetes.io/load-balancer-name: "${var.cluster.meta["cluster_name"]}"
    #service.beta.kubernetes.io/aws-load-balancer-subnets: "${join(",", module.vpc.public_subnets)}"

rbac:
  enabled: true
EOF
        }
    }
}

resource "null_resource" "helm_module_sleep_after_destroy" {
    triggers = {
        sleep_after_destroy = "sleep 180"
    }

    provisioner "local-exec" {
        when = destroy
        command = self.triggers.sleep_after_destroy
    }

    depends_on = [module.eks, module.vpc, module.iam_assumable_role_admin_cluster_autoscaler, module.iam_assumable_role_admin_aws_load_balancer_controller, module.iam_assumable_role_admin_external_dns, aws_eip.jarvice, local_file.kube_config]
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
# EKS cluster override values
${local.jarvice_ingress}
EOF

    depends_on = [module.eks, module.vpc, module.iam_assumable_role_admin_cluster_autoscaler, module.iam_assumable_role_admin_aws_load_balancer_controller, module.iam_assumable_role_admin_external_dns, aws_eip.jarvice, local_file.kube_config, null_resource.helm_module_sleep_after_destroy]
}

