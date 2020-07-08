# locals.tf - EKS module local variable definitions

locals {
    jarvice_override_yaml_file = replace(replace("${var.eks.helm.jarvice["override_yaml_file"]}", "<region>", "${var.eks.region}"), "<cluster_name>", "${var.eks["cluster_name"]}")

    jarvice_helm_override_yaml = fileexists(local.jarvice_override_yaml_file) ? "${file("${local.jarvice_override_yaml_file}")}" : ""

    jarvice_helm_values = merge(lookup(yamldecode("XXXdummy: value\n\n${file("values.yaml")}"), "jarvice", {}), lookup(yamldecode("XXXdummy: value\n\n${local.jarvice_helm_override_yaml}"), "jarvice", {}), lookup(yamldecode("XXXdummy: value\n\n${var.global.helm.jarvice["override_yaml_values"]}"), "jarvice", {}), lookup(yamldecode("XXXdummy: value\n\n${var.eks.helm.jarvice["override_yaml_values"]}"), "jarvice", {}))

    jarvice_cluster_type = local.jarvice_helm_values["JARVICE_CLUSTER_TYPE"] == "downstream" ? "downstream" : "upstream"
}

locals {
    system_node_instance_type = local.jarvice_cluster_type == "downstream" ? "m5.2xlarge" : "m5.xlarge"
    system_node_asg_desired_capacity = local.jarvice_cluster_type == "downstream" ? 2 : 3
}

locals {
    kube_config = {
        "path" = "~/.kube/config-tf.eks.${var.eks.region}.${var.eks["cluster_name"]}",
        "host" = data.aws_eks_cluster.cluster.endpoint,
        "cluster_ca_certificate" = data.aws_eks_cluster.cluster.certificate_authority.0.data,
        "token" = data.aws_eks_cluster_auth.cluster.token,
        "client_certificate" = null,
        "client_key" = null
    }
}

locals {
    jarvice_ingress_upstream = <<EOF
# EKS cluster override yaml
#jarvice_api:
#  ingressHost: {aws_eip.nat[0].public_dns}
#  ingressPath: "/api"

#jarvice_mc_portal:
#  ingressHost: {aws_eip.nat[0].public_dns}
#  ingressPath: "/"
EOF

    jarvice_ingress_downstream = <<EOF
# EKS cluster override yaml
#jarvice_k8s_scheduler:
#  ingressHost: {aws_eip.nat[0].public_dns}
EOF

    jarvice_ingress = local.jarvice_cluster_type == "downstream" ? local.jarvice_ingress_downstream : local.jarvice_ingress_upstream

    cluster_override_yaml_values = <<EOF
# EKS cluster override values
jarvice:
  #nodeSelector: '${local.jarvice_helm_values["nodeSelector"] == null ? "{\"node-role.kubernetes.io/jarvice-system\": \"true\"}" : local.jarvice_helm_values["nodeSelector"]}'

  JARVICE_PVC_VAULT_NAME: ${local.jarvice_helm_values["JARVICE_PVC_VAULT_NAME"] == null ? "persistent" : local.jarvice_helm_values["JARVICE_PVC_VAULT_NAME"]}
  JARVICE_PVC_VAULT_STORAGECLASS: ${local.jarvice_helm_values["JARVICE_PVC_VAULT_STORAGECLASS"] == null ? "jarvice-user" : local.jarvice_helm_values["JARVICE_PVC_VAULT_STORAGECLASS"]}
  JARVICE_PVC_VAULT_STORAGECLASS_PROVISIONER: kubernetes.io/aws-ebs
  JARVICE_PVC_VAULT_ACCESSMODES: ${local.jarvice_helm_values["JARVICE_PVC_VAULT_ACCESSMODES"] == null ? "ReadWriteOnce" : local.jarvice_helm_values["JARVICE_PVC_VAULT_ACCESSMODES"]}
  JARVICE_PVC_VAULT_SIZE: ${local.jarvice_helm_values["JARVICE_PVC_VAULT_SIZE"] == null ? 10 : local.jarvice_helm_values["JARVICE_PVC_VAULT_SIZE"]}

jarvice_db:
  persistence:
    storageClassProvisioner: kubernetes.io/aws-ebs

${local.jarvice_ingress}
EOF
}

locals {
    cluster_output_message = local.jarvice_cluster_type == "downstream" ? "Add the downstream cluster URL to an upstream JARVICE cluster" : "Open the portal URL to initialize JARVICE"
}

