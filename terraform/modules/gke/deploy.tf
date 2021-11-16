# deploy.tf - GKE module kubernetes/helm components deployment for JARVICE

module "common" {
    source = "../common"

    global = var.global
    cluster = var.cluster

    system_nodes_type_upstream = "n1-standard-8"
    system_nodes_type_downstream = "n1-standard-4"
    storage_class_provisioner = "kubernetes.io/gce-pd"
    storage_class_provisioner_dockerbuild = "pd.csi.storage.gke.io"
}

resource "google_service_account" "external_dns" {
    account_id = replace(substr("${var.cluster.meta["cluster_name"]}-external-dns", 0, 30), "/[^a-z0-9]$/", "")
    display_name = substr("JARVICE ExternalDNS service account for GKE cluster: ${var.cluster.meta["cluster_name"]}", 0, 100)
    project = lookup(var.cluster["meta"], "dns_zone_project", null)
}

resource "google_project_iam_member" "external_dns_admin" {
    role = "roles/dns.admin"
    member = "serviceAccount:${google_service_account.external_dns.email}"
    project = lookup(var.cluster["meta"], "dns_zone_project", local.project)
}

resource "google_service_account_key" "external_dns" {
    service_account_id = google_service_account.external_dns.name
}

#resource "google_service_account_iam_member" "external_dns_workload_identity_user" {
#    service_account_id = google_service_account.external_dns.name
#    role = "roles/iam.workloadIdentityUser"
#    member = "serviceAccount:${local.project}.svc.id.goog[${module.helm.metadata["external-dns"]["namespace"]}/external-dns]"
#}

resource "google_compute_address" "jarvice" {
    name = "${var.cluster.meta["cluster_name"]}-${var.cluster.location["region"]}"
    address_type = "EXTERNAL"

    depends_on = [google_container_cluster.jarvice]
}

locals {
    load_balancer_ip = lookup(var.cluster["meta"], "use_static_ip", null) != "false" ? "loadBalancerIP: ${google_compute_address.jarvice.address}" : ""

    charts = {
        "external-dns" = {
            "values" = <<EOF
image:
  registry: us.gcr.io
  repository: k8s-artifacts-prod/external-dns/external-dns
  tag: v0.8.0

sources:
  - ingress

provider: google

google:
  project: "${lookup(var.cluster["meta"], "dns_zone_project", local.project)}"
  serviceAccountKey: |
    ${indent(4, base64decode(google_service_account_key.external_dns.private_key))}

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

#serviceAccount:
#  annotations:
#    iam.gke.io/gcp-service-account: "${google_service_account.external_dns.email}"
EOF
        },
        "cert-manager" = {
            "values" = <<EOF
installCRDs: true

#ingressShim:
#  defaultIssuerName: letsencrypt-prod
#  defaultIssuerKind: ClusterIssuer
#  defaultIssuerGroup: cert-manager.io

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
        "traefik" = {
            "values" = <<EOF
imageTag: "1.7"

${local.load_balancer_ip}
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

kubernetes:
  ingressEndpoint:
    useDefaultPublishedService: true

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

    depends_on = [google_container_cluster.jarvice, google_container_node_pool.jarvice_system, google_container_node_pool.jarvice_compute, google_compute_address.jarvice, local_file.kube_config]
}

resource "kubernetes_daemonset" "nvidia_driver_installer_cos" {
    metadata {
        name = "nvidia-driver-installer-cos"
        namespace = "kube-system"
        labels = {
            k8s-app = "nvidia-driver-installer-cos"
        }
    }

    spec {
        selector {
            match_labels = {
                k8s-app = "nvidia-driver-installer-cos"
            }
        }
        strategy {
            type = "RollingUpdate"
        }

        template {
            metadata {
                labels = {
                    name = "nvidia-driver-installer-cos"
                    k8s-app = "nvidia-driver-installer-cos"
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
                                match_expressions {
                                    key = "cloud.google.com/gke-os-distribution"
                                    operator = "In"
                                    values = ["cos"]
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
                    name = "nvidia-driver-installer-cos"
                    resources {
                        requests = {
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
                    volume_mount {
                        name = "nvidia-install-dir-host"
                        mount_path = "/use/local/nvidia"
                    }
                    volume_mount {
                        name = "vulkan-icd-mount"
                        mount_path = "/etc/vulkan/idc.d"
                    }
                    volume_mount {
                        name = "dev"
                        mount_path = "/dev"
                    }
                    volume_mount {
                        name = "root-mount"
                        mount_path = "/root"
                    }
                    volume_mount {
                        name = "cos-tools"
                        mount_path = "/build/cos-tools"
                    }
                }
                container {
                    image = "gcr.io/google-containers/pause:2.0"
                    name  = "pause"
                }
            }
        }
    }

    depends_on = [google_container_cluster.jarvice, local_file.kube_config]
}

