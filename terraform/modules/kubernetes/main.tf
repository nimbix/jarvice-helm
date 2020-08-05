# main.tf - kubernetes module

resource "kubernetes_storage_class" "jarvice-db" {
    metadata {
        name = "jarvice-db"
        #labels = {"storage-role.jarvice.io/jarvice-db" = "${var.aks["cluster_name"]}"}
    }
    storage_provisioner = "kubernetes.io/azure-disk"
    reclaim_policy = "Retain"
    parameters = {
        cachingmode = "ReadOnly"
        kind = "Managed"
        #storageaccounttype = "Premium_LRS"
        storageaccounttype = "StandardSSD_LRS"
    }
}

resource "kubernetes_storage_class" "jarvice-user" {
    metadata {
        name = "jarvice-user"
        #labels = {"storage-role.jarvice.io/jarvice-user" = "${var.aks["cluster_name"]}"}
    }
    storage_provisioner = "kubernetes.io/azure-disk"
    reclaim_policy = "Retain"
    parameters = {
        cachingmode = "ReadOnly"
        kind = "Managed"
        #storageaccounttype = "Premium_LRS"
        storageaccounttype = "StandardSSD_LRS"
    }
}

