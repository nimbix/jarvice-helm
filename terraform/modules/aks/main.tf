# main.tf - AKS module

terraform {
  required_providers {
    azurerm = "~> 2.20"

    local = "~> 1.4"
    random = "~> 2.3"
  }
}

resource "azurerm_resource_group" "jarvice" {
    name = var.cluster["cluster_name"]
    location = var.cluster["location"]

    tags = {
        cluster_name = var.cluster["cluster_name"]
    }
}

resource "azurerm_public_ip" "jarvice" {
    name = var.cluster["cluster_name"]
    resource_group_name = azurerm_resource_group.jarvice.name
    location = azurerm_resource_group.jarvice.location

    allocation_method = "Static"
    sku = "Standard"
    domain_name_label = contains(["jarvice", "tf-jarvice", "jarvice-downstream", "tf-jarvice-downstream"], var.cluster["cluster_name"]) ? format("%s-%s", var.cluster["cluster_name"], random_id.jarvice.hex) : var.cluster["cluster_name"]

    tags = {
        cluster_name = var.cluster["cluster_name"]
    }
}

data "azurerm_kubernetes_service_versions" "kubernetes_version" {
    location = azurerm_resource_group.jarvice.location
    version_prefix = var.cluster["kubernetes_version"]
    include_preview = false

    depends_on = [azurerm_resource_group.jarvice]
}

resource "random_id" "jarvice" {
    byte_length = 4
}

resource "azurerm_kubernetes_cluster" "jarvice" {
    name = var.cluster["cluster_name"]
    kubernetes_version = data.azurerm_kubernetes_service_versions.kubernetes_version.latest_version

    dns_prefix = var.cluster["cluster_name"]
    resource_group_name = azurerm_resource_group.jarvice.name
    location = azurerm_resource_group.jarvice.location

    linux_profile {
        admin_username = "jarvice"

        ssh_key {
            key_data = local.ssh_public_key
        }
    }

    default_node_pool {
        name = "jxedefault"
        availability_zones = var.cluster["availability_zones"]
        node_count = 2
        vm_size = "Standard_B2s"

        node_labels = {
            "node-role.jarvice.io/default" = "true"
        }
    }

    service_principal {
        client_id = var.cluster["service_principal_client_id"]
        client_secret = var.cluster["service_principal_client_secret"]
    }

    network_profile {
        network_plugin = "kubenet"
    }

    addon_profile {
        http_application_routing {
            enabled = false
        }
        kube_dashboard {
            enabled = false
        }
    }

    tags = {
        cluster_name = var.cluster["cluster_name"]
    }

    depends_on = [azurerm_public_ip.jarvice]
}

resource "azurerm_kubernetes_cluster_node_pool" "jarvice_system" {
    name = "jxesystem"
    availability_zones = azurerm_kubernetes_cluster.jarvice.default_node_pool[0].availability_zones
    kubernetes_cluster_id = azurerm_kubernetes_cluster.jarvice.id

    vm_size = local.system_nodes_type
    os_type = "Linux"
    enable_auto_scaling = true
    node_count = local.system_nodes_num
    min_count = local.system_nodes_num
    max_count = local.system_nodes_num * 2

    node_labels = {
        "node-role.jarvice.io/jarvice-system" = "true"
    }
    node_taints = ["node-role.jarvice.io/jarvice-system=true:NoSchedule"]

    tags = {
        cluster_name = var.cluster["cluster_name"]
    }

    lifecycle {
        ignore_changes = [node_count]
    }
}

resource "azurerm_kubernetes_cluster_node_pool" "jarvice_compute" {
    count = length(var.cluster["compute_node_pools"])

    name = "jxecompute${count.index}"
    availability_zones = azurerm_kubernetes_cluster.jarvice.default_node_pool[0].availability_zones
    kubernetes_cluster_id = azurerm_kubernetes_cluster.jarvice.id

    vm_size = var.cluster.compute_node_pools[count.index]["nodes_type"]
    os_type = "Linux"
    os_disk_size_gb = var.cluster.compute_node_pools[count.index]["nodes_disk_size_gb"]

    enable_auto_scaling = true
    node_count = var.cluster.compute_node_pools[count.index]["nodes_num"]
    min_count = var.cluster.compute_node_pools[count.index]["nodes_min"]
    max_count = var.cluster.compute_node_pools[count.index]["nodes_max"]

    node_labels = {
        "node-role.jarvice.io/jarvice-compute" = "true"
    }
    node_taints = ["node-role.jarvice.io/jarvice-compute=true:NoSchedule"]

    tags = {
        cluster_name = var.cluster["cluster_name"]
    }

    lifecycle {
        ignore_changes = [node_count]
    }
}

