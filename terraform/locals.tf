# locals.tf - root module local variable definitions

locals {
    k8s = {
        for key in keys(var.k8s):
            key => var.k8s[key] if var.k8s[key].enabled == true
    }

    gke = {
        for key in keys(var.gke):
            key => var.gke[key] if var.gke[key].enabled == true
    }

    gkev2 = {
        for key in keys(var.gkev2):
            key => var.gkev2[key] if var.gkev2[key].enabled == true
    }

    eks = {
        for key in keys(var.eks):
            key => var.eks[key] if var.eks[key].enabled == true
    }

    eksv2 = {
        for key in keys(var.eksv2):
            key => var.eksv2[key] if var.eksv2[key].enabled == true
    }

    aks = {
        for key in keys(var.aks):
            key => var.aks[key] if var.aks[key].enabled == true
    }

    all = merge(var.k8s, var.gke, var.eks, var.aks)
    all_enabled = merge(local.k8s, local.gke, local.eks, local.aks)
}

