# locals.tf - EKS module local variable definitions

locals {
    kube_config = {
        "config_path" = "~/.kube/config-tf.eks.${var.cluster.location["region"]}.${var.cluster.meta["cluster_name"]}",
        "host" = data.aws_eks_cluster.cluster.endpoint,
        "cluster_ca_certificate" = data.aws_eks_cluster.cluster.certificate_authority.0.data,
        "client_certificate" = null,
        "client_key" = null,
        "token" = data.aws_eks_cluster_auth.cluster.token,
        "username" = null,
        "password" = null
    }
}

locals {
    jarvice_ingress_upstream = <<EOF
# EKS cluster upstream ingress related settings
jarvice:
  JARVICE_JOBS_DOMAIN: "lookup/job$"

jarvice_license_manager:
  #ingressPath: "/license-manager"
  ##ingressHost: {aws_eip.nat[0].public_dns}
  #ingressHost: "lookup"
  #ingressService: "traefik"
  #ingressServiceNamespace: "kube-system"
  nodeAffinity: '{"requiredDuringSchedulingIgnoredDuringExecution": {"nodeSelectorTerms": [{"matchExpressions": [{"key": "node-role.jarvice.io/jarvice-system", "operator": "Exists"}, {"key": "kubernetes.io/arch", "operator": "In", "values": ["amd64"]}]}] }}'

jarvice_api:
  ingressPath: "/api"
  #ingressHost: {aws_eip.nat[0].public_dns}
  ingressHost: "lookup"
  ingressService: "traefik"
  ingressServiceNamespace: "kube-system"

jarvice_mc_portal:
  ingressPath: "/"
  #ingressHost: {aws_eip.nat[0].public_dns}
  ingressHost: "lookup"
  ingressService: "traefik"
  ingressServiceNamespace: "kube-system"
EOF

    jarvice_ingress_downstream = <<EOF
# EKS cluster upstream ingress related settings
jarvice:
  JARVICE_JOBS_DOMAIN: "lookup/job$"

jarvice_k8s_scheduler:
  #ingressHost: {aws_eip.nat[0].public_dns}
  ingressHost: "lookup"
  ingressService: "traefik"
  ingressServiceNamespace: "kube-system"
EOF

    jarvice_ingress = module.common.jarvice_cluster_type == "downstream" ? local.jarvice_ingress_downstream : local.jarvice_ingress_upstream
}

locals {
    jarvice_ingress_name = module.common.jarvice_cluster_type == "downstream" ? "jarvice-k8s-scheduler" : "jarvice-mc-portal"

    jarvice_config = {
        "ingress_host_path" = "~/.terraform-jarvice/ingress-tf.eks.${var.cluster.location.region}.${var.cluster.meta["cluster_name"]}"
    }
}

