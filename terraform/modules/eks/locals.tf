# locals.tf - EKS module local variable definitions

locals {
    kube_config = {
        "config_path" = "~/.kube/config-tf.eks.${var.cluster.location["region"]}.${var.cluster.meta["cluster_name"]}",
        "host" = data.aws_eks_cluster.cluster.endpoint,
        "cluster_ca_certificate" = data.aws_eks_cluster.cluster.certificate_authority.0.data,
        "client_certificate" = "",
        "client_key" = "",
        "token" = data.aws_eks_cluster_auth.cluster.token
    }
}

locals {
    cluster_values_yaml = <<EOF
jarvice:
  JARVICE_JOBS_DOMAIN: "lookup/job$"
  daemonsets:
    nvidia:
      enabled: true
      nodeAffinity: '{"requiredDuringSchedulingIgnoredDuringExecution": {"nodeSelectorTerms": [{"matchExpressions": [{"key": "accelerator", "operator": "In", "values": ["nvidia"]}]}] }}'
EOF
    jarvice_ingress_upstream = <<EOF
${local.cluster_values_yaml}

# EKS cluster upstream ingress related settings
jarvice_license_manager:
  #ingressPath: "/license-manager"
  #ingressHost: "${var.cluster.meta["cluster_name"]}.${var.cluster.location["region"]}.eks.jarvice.${aws_eip.jarvice[0].public_ip}.nip.io"
  #ingressAnnotations:
  #  cert-manager.io/issue-temporary-certificate: "true"
  nodeAffinity: '{"requiredDuringSchedulingIgnoredDuringExecution": {"nodeSelectorTerms": [{"matchExpressions": [{"key": "node-role.jarvice.io/jarvice-system", "operator": "Exists"}, {"key": "kubernetes.io/arch", "operator": "In", "values": ["amd64"]}]}] }}'

jarvice_api:
  ingressPath: "/api"
  ingressHost: "${var.cluster.meta["cluster_name"]}.${var.cluster.location["region"]}.eks.jarvice.${aws_eip.jarvice[0].public_ip}.nip.io"
  ingressAnnotations:
    cert-manager.io/issue-temporary-certificate: "true"

jarvice_mc_portal:
  ingressPath: "/"
  ingressHost: "${var.cluster.meta["cluster_name"]}.${var.cluster.location["region"]}.eks.jarvice.${aws_eip.jarvice[0].public_ip}.nip.io"
  ingressAnnotations:
    cert-manager.io/issue-temporary-certificate: "true"
EOF

    jarvice_ingress_downstream = <<EOF
${local.cluster_values_yaml}

# EKS cluster upstream ingress related settings
jarvice_k8s_scheduler:
  ingressHost: "${var.cluster.meta["cluster_name"]}.${var.cluster.location["region"]}.eks.jarvice.${aws_eip.jarvice[0].public_ip}.nip.io"
  ingressAnnotations:
    cert-manager.io/issue-temporary-certificate: "true"
EOF

    jarvice_ingress = module.common.jarvice_cluster_type == "downstream" ? local.jarvice_ingress_downstream : local.jarvice_ingress_upstream
}

