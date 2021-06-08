# main.tf - AKS module

terraform {
    required_providers {
        azurerm = "~> 2.61.0"

        helm = "~> 2.1.2"
        kubernetes = "~> 2.1.0"

        local = "~> 2.1.0"
        random = "~> 3.1.0"
    }
}

resource "azurerm_resource_group" "jarvice" {
    name = var.cluster.meta["cluster_name"]
    location = var.cluster.location["region"]

    tags = {
        cluster_name = var.cluster.meta["cluster_name"]
    }
}

resource "azurerm_public_ip" "jarvice" {
    name = var.cluster.meta["cluster_name"]
    resource_group_name = azurerm_resource_group.jarvice.name
    location = azurerm_resource_group.jarvice.location

    allocation_method = "Static"
    sku = "Standard"
    #domain_name_label = contains(["jarvice", "tf-jarvice", "jarvice-downstream", "tf-jarvice-downstream"], var.cluster.meta["cluster_name"]) ? format("%s-%s", var.cluster.meta["cluster_name"], random_id.jarvice.hex) : var.cluster.meta["cluster_name"]

    tags = {
        cluster_name = var.cluster.meta["cluster_name"]
    }
}

data "azurerm_kubernetes_service_versions" "kubernetes_version" {
    location = azurerm_resource_group.jarvice.location
    version_prefix = var.cluster.meta["kubernetes_version"]
    include_preview = false

    depends_on = [azurerm_resource_group.jarvice]
}

resource "random_id" "jarvice" {
    byte_length = 4
}

resource "azurerm_kubernetes_cluster" "jarvice" {
    name = var.cluster.meta["cluster_name"]
    kubernetes_version = data.azurerm_kubernetes_service_versions.kubernetes_version.latest_version

    dns_prefix = var.cluster.meta["cluster_name"]
    resource_group_name = azurerm_resource_group.jarvice.name
    location = azurerm_resource_group.jarvice.location

    linux_profile {
        admin_username = "jarvice"

        ssh_key {
            key_data = module.common.ssh_public_key
        }
    }

    default_node_pool {
        name = "default"
        availability_zones = var.cluster.location["zones"]
        node_count = 2
        vm_size = "Standard_B2s"

        node_labels = {
            "node-role.jarvice.io/default" = "true"
        }
    }

    #service_principal {
    #    client_id = var.cluster.auth["service_principal_client_id"]
    #    client_secret = var.cluster.auth["service_principal_client_secret"]
    #}

    identity {
        type = "SystemAssigned"
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
        cluster_name = var.cluster.meta["cluster_name"]
    }

    depends_on = [azurerm_public_ip.jarvice]

    lifecycle {
        ignore_changes = [kubernetes_version]
    }
}

resource "azurerm_kubernetes_cluster_node_pool" "jarvice_system" {
    name = "jxesystem"
    availability_zones = azurerm_kubernetes_cluster.jarvice.default_node_pool[0].availability_zones
    kubernetes_cluster_id = azurerm_kubernetes_cluster.jarvice.id

    vm_size = module.common.system_nodes_type
    os_type = "Linux"
    enable_auto_scaling = true
    node_count = module.common.system_nodes_num
    min_count = module.common.system_nodes_num
    max_count = module.common.system_nodes_num * 2

    node_labels = {
        "node-role.jarvice.io/jarvice-system" = "true"
        "node-pool.jarvice.io/jarvice-system" = "jxesystem"
    }
    node_taints = ["node-role.jarvice.io/jarvice-system=true:NoSchedule"]

    tags = {
        cluster_name = var.cluster.meta["cluster_name"]
    }

    lifecycle {
        ignore_changes = [node_count]
    }
}

resource "azurerm_kubernetes_cluster_node_pool" "jarvice_compute" {
    for_each = var.cluster["compute_node_pools"]

    name = each.key
    availability_zones = azurerm_kubernetes_cluster.jarvice.default_node_pool[0].availability_zones
    kubernetes_cluster_id = azurerm_kubernetes_cluster.jarvice.id

    vm_size = each.value["nodes_type"]
    os_type = "Linux"
    os_disk_size_gb = each.value["nodes_disk_size_gb"]

    enable_auto_scaling = true
    node_count = each.value["nodes_num"]
    min_count = each.value["nodes_min"]
    max_count = each.value["nodes_max"]

    node_labels = {
        "node-role.jarvice.io/jarvice-compute" = "true"
        "node-pool.jarvice.io/jarvice-compute" = each.key
    }
    node_taints = ["node-role.jarvice.io/jarvice-compute=true:NoSchedule"]

    tags = {
        cluster_name = var.cluster.meta["cluster_name"]
    }

    lifecycle {
        ignore_changes = [node_count]
    }
}

