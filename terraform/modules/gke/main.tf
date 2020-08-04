# main.tf - GKE module

terraform {
    required_providers {
        google = "~> 3.32.0"
        google-beta = "~> 3.32.0"

        null = "~> 2.1"
        local = "~> 1.4"
        random = "~> 2.3"
    }
}

locals {
    zone = var.cluster["location"]
    region = join("-", slice(split("-", var.cluster["location"]), 0, 2))
}

locals {
    oauth_scopes = [
        "https://www.googleapis.com/auth/devstorage.read_only",
        "https://www.googleapis.com/auth/logging.write",
        "https://www.googleapis.com/auth/monitoring",
        "https://www.googleapis.com/auth/pubsub",
        "https://www.googleapis.com/auth/service.management.readonly",
        "https://www.googleapis.com/auth/servicecontrol",
        "https://www.googleapis.com/auth/trace.append",
        "https://www.googleapis.com/auth/compute"
    ]
}

locals {
    username = "kubernetes-admin"
}

resource "random_id" "password" {
    byte_length = 18
}

data "google_container_engine_versions" "kubernetes_version" {
    provider = google-beta

    location = local.zone
    version_prefix = "${var.cluster["kubernetes_version"]}."
}

resource "google_container_cluster" "jarvice" {
    provider = google-beta

    name = var.cluster["cluster_name"]
    location = local.region
    node_locations = [local.zone]

    min_master_version = data.google_container_engine_versions.kubernetes_version.release_channel_default_version["STABLE"]
    node_version = data.google_container_engine_versions.kubernetes_version.release_channel_default_version["STABLE"]

    release_channel {
        channel = "STABLE"
    }

    initial_node_count = 1
    remove_default_node_pool = true

    #cluster_autoscaling {
    #    enabled = true
    #    resource_limits {
    #        resource_type = "cpu"
    #        minimum = 1
    #        maximum = 999999999
    #    }
    #    resource_limits {
    #        resource_type = "memory"
    #        minimum = 1
    #        maximum = 999999999
    #    }
    #}

    addons_config {
        horizontal_pod_autoscaling {
            disabled = true
        }
        http_load_balancing {
            disabled = false
        }
    }

    master_auth {
        username = local.username
        password = random_id.password.hex

        client_certificate_config {
            issue_client_certificate = true
        }
    }
}

resource "google_container_node_pool" "jarvice_default" {
    name = "jxedefault"
    location = local.region
    node_locations = [local.zone]

    cluster = google_container_cluster.jarvice.name
    version = data.google_container_engine_versions.kubernetes_version.release_channel_default_version["STABLE"]

    node_count = 2

    management {
        auto_upgrade = false
        auto_repair = false
    }

    node_config {
        machine_type = "n1-standard-1"
        image_type = "UBUNTU"

        service_account = "default"
        oauth_scopes = local.oauth_scopes

        metadata = {
            disable-legacy-endpoints = "true"
            ssh-keys = <<EOF
${local.username}:${local.ssh_public_key}
EOF
        }

        labels = {
            #"node-role.kubernetes.io/default" = "true",
            "node-role.jarvice.io/default" = "true"
        }

        tags = [google_container_cluster.jarvice.name, "jxedefault"]
    }
}

resource "google_container_node_pool" "jarvice_system" {
    name = "jxesystem"
    location = local.region
    node_locations = [local.zone]

    cluster = google_container_cluster.jarvice.name
    version = data.google_container_engine_versions.kubernetes_version.release_channel_default_version["STABLE"]

    initial_node_count = var.cluster.system_node_pool["num_nodes"] != null ? var.cluster.system_node_pool["num_nodes"] : local.system_num_nodes
    autoscaling {
        min_node_count = var.cluster.system_node_pool["num_nodes"] != null ? var.cluster.system_node_pool["num_nodes"] : local.system_num_nodes
        max_node_count = var.cluster.system_node_pool["num_nodes"] != null ? var.cluster.system_node_pool["num_nodes"] * 2 : local.system_num_nodes * 2
    }

    management {
        auto_upgrade = false
        auto_repair = false
    }

    node_config {
        machine_type = local.system_node_machine_type
        image_type = "UBUNTU"

        service_account = "default"
        oauth_scopes = local.oauth_scopes

        metadata = {
            disable-legacy-endpoints = "true"
            ssh-keys = <<EOF
${local.username}:${local.ssh_public_key}
EOF
        }

        labels = {
            #"node-role.kubernetes.io/jarvice-system" = "true",
            "node-role.jarvice.io/jarvice-system" = "true"
        }
        taint = [
            {
                key = "node-role.kubernetes.io/jarvice-system"
                value = "true"
                effect = "NO_SCHEDULE"
            }
        ]

        tags = [google_container_cluster.jarvice.name, "jxesystem"]
    }
}

resource "google_container_node_pool" "jarvice_compute" {
    count = length(var.cluster["compute_node_pools"])

    name = "jxecompute${count.index}"
    location = local.region
    node_locations = [local.zone]

    cluster = google_container_cluster.jarvice.name
    version = data.google_container_engine_versions.kubernetes_version.release_channel_default_version["STABLE"]

    initial_node_count = var.cluster.compute_node_pools[count.index]["num_nodes"]
    autoscaling {
        min_node_count = var.cluster.compute_node_pools[count.index]["min_nodes"]
        max_node_count = var.cluster.compute_node_pools[count.index]["max_nodes"]
    }

    management {
        auto_upgrade = false
        auto_repair = false
    }

    node_config {
        machine_type = var.cluster.compute_node_pools[count.index]["machine_type"]
        disk_size_gb = var.cluster.compute_node_pools[count.index]["disk_size_gb"]
        image_type = "UBUNTU"
        min_cpu_platform = "Intel Skylake"
        disk_type = "pd-ssd"

        #guest_accelerator {
        #    type = "nvidia-tesla-p100"
        #    count = 1
        #}

        service_account = "default"
        oauth_scopes = local.oauth_scopes

        metadata = {
            disable-legacy-endpoints = "true"
            ssh-keys = <<EOF
${local.username}:${local.ssh_public_key}
EOF
        }

        labels = {
            #"node-role.kubernetes.io/jarvice-compute" = "true",
            "node-role.jarvice.io/jarvice-compute" = "true"
        }
        taint = [
            {
                key = "node-role.kubernetes.io/jarvice-compute"
                value = "true"
                effect = "NO_SCHEDULE"
            }
        ]

        tags = [google_container_cluster.jarvice.name, "jxecompute${count.index}"]
    }
}

