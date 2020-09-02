# locals.tf - GKE module local variable definitions

locals {
    kube_config = {
        "config_path" = "~/.kube/config-tf.gke.${var.cluster.location["region"]}.${var.cluster.meta["cluster_name"]}",
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

    jarvice_ingress = module.common.jarvice_cluster_type == "downstream" ? local.jarvice_ingress_downstream : local.jarvice_ingress_upstream
}

locals {
    jarvice_ingress_name = module.common.jarvice_cluster_type == "downstream" ? "jarvice-k8s-scheduler" : "jarvice-mc-portal"

    jarvice_config = {
        "ingress_host_path" = "~/.terraform-jarvice/ingress-tf.gke.${var.cluster.location.region}.${var.cluster.meta["cluster_name"]}"
    }
}

