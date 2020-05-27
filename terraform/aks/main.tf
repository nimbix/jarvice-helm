terraform {
  #backend "azurerm" {}
  backend "local" {}
}


provider "azurerm" {
  version = "~> 2.8"
  features {}
}

resource "azurerm_resource_group" "jarvice" {
  name = "${var.aks["cluster_name"]}-resource-group"
  location = var.aks["location"]
  tags = {
    cluster_name = var.aks["cluster_name"]
  }
}

resource "azurerm_public_ip" "jarvice" {
  name = "${var.aks["cluster_name"]}-public-ip"
  resource_group_name = azurerm_resource_group.jarvice.name
  location = azurerm_resource_group.jarvice.location
  allocation_method = "Static"
  ip_version = "IPv4"
  sku = "standard"
  tags = {
    cluster_name = var.aks["cluster_name"]
  }
}

resource "azurerm_kubernetes_cluster" "jarvice" {
  name = "${var.aks["cluster_name"]}-kubernetes-cluster"
  kubernetes_version = var.aks["kubernetes_version"]
  dns_prefix = var.aks["cluster_name"]
  resource_group_name = azurerm_resource_group.jarvice.name
  location = azurerm_resource_group.jarvice.location

  linux_profile {
      admin_username = "jarvice"

      ssh_key {
          key_data = file(var.aks["ssh_public_key"])
      }
  }

  default_node_pool {
    name = "jxemaster"
    availability_zones = var.aks["availability_zones"]
    node_count = 2
    vm_size = "Standard_B2s"
    #os_type = "Linux"
    #os_disk_size_gb = 30

    node_labels = {"node-role.kubernetes.io/master" = "true"}
  }

  service_principal {
    client_id = var.aks["service_principal_client_id"]
    client_secret = var.aks["service_principal_client_secret"]
  }

  network_profile {
    network_plugin = "kubenet"
    load_balancer_sku = "Standard"
    load_balancer_profile {
      outbound_ip_address_ids = [ "${azurerm_public_ip.jarvice.id}" ]
    }
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
    cluster_name = var.aks["cluster_name"]
  }
}

resource "azurerm_kubernetes_cluster_node_pool" "jarvice_system" {
  name = "jxesystem"
  availability_zones = azurerm_kubernetes_cluster.jarvice.default_node_pool[0].availability_zones
  kubernetes_cluster_id = azurerm_kubernetes_cluster.jarvice.id

  vm_size = var.aks.system_node_pool["node_vm_size"]
  node_count = var.aks.system_node_pool["node_count"]

  node_labels = {"node-role.kubernetes.io/jarvice-system" = "true"}
  node_taints = ["node-role.kubernetes.io/jarvice-system=true:NoSchedule"]

  tags = {
    cluster_name = var.aks["cluster_name"]
  }
}

resource "azurerm_kubernetes_cluster_node_pool" "jarvice_compute" {
  count = length(var.aks["compute_node_pools"])

  name = "jxecompute${count.index}"
  availability_zones = azurerm_kubernetes_cluster.jarvice.default_node_pool[0].availability_zones
  kubernetes_cluster_id = azurerm_kubernetes_cluster.jarvice.id

  vm_size = var.aks.compute_node_pools[count.index]["node_vm_size"]
  os_disk_size_gb = var.aks.compute_node_pools[count.index]["node_os_disk_size_gb"]

  enable_auto_scaling = true
  node_count = var.aks.compute_node_pools[count.index]["node_count"]
  min_count = var.aks.compute_node_pools[count.index]["node_min_count"]
  max_count = var.aks.compute_node_pools[count.index]["node_max_count"]

  node_labels = {"node-role.kubernetes.io/jarvice-compute" = "true"}
  node_taints = ["node-role.kubernetes.io/jarvice-compute=true:NoSchedule"]

  tags = {
    cluster_name = var.aks["cluster_name"]
  }
}


