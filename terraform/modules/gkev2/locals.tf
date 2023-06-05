# locals.tf - GKE v2 module local variable definitions

locals {
    kube_config = {
        "config_path" = "~/.kube/config-tf.gkev2.${var.cluster.location["region"]}.${var.cluster.meta["cluster_name"]}",
        "host" = "https://${google_container_cluster.jarvice.endpoint}",
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
    enable_gcfs = anytrue([
        for pool in values(var.cluster["compute_node_pools"]):
            lookup(pool.meta, "enable_gcfs", "false") == "true" ? true : false
    ])
    enable_gcfs_all_with_accelerator = alltrue(compact([
        for pool in values(var.cluster["compute_node_pools"]):
            lookup(pool.meta, "accelerator_type", null) == null && lookup(pool.meta, "accelerator_count", null) == null ? "" : lookup(pool.meta, "enable_gcfs", "false") == "true" ? "true" : "false"
    ]))
    cluster_values_yaml = <<EOF
jarvice:
  JARVICE_JOBS_DOMAIN: "lookup/job$"
  daemonsets:
    tolerations: '[{"key": "node-role.jarvice.io/jarvice-compute", "effect": "NoSchedule", "operator": "Exists"}, {"key": "node-role.kubernetes.io/jarvice-compute", "effect": "NoSchedule", "operator": "Exists"}, {"key": "CriticalAddonsOnly", "operator": "Exists"}, {"key": "nvidia.com/gpu", "effect": "NoSchedule", "operator": "Exists"}]'
    lxcfs:
      enabled: true
      env:
        HOST_LXCFS_DIR: /var/lib/toolbox/jarvice/lxcfs
        HOST_LXCFS_INSTALL_DIR: /var/lib/toolbox/jarvice/lxcfs-daemonset
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
      nodeAffinity: '{"requiredDuringSchedulingIgnoredDuringExecution": {"nodeSelectorTerms": [{"matchExpressions": [{"key": "cloud.google.com/gke-accelerator", "operator": "Exists"}, {"key": "cloud.google.com/gke-os-distribution", "operator": "In", "values": ["ubuntu"]}, {"key": "cloud.google.com/gke-container-runtime", "operator": "In", "values": ["docker"]}]}] }}'
    dri_optional:
      enabled: true
      env:
        DRI_INIT_DELAY: ${local.enable_gcfs_all_with_accelerator == true ? "90" : "180"}
        DRI_DEFAULT_CAPACITY: 128
    flex_volume_plugin_nfs_nolock_install:
      enabled: true
      tolerations: '[{"key": "node-role.jarvice.io/jarvice-compute", "effect": "NoSchedule", "operator": "Exists"}, {"key": "node-role.kubernetes.io/jarvice-compute", "effect": "NoSchedule", "operator": "Exists"}, {"key": "node-role.jarvice.io/jarvice-system", "effect": "NoSchedule", "operator": "Exists"}, {"key": "node-role.kubernetes.io/jarvice-system", "effect": "NoSchedule", "operator": "Exists"}, {"key": "node-role.jarvice.io/jarvice-storage", "effect": "NoSchedule", "operator": "Exists"}, {"key": "node-role.kubernetes.io/jarvice-storage", "effect": "NoSchedule", "operator": "Exists"}, {"key": "CriticalAddonsOnly", "operator": "Exists"}, {"key": "nvidia.com/gpu", "effect": "NoSchedule", "operator": "Exists"}]'
      env:
        KUBELET_PLUGIN_DIR: /home/kubernetes/flexvolume

jarvice_images_pull:
  enabled: ${local.enable_gcfs == true ? "true" : "false"}
  tolerations: '[{"key": "node-role.jarvice.io/jarvice-images-pull", "effect": "NoSchedule", "operator": "Exists"}]'
  nodeAffinity: '{"requiredDuringSchedulingIgnoredDuringExecution": {"nodeSelectorTerms": [{"matchExpressions": [{"key": "node-role.jarvice.io/jarvice-images-pull", "operator": "Exists"}]}] }}'
EOF
    jarvice_ingress_upstream = <<EOF
${local.cluster_values_yaml}

# GKE v2 cluster upstream ingress related settings
jarvice_license_manager:
  #ingressPath: "/license-manager"
  #ingressHost: "${var.cluster.meta["cluster_name"]}.${var.cluster.location["region"]}.gkev2.jarvice.${google_compute_address.jarvice.address}.nip.io"
  nodeAffinity: '{"requiredDuringSchedulingIgnoredDuringExecution": {"nodeSelectorTerms": [{"matchExpressions": [{"key": "node-role.jarvice.io/jarvice-system", "operator": "Exists"}, {"key": "kubernetes.io/arch", "operator": "In", "values": ["amd64"]}]}] }}'

jarvice_api:
  ingressPath: "/api"
  ingressHost: "${var.cluster.meta["cluster_name"]}.${var.cluster.location["region"]}.gkev2.jarvice.${google_compute_address.jarvice.address}.nip.io"

jarvice_mc_portal:
  ingressPath: "/"
  ingressHost: "${var.cluster.meta["cluster_name"]}.${var.cluster.location["region"]}.gkev2.jarvice.${google_compute_address.jarvice.address}.nip.io"
EOF

    jarvice_ingress_downstream = <<EOF
${local.cluster_values_yaml}

# GKE v2 cluster upstream ingress related settings
jarvice_k8s_scheduler:
  ingressHost: "${var.cluster.meta["cluster_name"]}.${var.cluster.location["region"]}.gkev2.jarvice.${google_compute_address.jarvice.address}.nip.io"
EOF

    jarvice_ingress = module.common.jarvice_cluster_type == "downstream" ? local.jarvice_ingress_downstream : local.jarvice_ingress_upstream
}

