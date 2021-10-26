# main.tf - GKE module

terraform {
    required_providers {
        google = "~> 3.68.0"
        google-beta = "~> 3.68.0"

        helm = "~> 2.1.2"
        kubernetes = "~> 2.1.0"

        null = "~> 3.1.0"
        local = "~> 2.1.0"
        random = "~> 3.1.0"
    }
}

data "google_project" "jarvice" {
}

locals {
    project = trimprefix(data.google_project.jarvice.id, "projects/")
    region = var.cluster.location["region"]
    zones = var.cluster.location["zones"]

    oauth_scopes = [
        "https://www.googleapis.com/auth/devstorage.read_only",
        "https://www.googleapis.com/auth/logging.write",
        "https://www.googleapis.com/auth/monitoring",
        "https://www.googleapis.com/auth/pubsub",
        "https://www.googleapis.com/auth/service.management.readonly",
        "https://www.googleapis.com/auth/servicecontrol",
        "https://www.googleapis.com/auth/trace.append",
        "https://www.googleapis.com/auth/compute",
        "https://www.googleapis.com/auth/cloud-platform"
    ]

    project_services = [
        "compute.googleapis.com",
        "container.googleapis.com",
        "dns.googleapis.com"
    ]

    username = "kubernetes-admin"
}

resource "google_project_service" "project_services" {
    for_each = toset(local.project_services)

    service = each.value
    disable_dependent_services = false
    disable_on_destroy = false
}

data "google_client_config" "jarvice" {
}

data "google_container_engine_versions" "kubernetes_version" {
    #provider = google-beta

    location = local.region
    version_prefix = "${var.cluster.meta["kubernetes_version"]}."
}

locals {
    master_version = data.google_container_engine_versions.kubernetes_version.latest_master_version
    node_version = data.google_container_engine_versions.kubernetes_version.latest_node_version
}

resource "google_container_cluster" "jarvice" {
    #provider = google-beta

    name = var.cluster.meta["cluster_name"]
    location = local.region
    node_locations = local.zones

    min_master_version = local.master_version
    node_version = local.node_version

    #release_channel {
    #    channel = "STABLE"
    #}

    initial_node_count = 2
    remove_default_node_pool = false

    node_config {
        machine_type = "n1-standard-1"

        image_type = "UBUNTU_CONTAINERD"

        service_account = "default"
        oauth_scopes = local.oauth_scopes

        metadata = {
            disable-legacy-endpoints = "true"
            ssh-keys = <<EOF
${local.username}:${module.common.ssh_public_key}
EOF
        }

        #workload_metadata_config {
        #    node_metadata = "GKE_METADATA_SERVER"
        #}

        labels = {
            "node-role.jarvice.io/default" = "true"
        }

        tags = [var.cluster.meta["cluster_name"], "jxedefault"]
    }

    #workload_identity_config {
    #    identity_namespace = "${local.project}.svc.id.goog"
    #}

    network = "default"
    subnetwork = "default"

    ip_allocation_policy {
        cluster_ipv4_cidr_block = ""
        services_ipv4_cidr_block = ""
    }
    default_max_pods_per_node = 110

    #addons_config {
    #    horizontal_pod_autoscaling {
    #        disabled = false
    #    }
    #    http_load_balancing {
    #        disabled = false
    #    }
    #}

    resource_labels = {
        "cluster_name" = var.cluster.meta["cluster_name"]
    }

    depends_on = [google_project_service.project_services]

    lifecycle {
        #ignore_changes = [min_master_version, node_version, node_config[0].workload_metadata_config, workload_identity_config]
        ignore_changes = [min_master_version, node_version]
    }
}

resource "google_container_node_pool" "jarvice_system" {
    #provider = google-beta

    name = "jxesystem"
    location = local.region
    node_locations = local.zones

    cluster = google_container_cluster.jarvice.name
    version = local.node_version

    initial_node_count = module.common.system_nodes_num
    autoscaling {
        min_node_count = module.common.system_nodes_num
        max_node_count = module.common.system_nodes_num * 2
    }

    management {
        auto_repair = true
        auto_upgrade = false
    }

    node_config {
        machine_type = module.common.system_nodes_type

        image_type = "UBUNTU_CONTAINERD"

        service_account = "default"
        oauth_scopes = local.oauth_scopes

        metadata = {
            disable-legacy-endpoints = "true"
            ssh-keys = <<EOF
${local.username}:${module.common.ssh_public_key}
EOF
        }

        labels = {
            "node-role.jarvice.io/jarvice-system" = "true"
            "node-pool.jarvice.io/jarvice-system" = "jxesystem"
        }
        taint = [
            {
                key = "node-role.jarvice.io/jarvice-system"
                value = "true"
                effect = "NO_SCHEDULE"
            }
        ]

        tags = [google_container_cluster.jarvice.name, "jxesystem"]
    }

    lifecycle {
        ignore_changes = [version, initial_node_count]
    }
}

resource "google_container_node_pool" "jarvice_dockerbuild" {
    count = module.common.jarvice_cluster_type == "downstream" || var.cluster.dockerbuild_node_pool["nodes_type"] == null ? 0 : 1

    #provider = google-beta

    name = "jxedockerbuild"
    location = local.region
    node_locations = local.zones

    cluster = google_container_cluster.jarvice.name
    version = local.node_version

    initial_node_count = var.cluster.dockerbuild_node_pool["nodes_num"]
    autoscaling {
        min_node_count = var.cluster.dockerbuild_node_pool["nodes_min"]
        max_node_count = var.cluster.dockerbuild_node_pool["nodes_max"]
    }

    management {
        auto_repair = true
        auto_upgrade = false
    }

    node_config {
        machine_type = var.cluster.dockerbuild_node_pool["nodes_type"]

        image_type = "UBUNTU_CONTAINERD"

        service_account = "default"
        oauth_scopes = local.oauth_scopes

        metadata = {
            disable-legacy-endpoints = "true"
            ssh-keys = <<EOF
${local.username}:${module.common.ssh_public_key}
EOF
        }

        labels = {
            "node-role.jarvice.io/jarvice-dockerbuild" = "true"
            "node-pool.jarvice.io/jarvice-dockerbuild" = "jxedockerbuild"
        }
        taint = [
            {
                key = "node-role.jarvice.io/jarvice-dockerbuild"
                value = "true"
                effect = "NO_SCHEDULE"
            }
        ]

        tags = [google_container_cluster.jarvice.name, "jxedockerbuild"]
    }

    lifecycle {
        ignore_changes = [version, initial_node_count]
    }
}

#resource "google_compute_resource_policy" "jarvice_compute" {
#    name = var.cluster.meta["cluster_name"]
#    region = local.region
#    group_placement_policy {
#        availability_domain_count = 1
#        collocation = "COLLOCATED"
#    }
#}

resource "google_container_node_pool" "jarvice_compute" {
    for_each = var.cluster["compute_node_pools"]

    #provider = google-beta

    name = each.key
    location = local.region
    node_locations = lookup(each.value.meta, "zones", null) != null ? split(",", each.value.meta["zones"]) : local.zones

    cluster = google_container_cluster.jarvice.name
    version = local.node_version

    initial_node_count = each.value["nodes_num"]
    autoscaling {
        min_node_count = each.value["nodes_min"]
        max_node_count = each.value["nodes_max"]
    }

    management {
        auto_repair = false
        auto_upgrade = false
    }

    node_config {
        machine_type = each.value["nodes_type"]
        disk_size_gb = each.value["nodes_disk_size_gb"]
        disk_type = lookup(each.value.meta, "disk_type", "pd-standard")

        #image_type = "UBUNTU_CONTAINERD"
        image_type = "UBUNTU"

        #min_cpu_platform = "Intel Skylake"
        #disk_type = "pd-ssd"

        guest_accelerator {
            type = lookup(each.value.meta, "accelerator_type", "")
            count = lookup(each.value.meta, "accelerator_count", 0)
        }

        service_account = "default"
        oauth_scopes = local.oauth_scopes

        metadata = {
            disable-legacy-endpoints = "true"
            ssh-keys = <<EOF
${local.username}:${module.common.ssh_public_key}
EOF
        }

        labels = {
            "node-role.jarvice.io/jarvice-compute" = "true"
            "node-pool.jarvice.io/jarvice-compute" = each.key
            "node-pool.jarvice.io/disable-hyperthreading" = lookup(each.value.meta, "disable_hyperthreading", "false")
        }
        taint = [
            {
                key = "node-role.jarvice.io/jarvice-compute"
                value = "true"
                effect = "NO_SCHEDULE"
            }
        ]

        tags = [google_container_cluster.jarvice.name, each.key]
    }

    lifecycle {
        ignore_changes = [version, initial_node_count, node_config[0].taint]
    }
}

