# locals.tf - EKS module local variable definitions

locals {
    jarvice_values_file = replace(replace("${var.cluster.helm.jarvice["values_file"]}", "<region>", "${var.cluster.location["region"]}"), "<cluster_name>", "${var.cluster.meta["cluster_name"]}")

    jarvice_helm_override_yaml = fileexists(local.jarvice_values_file) ? "${file("${local.jarvice_values_file}")}" : ""

    jarvice_helm_values = merge(lookup(yamldecode("XXXdummy: value\n\n${fileexists(var.global.helm.jarvice["values_file"]) ? file(var.global.helm.jarvice["values_file"]) : ""}"), "jarvice", {}), lookup(yamldecode("XXXdummy: value\n\n${local.jarvice_helm_override_yaml}"), "jarvice", {}), lookup(yamldecode("XXXdummy: value\n\n${var.global.helm.jarvice["values_yaml"]}"), "jarvice", {}), lookup(yamldecode("XXXdummy: value\n\n${var.cluster.helm.jarvice["values_yaml"]}"), "jarvice", {}))

    jarvice_cluster_type = local.jarvice_helm_values["JARVICE_CLUSTER_TYPE"] == "downstream" ? "downstream" : "upstream"
}

locals {
    system_nodes_type = var.cluster.system_node_pool["nodes_type"] != null ? var.cluster.system_node_pool["nodes_type"] : local.jarvice_cluster_type == "downstream" ? "m5.xlarge" : "m5.4xlarge"
    system_nodes_num = var.cluster.system_node_pool["nodes_num"] != null ? var.cluster.system_node_pool["nodes_num"] : local.jarvice_cluster_type == "downstream" ? 2 : 3
}

locals {
    ssh_public_key = var.cluster.meta["ssh_public_key"] != null ? file(var.cluster.meta["ssh_public_key"]) : file(var.global.meta["ssh_public_key"])
}

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
    jarvice_config = {
        "ingress_host_path" = "~/.terraform-jarvice/ingress-tf.eks.${var.cluster.location.region}.${var.cluster.meta["cluster_name"]}"
    }
}

locals {
    jarvice_ingress_upstream = <<EOF
# EKS cluster override yaml
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
# EKS cluster override yaml
jarvice_k8s_scheduler:
  #ingressHost: {aws_eip.nat[0].public_dns}
  ingressHost: "lookup"
  ingressService: "traefik"
  ingressServiceNamespace: "kube-system"
EOF

    jarvice_ingress = local.jarvice_cluster_type == "downstream" ? local.jarvice_ingress_downstream : local.jarvice_ingress_upstream
    jarvice_ingress_name = local.jarvice_cluster_type == "downstream" ? "jarvice-k8s-scheduler" : "jarvice-mc-portal"

    storage_class_provisioner = "kubernetes.io/aws-ebs"
    cluster_values_yaml = <<EOF
# EKS cluster override values
jarvice:
  tolerations: '[{"key": "node-role.jarvice.io/jarvice-system", "effect": "NoSchedule", "operator": "Exists"}]'
  nodeSelector: '{"node-role.jarvice.io/jarvice-system": "true"}'

  JARVICE_PVC_VAULT_NAME: ${local.jarvice_helm_values["JARVICE_PVC_VAULT_NAME"] == null ? "persistent" : local.jarvice_helm_values["JARVICE_PVC_VAULT_NAME"]}
  JARVICE_PVC_VAULT_STORAGECLASS: ${local.jarvice_helm_values["JARVICE_PVC_VAULT_STORAGECLASS"] == null ? "jarvice-user" : local.jarvice_helm_values["JARVICE_PVC_VAULT_STORAGECLASS"]}
  JARVICE_PVC_VAULT_STORAGECLASS_PROVISIONER: ${local.storage_class_provisioner}
  JARVICE_PVC_VAULT_ACCESSMODES: ${local.jarvice_helm_values["JARVICE_PVC_VAULT_ACCESSMODES"] == null ? "ReadWriteOnce" : local.jarvice_helm_values["JARVICE_PVC_VAULT_ACCESSMODES"]}
  JARVICE_PVC_VAULT_SIZE: ${local.jarvice_helm_values["JARVICE_PVC_VAULT_SIZE"] == null ? 10 : local.jarvice_helm_values["JARVICE_PVC_VAULT_SIZE"]}

  daemonsets:
    lxcfs:
      enabled: true
      tolerations: '[{"key": "node-role.jarvice.io/jarvice-compute", "effect": "NoSchedule", "operator": "Exists"}]'
      nodeSelector: '{"node-role.jarvice.io/jarvice-compute": "true"}'

jarvice_db:
  persistence:
    enabled: true
    storageClassProvisioner: ${local.storage_class_provisioner}

${local.jarvice_ingress}
EOF
}

locals {
    cluster_output_message = local.jarvice_cluster_type == "downstream" ? "Add the downstream cluster URL to an upstream JARVICE cluster" : "Open the portal URL to initialize JARVICE"
}

