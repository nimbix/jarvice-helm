# locals.tf - GKE module local variable definitions

locals {
    kube_config = {
        "config_path" = "~/.kube/config-tf.gke.${var.cluster.location["region"]}.${var.cluster.meta["cluster_name"]}",
        "host" = google_container_cluster.jarvice.endpoint,
        "cluster_ca_certificate" = google_container_cluster.jarvice.master_auth.0.cluster_ca_certificate,
        "client_certificate" = "",
        "client_key" = "",
        "token" = data.google_client_config.jarvice.access_token
    }
}

locals {
    disable_hyper_threading_pools = [
        for name, pool in var.cluster["compute_node_pools"]:
            name if lower(lookup(pool.meta, "disable_hyperthreading", "false")) == "true"
    ]
    cluster_values_yaml = <<EOF
jarvice:
  JARVICE_JOBS_DOMAIN: "lookup/job$"
  daemonsets:
    tolerations: '[{"key": "node-role.jarvice.io/jarvice-compute", "effect": "NoSchedule", "operator": "Exists"}, {"key": "node-role.kubernetes.io/jarvice-compute", "effect": "NoSchedule", "operator": "Exists"}, {"key": "CriticalAddonsOnly", "operator": "Exists"}, {"key": "nvidia.com/gpu", "effect": "NoSchedule", "operator": "Exists"}]'
    disable_hyper_threading:
      enabled: true
      nodeAffinity: '{"requiredDuringSchedulingIgnoredDuringExecution": {"nodeSelectorTerms": [{"matchExpressions": [{"key": "node-pool.jarvice.io/jarvice-compute", "operator": "In", "values": [${join(",", formatlist("\"%s\"", concat(local.disable_hyper_threading_pools, ["dummyXXX"])))}]}]} ] }}'
    node_init:
      enabled: true
      env:
        COMMAND: |
            echo "Disabling kernel check for hung tasks..."
            echo 0 > /proc/sys/kernel/hung_task_timeout_secs || /bin/true
            echo "Disabling kernel check for hung tasks...done."
    nvidia_install:
      enabled: true
      nodeAffinity: '{"requiredDuringSchedulingIgnoredDuringExecution": {"nodeSelectorTerms": [{"matchExpressions": [{"key": "cloud.google.com/gke-accelerator", "operator": "Exists"}]}] }}'
    dri_optional:
      enabled: true
      env:
        DRI_INIT_DELAY: 180
        DRI_DEFAULT_CAPACITY: 1
    flex_volume_plugin_nfs_nolock_install:
      enabled: true
      env:
        KUBELET_PLUGIN_DIR: /home/kubernetes/flexvolume
EOF
    jarvice_ingress_upstream = <<EOF
${local.cluster_values_yaml}

# GKE cluster upstream ingress related settings
jarvice_license_manager:
  #ingressPath: "/license-manager"
  #ingressHost: "${var.cluster.meta["cluster_name"]}.${var.cluster.location["region"]}.gke.jarvice.${google_compute_address.jarvice.address}.nip.io"
  nodeAffinity: '{"requiredDuringSchedulingIgnoredDuringExecution": {"nodeSelectorTerms": [{"matchExpressions": [{"key": "node-role.jarvice.io/jarvice-system", "operator": "Exists"}, {"key": "kubernetes.io/arch", "operator": "In", "values": ["amd64"]}]}] }}'

jarvice_api:
  ingressPath: "/api"
  ingressHost: "${var.cluster.meta["cluster_name"]}.${var.cluster.location["region"]}.gke.jarvice.${google_compute_address.jarvice.address}.nip.io"

jarvice_mc_portal:
  ingressPath: "/"
  ingressHost: "${var.cluster.meta["cluster_name"]}.${var.cluster.location["region"]}.gke.jarvice.${google_compute_address.jarvice.address}.nip.io"
EOF

    jarvice_ingress_downstream = <<EOF
${local.cluster_values_yaml}

# GKE cluster upstream ingress related settings
jarvice_k8s_scheduler:
  ingressHost: "${var.cluster.meta["cluster_name"]}.${var.cluster.location["region"]}.gke.jarvice.${google_compute_address.jarvice.address}.nip.io"
EOF

    jarvice_ingress = module.common.jarvice_cluster_type == "downstream" ? local.jarvice_ingress_downstream : local.jarvice_ingress_upstream
}

