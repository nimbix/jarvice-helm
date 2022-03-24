# deploy.tf - EKS module kubernetes/helm components deployment for JARVICE

module "common" {
    source = "../common"

    global = var.global
    cluster = var.cluster

    system_nodes_type_upstream = lookup(var.cluster.meta, "arch", "") == "arm64" ? "m6g.4xlarge" : "m5.4xlarge"
    system_nodes_type_downstream = lookup(var.cluster.meta, "arch", "") == "arm64" ? "m6g.xlarge" : "m5.xlarge"
    storage_class_provisioner = "kubernetes.io/aws-ebs"
    storage_class_provisioner_dockerbuild = "kubernetes.io/aws-ebs"
}

resource "aws_eip" "jarvice" {
    count = length(local.vpc.public_subnets)

    vpc = true

    tags = {
        cluster_name = var.cluster.meta["cluster_name"]
        load_balancer = "traefik"
    }

    depends_on = [module.vpc]
}

locals {
    eks_registries = {
        "af-south-1" = "877085696533.dkr.ecr.af-south-1.amazonaws.com"
        "ap-east-1" = "800184023465.dkr.ecr.ap-east-1.amazonaws.com"
        "ap-northeast-1" = "602401143452.dkr.ecr.ap-northeast-1.amazonaws.com"
        "ap-northeast-2" = "602401143452.dkr.ecr.ap-northeast-2.amazonaws.com"
        "ap-northeast-3" = "602401143452.dkr.ecr.ap-northeast-3.amazonaws.com"
        "ap-south-1" = "602401143452.dkr.ecr.ap-south-1.amazonaws.com"
        "ap-southeast-1" = "602401143452.dkr.ecr.ap-southeast-1.amazonaws.com"
        "ap-southeast-2" = "602401143452.dkr.ecr.ap-southeast-2.amazonaws.com"
        "ca-central-1" = "602401143452.dkr.ecr.ca-central-1.amazonaws.com"
        "cn-north-1" = "918309763551.dkr.ecr.cn-north-1.amazonaws.com.cn"
        "cn-northwest-1" = "961992271922.dkr.ecr.cn-northwest-1.amazonaws.com.cn"
        "eu-central-1" = "602401143452.dkr.ecr.eu-central-1.amazonaws.com"
        "eu-north-1" = "602401143452.dkr.ecr.eu-north-1.amazonaws.com"
        "eu-south-1" = "590381155156.dkr.ecr.eu-south-1.amazonaws.com"
        "eu-west-1" = "602401143452.dkr.ecr.eu-west-1.amazonaws.com"
        "eu-west-2" = "602401143452.dkr.ecr.eu-west-2.amazonaws.com"
        "eu-west-3" = "602401143452.dkr.ecr.eu-west-3.amazonaws.com"
        "me-south-1" = "558608220178.dkr.ecr.me-south-1.amazonaws.com"
        "sa-east-1" = "602401143452.dkr.ecr.sa-east-1.amazonaws.com"
        "us-east-1" = "602401143452.dkr.ecr.us-east-1.amazonaws.com"
        "us-east-2" = "602401143452.dkr.ecr.us-east-2.amazonaws.com"
        "us-gov-east-1" = "151742754352.dkr.ecr.us-gov-east-1.amazonaws.com"
        "us-gov-west-1" = "013241004608.dkr.ecr.us-gov-west-1.amazonaws.com"
        "us-west-1" = "602401143452.dkr.ecr.us-west-1.amazonaws.com"
        "us-west-2" = "602401143452.dkr.ecr.us-west-2.amazonaws.com"
    }
}

locals {
    charts = {
        "aws-load-balancer-controller" = {
            "values" = <<EOF
image:
  repository: ${lookup(local.eks_registries, var.cluster.location["region"], local.eks_registries["us-west-2"])}/amazon/aws-load-balancer-controller

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

vpcId: "${local.vpc.id}"

podDisruptionBudget:
  maxUnavailable: 1
EOF
        },
        "cluster-autoscaler" = {
            "values" = <<EOF
autoDiscovery:
  clusterName: ${var.cluster.meta["cluster_name"]}

awsRegion: "${var.cluster.location["region"]}"

cloudProvider: aws

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
  serviceAccount:
    annotations:
      eks.amazonaws.com/role-arn: "${module.iam_assumable_role_admin_cluster_autoscaler.iam_role_arn}"
EOF
        },
        "metrics-server" = {
            "values" = <<EOF
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
image:
  registry: us.gcr.io
  repository: k8s-artifacts-prod/external-dns/external-dns
  tag: v0.10.1

sources:
  - ingress

provider: aws

aws:
  region: "${var.cluster.location["region"]}"
  zoneType: "${length(regexall("^us-gov-", var.cluster.location["region"])) > 0 ? "private" : "public"}"
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
deployment:
  replicas: 2

ingressClass:
  enabled: true

ingressRoute:
  dashboard:
    enabled: false

providers:
  kubernetesIngress:
    publishedService:
      enabled: true

additionalArguments:
  - "--serverstransport.insecureskipverify=true"

ports:
  web:
    redirectTo: websecure
  websecure:
    tls:
      enabled: true

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

resources:
  requests:
    cpu: "1"
    memory: "1Gi"
  limits:
    cpu: "1"
    memory: "1Gi"

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
        }
    }
}

resource "null_resource" "create_aws_auth" {
    triggers = {
        kube_config_yaml = base64encode(local.kube_config_yaml)
        cmd_patch  = <<-EOT
            kubectl create configmap aws-auth -n kube-system --kubeconfig <(echo $KUBECONFIG | base64 --decode)
            kubectl patch configmap/aws-auth --patch "${module.eks.aws_auth_configmap_yaml}" -n kube-system --kubeconfig <(echo $KUBECONFIG | base64 --decode)
        EOT
    }

    provisioner "local-exec" {
        interpreter = ["/bin/bash", "-c"]
        environment = {
            KUBECONFIG = self.triggers.kube_config_yaml
        }
        command = self.triggers.cmd_patch
    }
}

resource "null_resource" "helm_module_sleep_after_destroy" {
    triggers = {
        sleep_after_destroy = "sleep 200"
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

    depends_on = [module.eks, module.vpc, module.iam_assumable_role_admin_cluster_autoscaler, module.iam_assumable_role_admin_aws_load_balancer_controller, module.iam_assumable_role_admin_external_dns, aws_eip.jarvice, local_file.kube_config, null_resource.create_aws_auth, null_resource.helm_module_sleep_after_destroy]
}

resource "kubernetes_daemonset" "aws_efa_k8s_device_plugin" {
    metadata {
        name = "aws-efa-k8s-device-plugin-daemonset"
        namespace = "kube-system"
    }

    spec {
        selector {
            match_labels = {
                name = "aws-efa-k8s-device-plugin"
            }
        }
        strategy {
            type = "RollingUpdate"
        }

        template {
            metadata {
                labels = {
                    name = "aws-efa-k8s-device-plugin"
                }
            }

            spec {
                service_account_name = "default"
                toleration {
                    key = "CriticalAddonsOnly"
                    operator = "Exists"
                }
                toleration {
                    key = "aws.amazon.com/efa"
                    operator = "Exists"
                    effect = "NoSchedule"
                }
                toleration {
                    key = "node-role.jarvice.io/jarvice-compute"
                    operator = "Exists"
                }
                priority_class_name = "system-node-critical"
                affinity {
                    node_affinity {
                        required_during_scheduling_ignored_during_execution {
                            node_selector_term {
                                match_expressions {
                                    key = "node.kubernetes.io/instance-type"
                                    operator = "In"
                                    values = [
                                        "c5n.18xlarge",
                                        "c5n.metal",
                                        "g4dn.metal",
                                        "i3en.24xlarge",
                                        "i3en.metal",
                                        "inf1.24xlarge",
                                        "m5dn.24xlarge",
                                        "m5n.24xlarge",
                                        "p3dn.24xlarge",
                                        "r5dn.24xlarge",
                                        "r5n.24xlarge",
                                        "p4d.24xlarge"
                                    ]
                                }
                            }
                        }
                    }
                }
                host_network = true
                volume {
                    name = "device-plugin"
                    host_path {
                        path = "/var/lib/kubelet/device-plugins"
                    }
                }
                container {
                    image = "${lookup(local.eks_registries, var.cluster.location["region"], local.eks_registries["us-west-2"])}/eks/aws-efa-k8s-device-plugin:v0.3.3"
                    image_pull_policy = "Always"
                    name = "aws-efa-k8s-device-plugin"
                    security_context {
                        allow_privilege_escalation = false
                        capabilities {
                            drop = ["ALL"]
                        }
                    }
                    volume_mount {
                        name = "device-plugin"
                        mount_path = "/var/lib/kubelet/device-plugins"
                    }
                }
            }
        }
    }

    depends_on = [module.eks, module.vpc, local_file.kube_config, null_resource.create_aws_auth]
}

