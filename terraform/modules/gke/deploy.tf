# deploy.tf - GKE module kubernetes/helm components deployment for JARVICE

module "common" {
    source = "../common"

    global = var.global
    cluster = var.cluster

    system_nodes_type_upstream = "n1-standard-8"
    system_nodes_type_downstream = "n1-standard-4"
    storage_class_provisioner = "kubernetes.io/gce-pd"
}

locals {
    charts = {
        "traefik" = {
            "values" = <<EOF
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

ssl:
  enabled: true
  enforced: true
  permanentRedirect: true
  insecureSkipVerify: true
  generateTLS: true

dashboard:
  enabled: false

rbac:
  enabled: true
EOF
        }
    }
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
# GKE cluster override values
${local.jarvice_ingress}
EOF

    depends_on = [google_container_cluster.jarvice, google_container_node_pool.jarvice_system]
}

resource "kubernetes_daemonset" "nvidia_driver_installer_cos" {
    count = 0

    metadata {
        name = "nvidia-driver-installer"
        namespace = "kube-system"
        labels = {
            k8s-app = "nvidia-driver-installer"
        }
    }

    spec {
        selector {
            match_labels = {
                k8s-app = "nvidia-driver-installer"
            }
        }
        strategy {
            type = "RollingUpdate"
        }

        template {
            metadata {
                labels = {
                    name = "nvidia-driver-installer"
                    k8s-app = "nvidia-driver-installer"
                }
            }

            spec {
                affinity {
                    node_affinity {
                        required_during_scheduling_ignored_during_execution {
                            node_selector_term {
                                match_expressions {
                                    key = "cloud.google.com/gke-accelerator"
                                    operator = "Exists"
                                }
                            }
                        }
                    }
                }
                toleration {
                    operator = "Exists"
                }
                host_network = true
                host_pid = true
                volume {
                    name = "dev"
                    host_path {
                        path = "/dev"
                    }
                }
                volume {
                    name = "vulkan-icd-mount"
                    host_path {
                        path = "/home/kubernetes/bin/nvidia/vulkan/icd.d"
                    }
                }
                volume {
                    name = "nvidia-install-dir-host"
                    host_path {
                        path = "/home/kubernetes/bin/nvidia"
                    }
                }
                volume {
                    name = "root-mount"
                    host_path {
                        path = "/"
                    }
                }
                volume {
                    name = "cos-tools"
                    host_path {
                        path = "/var/lib/cos-tools"
                    }
                }
                init_container {
                    image = "cos-nvidia-installer:fixed"
                    image_pull_policy = "Never"
                    name = "nvidia-driver-installer"
                    resources {
                        requests {
                            cpu = "0.15"
                        }
                    }
                    security_context {
                        privileged = true
                    }
                    env {
                        name = "NVIDIA_INSTALL_DIR_HOST"
                        value = "/home/kubernetes/bin/nvidia"
                    }
                    env {
                        name = "NVIDIA_INSTALL_DIR_CONTAINER"
                        value = "/usr/local/nvidia"
                    }
                    env {
                        name = "VULKAN_ICD_DIR_HOST"
                        value = "/home/kubernetes/bin/nvidia/vulkan/icd.d"
                    }
                    env {
                        name = "VULKAN_ICD_DIR_CONTAINER"
                        value = "/etc/vulkan/icd.d"
                    }
                    env {
                        name = "ROOT_MOUNT_DIR"
                        value = "/root"
                    }
                    env {
                        name = "COS_TOOLS_DIR_HOST"
                        value = "/var/lib/cos-tools"
                    }
                    env {
                        name = "COS_TOOLS_DIR_CONTAINER"
                        value = "/build/cos-tools"
                    }
                }
                container {
                    image = "gcr.io/google-containers/pause:2.0"
                    name  = "pause"
                }
            }
        }
    }
}

