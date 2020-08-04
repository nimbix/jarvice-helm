# locals.tf - GKE module local variable definitions

locals {
    jarvice_override_yaml_file = replace(replace("${var.cluster.helm.jarvice["override_yaml_file"]}", "<location>", "${var.cluster["location"]}"), "<cluster_name>", "${var.cluster["cluster_name"]}")

    jarvice_helm_override_yaml = fileexists(local.jarvice_override_yaml_file) ? "${file("${local.jarvice_override_yaml_file}")}" : ""

    jarvice_helm_values = merge(lookup(yamldecode("XXXdummy: value\n\n${file("values.yaml")}"), "jarvice", {}), lookup(yamldecode("XXXdummy: value\n\n${local.jarvice_helm_override_yaml}"), "jarvice", {}), lookup(yamldecode("XXXdummy: value\n\n${var.global.helm.jarvice["override_yaml_values"]}"), "jarvice", {}), lookup(yamldecode("XXXdummy: value\n\n${var.cluster.helm.jarvice["override_yaml_values"]}"), "jarvice", {}))

    jarvice_cluster_type = local.jarvice_helm_values["JARVICE_CLUSTER_TYPE"] == "downstream" ? "downstream" : "upstream"
}

locals {
    system_node_machine_type = local.jarvice_cluster_type == "downstream" ? "n1-standard-4" : "n1-standard-8"
    system_num_nodes = local.jarvice_cluster_type == "downstream" ? 2 : 3
}

locals {
    ssh_public_key = var.cluster["ssh_public_key"] != null ? file(var.cluster["ssh_public_key"]) : file(var.global["ssh_public_key"])
}

locals {
    kube_config = {
        "path" = "~/.kube/config-tf.gke.${var.cluster["location"]}.${var.cluster["cluster_name"]}",
        "host" = google_container_cluster.jarvice.endpoint,
        "cluster_ca_certificate" = google_container_cluster.jarvice.master_auth.0.cluster_ca_certificate,
        "client_certificate" = google_container_cluster.jarvice.master_auth.0.client_certificate,
        "client_key" = google_container_cluster.jarvice.master_auth.0.client_key,
        "token" = null,
        "username" = google_container_cluster.jarvice.master_auth.0.username,
        "password" = google_container_cluster.jarvice.master_auth.0.password
    }
}

locals {
    jarvice_config = {
        "ingress_host_path" = "~/.terraform-jarvice/ingress-tf.gke.${var.cluster.location}.${var.cluster["cluster_name"]}"
    }
}

locals {
    jarvice_ingress_upstream = <<EOF
# GKE cluster override yaml
jarvice_api:
  ingressPath: "/api"
  ingressHost: "-"

jarvice_mc_portal:
  ingressPath: "/"
  ingressHost: "-"
EOF

    jarvice_ingress_downstream = <<EOF
# GKE cluster override yaml
jarvice_k8s_scheduler:
  ingressHost: "-"
EOF

    jarvice_ingress = local.jarvice_cluster_type == "downstream" ? local.jarvice_ingress_downstream : local.jarvice_ingress_upstream
    jarvice_ingress_name = local.jarvice_cluster_type == "downstream" ? "jarvice-k8s-scheduler" : "jarvice-mc-portal"

    storage_class_provisioner = "kubernetes.io/gce-pd"
    cluster_override_yaml_values = <<EOF
# GKE cluster override values
jarvice:
  nodeSelector: '${local.jarvice_helm_values["nodeSelector"] == null ? "{\"node-role.jarvice.io/jarvice-system\": \"true\"}" : local.jarvice_helm_values["nodeSelector"]}'
  #nodeSelector: '${local.jarvice_helm_values["nodeSelector"] == null ? "{\"node-role.kubernetes.io/jarvice-system\": \"true\"}" : local.jarvice_helm_values["nodeSelector"]}'

  JARVICE_PVC_VAULT_NAME: ${local.jarvice_helm_values["JARVICE_PVC_VAULT_NAME"] == null ? "persistent" : local.jarvice_helm_values["JARVICE_PVC_VAULT_NAME"]}
  JARVICE_PVC_VAULT_STORAGECLASS: ${local.jarvice_helm_values["JARVICE_PVC_VAULT_STORAGECLASS"] == null ? "jarvice-user" : local.jarvice_helm_values["JARVICE_PVC_VAULT_STORAGECLASS"]}
  JARVICE_PVC_VAULT_STORAGECLASS_PROVISIONER: ${local.storage_class_provisioner}
  JARVICE_PVC_VAULT_ACCESSMODES: ${local.jarvice_helm_values["JARVICE_PVC_VAULT_ACCESSMODES"] == null ? "ReadWriteOnce" : local.jarvice_helm_values["JARVICE_PVC_VAULT_ACCESSMODES"]}
  JARVICE_PVC_VAULT_SIZE: ${local.jarvice_helm_values["JARVICE_PVC_VAULT_SIZE"] == null ? 10 : local.jarvice_helm_values["JARVICE_PVC_VAULT_SIZE"]}

jarvice_db:
  persistence:
    storageClassProvisioner: ${local.storage_class_provisioner}

${local.jarvice_ingress}
EOF
}

locals {
    cluster_output_message = local.jarvice_cluster_type == "downstream" ? "Add the downstream cluster URL to an upstream JARVICE cluster" : "Open the portal URL to initialize JARVICE"
}

