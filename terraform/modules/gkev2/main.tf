# main.tf - GKE v2 module

terraform {
    required_providers {
        google = "~> 4.66.0"

        helm = "~> 2.4"
        kubernetes = "~> 2.6"

        null = "~> 3.1"
        local = "~> 2.1"
        random = "~> 3.1"
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

    project_services = lookup(var.cluster["meta"], "dns_manage_records", false) ? [
        "compute.googleapis.com",
        "container.googleapis.com",
        "containerfilesystem.googleapis.com",
        "dns.googleapis.com"
    ]:[
        "compute.googleapis.com",
        "container.googleapis.com",
        "containerfilesystem.googleapis.com"
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
    location = local.region
    version_prefix = "${var.cluster.meta["kubernetes_version"]}."
}

locals {
    master_version = data.google_container_engine_versions.kubernetes_version.latest_master_version
    node_version = data.google_container_engine_versions.kubernetes_version.latest_node_version
}

resource "google_container_cluster" "jarvice" {
    name = var.cluster.meta["cluster_name"]
    location = local.region
    node_locations = local.zones

    min_master_version = local.master_version
    node_version = local.node_version

    release_channel {
        channel = coalesce(lookup(var.cluster.meta, "release_channel",  null), "UNSPECIFIED")
    }

    initial_node_count = 2
    remove_default_node_pool = false
    enable_shielded_nodes = true
    node_config {
        machine_type = "n1-standard-1"
        boot_disk_kms_key = lookup(var.cluster.meta, "kms_key",  null)
        image_type = "UBUNTU_CONTAINERD"

        service_account = coalesce(lookup(var.cluster.meta, "service_account",  null), "default")
        oauth_scopes = local.oauth_scopes

        metadata = {
            disable-legacy-endpoints = "true"
            ssh-keys = "${local.username}:${module.common.ssh_public_key}"
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
        #ignore_changes = [min_master_version, node_version, enable_shielded_nodes, node_config[0].workload_metadata_config, workload_identity_config]
        ignore_changes = [min_master_version, node_version, enable_shielded_nodes]
    }
}

resource "google_container_node_pool" "jarvice_system" {
    name = "jxesystem"
    location = local.region
    node_locations = local.zones

    cluster = google_container_cluster.jarvice.name
    version = google_container_cluster.jarvice.master_version

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
        boot_disk_kms_key = lookup(var.cluster.meta, "kms_key",  null)
        service_account = coalesce(lookup(var.cluster.meta, "service_account",  null), "default")
        oauth_scopes = local.oauth_scopes

        metadata = {
            disable-legacy-endpoints = "true"
            ssh-keys = "${local.username}:${module.common.ssh_public_key}"
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

    name = "jxedockerbuild"
    location = local.region
    node_locations = local.zones

    cluster = google_container_cluster.jarvice.name
    version = google_container_cluster.jarvice.master_version

    initial_node_count = var.cluster.dockerbuild_node_pool["nodes_num"]
    autoscaling {
        min_node_count = var.cluster.dockerbuild_node_pool["nodes_min"]
        max_node_count = var.cluster.dockerbuild_node_pool["nodes_max"]
    }

    management {
        auto_repair = false
        auto_upgrade = false
    }

    node_config {
        machine_type = var.cluster.dockerbuild_node_pool["nodes_type"]
        boot_disk_kms_key = lookup(var.cluster.meta, "kms_key",  null)
        image_type = "UBUNTU_CONTAINERD"

        service_account = coalesce(lookup(var.cluster.meta, "service_account",  null), "default")
        oauth_scopes = local.oauth_scopes

        metadata = {
            disable-legacy-endpoints = "true"
            ssh-keys = "${local.username}:${module.common.ssh_public_key}"
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

resource "google_container_node_pool" "jarvice_images_pull" {
    count = local.enable_gcfs == true ? 1 : 0

    name = "jxeimagespull"
    location = local.region
    node_locations = local.zones

    cluster = google_container_cluster.jarvice.name
    version = local.node_version

    initial_node_count = 0
    autoscaling {
        min_node_count = 0
        max_node_count = 1
    }

    management {
        auto_repair = false
        auto_upgrade = false
    }

    node_config {
        machine_type = "n1-standard-8"
        disk_size_gb = 500
        disk_type = "pd-ssd"
        boot_disk_kms_key = lookup(var.cluster.meta, "kms_key",  null)
        image_type = "COS_CONTAINERD"
        gcfs_config {
            enabled = true
        }

        service_account = coalesce(lookup(var.cluster.meta, "service_account",  null), "default")
        oauth_scopes = local.oauth_scopes

        metadata = {
            disable-legacy-endpoints = "true"
            ssh-keys = "${local.username}:${module.common.ssh_public_key}"
        }

        labels = {
            "node-role.jarvice.io/jarvice-images-pull" = "true"
            "node-pool.jarvice.io/jarvice-images-pull" = "jxeimagespull"
        }
        taint = [
            {
                key = "node-role.jarvice.io/jarvice-images-pull"
                value = "true"
                effect = "NO_SCHEDULE"
            }
        ]

        tags = [google_container_cluster.jarvice.name, "jxeimagespull"]
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

    name = each.key
    location = local.region
    node_locations = lookup(each.value.meta, "zones", null) != null ? split(",", each.value.meta["zones"]) : local.zones

    cluster = google_container_cluster.jarvice.name
    version = google_container_cluster.jarvice.master_version

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
        boot_disk_kms_key = lookup(var.cluster.meta, "kms_key",  null)
        disk_size_gb = each.value["nodes_disk_size_gb"]
        disk_type = lookup(each.value.meta, "disk_type", "pd-standard")

        image_type = lower(lookup(each.value.meta, "enable_gcfs", "false")) == "true" ? "COS_CONTAINERD" : var.cluster.meta["kubernetes_version"] > 1.19 ? "UBUNTU_CONTAINERD" : "UBUNTU"
        dynamic "gcfs_config" {
            for_each = lookup(each.value.meta, "enable_gcfs", null) != null ? [lower(each.value.meta["enable_gcfs"]) == "true" ? true : false] : []
            content {
                enabled = gcfs_config.value
            }
        }

        #min_cpu_platform = "Intel Skylake"
        #disk_type = "pd-ssd"

        guest_accelerator {
            type = lookup(each.value.meta, "accelerator_type", "")
            count = lookup(each.value.meta, "accelerator_count", 0)
        }

        service_account = coalesce(lookup(var.cluster.meta, "service_account",  null), "default")
        oauth_scopes = local.oauth_scopes

        metadata = {
            disable-legacy-endpoints = "true"
            ssh-keys = "${local.username}:${module.common.ssh_public_key}"
        }

        labels = merge(
            {
                "node-role.jarvice.io/jarvice-compute" = "true"
                "node-pool.jarvice.io/jarvice-compute" = each.key
                "node-pool.jarvice.io/disable-hyperthreading" = lower(lookup(each.value.meta, "disable_hyperthreading", "false")) == "true" ? "true" : "false"
            },
            lookup(each.value.meta, "enable_gcfs", null) != null ? {"node-pool.jarvice.io/enable-gcfs" = lower(each.value.meta["enable_gcfs"]) == "true" ? "true" : "false"} : {},
        )
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

resource "google_container_node_pool" "jarvice_kns" {
    for_each = var.cluster["kns_node_pools"]

    name = each.key
    location = local.region
    node_locations = lookup(each.value.meta, "zones", null) != null ? split(",", each.value.meta["zones"]) : local.zones

    cluster = google_container_cluster.jarvice.name
    version = google_container_cluster.jarvice.master_version

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
        boot_disk_kms_key = lookup(var.cluster.meta, "kms_key",  null)
        disk_size_gb = each.value["nodes_disk_size_gb"]
        disk_type = lookup(each.value.meta, "disk_type", "pd-standard")

        image_type = lower(lookup(each.value.meta, "enable_gcfs", "false")) == "true" ? "COS_CONTAINERD" : var.cluster.meta["kubernetes_version"] > 1.19 ? "UBUNTU_CONTAINERD" : "UBUNTU"
        dynamic "gcfs_config" {
            for_each = lookup(each.value.meta, "enable_gcfs", null) != null ? [lower(each.value.meta["enable_gcfs"]) == "true" ? true : false] : []
            content {
                enabled = gcfs_config.value
            }
        }

        #min_cpu_platform = "Intel Skylake"
        #disk_type = "pd-ssd"

        guest_accelerator {
            type = lookup(each.value.meta, "accelerator_type", "")
            count = lookup(each.value.meta, "accelerator_count", 0)
        }

        service_account = coalesce(lookup(var.cluster.meta, "service_account",  null), "default")
        oauth_scopes = local.oauth_scopes

        metadata = {
            disable-legacy-endpoints = "true"
            ssh-keys = "${local.username}:${module.common.ssh_public_key}"
        }

        labels = merge(
            {
                "node-role.jarvice.io/jarvice-vcluster" = "true"
                "node-pool.jarvice.io/disable-hyperthreading" = lower(lookup(each.value.meta, "disable_hyperthreading", "false")) == "true" ? "true" : "false"
            },
            lookup(each.value.meta, "enable_gcfs", null) != null ? {"node-pool.jarvice.io/enable-gcfs" = lower(each.value.meta["enable_gcfs"]) == "true" ? "true" : "false"} : {},
        )
        taint = [
            {
                key = "node-role.jarvice.io/jarvice-vcluster"
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
