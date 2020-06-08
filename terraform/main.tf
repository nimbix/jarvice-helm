terraform {
    backend "local" {}
}

module "aks" {
    source = "./modules/aks"

    # count feature will be available in terraform v0.13.0
    #count = length(var.aks)
    #aks = var.aks[count.index]

    global_override_yaml_values = var.global_override_yaml_values
    aks = var.aks[0]
}

