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

resource "random_id" "dns_prefix" {
    byte_length = 6
}

resource "azurerm_kubernetes_cluster" "jarvice" {
    name = var.cluster["cluster_name"]
    kubernetes_version = var.cluster["kubernetes_version"]
    dns_prefix = contains(["jarvice", "tf-jarvice", "jarvice-downstream", "tf-jarvice-downstream"], var.cluster["cluster_name"]) ? "${var.cluster["cluster_name"]-random_id.dns_prefix.hex}" : var.cluster["cluster_name"]
    resource_group_name = azurerm_resource_group.jarvice.name
    location = azurerm_resource_group.jarvice.location

    linux_profile {
        admin_username = "jarvice"

        ssh_key {
            key_data = local.ssh_public_key
        }
    }

    default_node_pool {
        name = "jxemaster"
        availability_zones = var.cluster["availability_zones"]
        node_count = 2
        vm_size = "Standard_B2s"

        node_labels = {"node-role.kubernetes.io/master" = "true"}
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
}

resource "azurerm_public_ip" "jarvice" {
    name = var.cluster["cluster_name"]
    resource_group_name = azurerm_kubernetes_cluster.jarvice.node_resource_group
    location = azurerm_kubernetes_cluster.jarvice.location

    allocation_method = "Static"
    sku = "Standard"
    domain_name_label = var.cluster["cluster_name"]

    tags = {
        cluster_name = var.cluster["cluster_name"]
    }

    timeouts {
        delete = "15m"
    }
}

resource "azurerm_kubernetes_cluster_node_pool" "jarvice_system" {
    name = "jxesystem"
    availability_zones = azurerm_kubernetes_cluster.jarvice.default_node_pool[0].availability_zones
    kubernetes_cluster_id = azurerm_kubernetes_cluster.jarvice.id

    vm_size = var.cluster.system_node_pool["node_vm_size"] != null ? var.cluster.system_node_pool["node_vm_size"] : local.system_node_vm_size
    os_type = "Linux"
    node_count = var.cluster.system_node_pool["node_count"] != null ? var.cluster.system_node_pool["node_count"] : local.system_node_vm_count

    node_labels = {
        "node-role.jarvice.io/jarvice-system" = "true",
        "node-role.kubernetes.io/jarvice-system" = "true"
    }
    node_taints = ["node-role.kubernetes.io/jarvice-system=true:NoSchedule"]

    tags = {
        cluster_name = var.cluster["cluster_name"]
    }
}

resource "azurerm_kubernetes_cluster_node_pool" "jarvice_compute" {
    count = length(var.cluster["compute_node_pools"])

    name = "jxecompute${count.index}"
    availability_zones = azurerm_kubernetes_cluster.jarvice.default_node_pool[0].availability_zones
    kubernetes_cluster_id = azurerm_kubernetes_cluster.jarvice.id

    vm_size = var.cluster.compute_node_pools[count.index]["node_vm_size"]
    os_type = "Linux"
    os_disk_size_gb = var.cluster.compute_node_pools[count.index]["node_os_disk_size_gb"]

    enable_auto_scaling = true
    node_count = var.cluster.compute_node_pools[count.index]["node_count"]
    min_count = var.cluster.compute_node_pools[count.index]["node_min_count"]
    max_count = var.cluster.compute_node_pools[count.index]["node_max_count"]

    node_labels = {
        "node-role.jarvice.io/jarvice-compute" = "true",
        "node-role.kubernetes.io/jarvice-compute" = "true"
    }
    node_taints = ["node-role.kubernetes.io/jarvice-compute=true:NoSchedule"]

    tags = {
        cluster_name = var.cluster["cluster_name"]
    }
}

