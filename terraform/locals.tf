# locals.tf - root module local variable definitions

locals {
    aks = {
        for key in keys(var.aks):
            key => var.aks[key] if var.aks[key].enabled == true
    }

    eks = {
        for key in keys(var.eks):
            key => var.eks[key] if var.eks[key].enabled == true
    }
}

