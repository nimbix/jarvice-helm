# main.tf - root module

terraform {
    required_version = "~> 0.12.24"
    #backend "local" {}
}

# TODO: terraform-v0.13
#module "aks" {
#    for_each = local.aks
#
#    source = "./modules/aks"
#
#    aks = each.value
#    global = var.global
#
#    providers = {
#        aks = azurerm[each.key]
#        helm = helm.aks
#    }
#}

# Dynamically create clusters definition file until for_each is enabled and
# working for modules and providers in terraform v0.13
resource "local_file" "clusters" {
    filename = "${path.module}/clusters.tf"
    file_permission = "0664"
    directory_permission = "0775"

    content = <<EOF
# clusters.tf - cluster definitions (dynamically created using cluster configs)

##############################################################################
%{ for key in keys(local.eks) }
# EKS cluster configuration: ${key}
provider "aws" {
    alias = "${key}"
    region  = local.eks["${key}"].region
}

provider "kubernetes" {
    alias = "${key}"

    load_config_file = false
    host = module.${key}.kube_config_host
    cluster_ca_certificate = base64decode(module.${key}.kube_config_cluster_ca_certificate)
#    client_certificate = base64decode(module.${key}.kube_config_client_certificate)
#    client_key = base64decode(module.${key}.kube_config_client_key)
    token = module.${key}.kube_config_token
}

provider "helm" {
    alias = "${key}"

    kubernetes {
        load_config_file = false
        host = module.${key}.kube_config_host
        cluster_ca_certificate = base64decode(module.${key}.kube_config_cluster_ca_certificate)
#        client_certificate = base64decode(module.${key}.kube_config_client_certificate)
#        client_key = base64decode(module.${key}.kube_config_client_key)
        token = module.${key}.kube_config_token
    }
}

module "${key}" {
    source = "./modules/eks"

    eks = local.eks["${key}"]
    global = var.global

    providers = {
        aws = aws.${key}
        kubernetes = kubernetes.${key}
        helm = helm.${key}
    }
}

output "${key}" {
    value = format("\n\nEKS Cluster Configuration: %s\n%s\n", "${key}", module.${key}.cluster_info)
}
%{ endfor }
##############################################################################
%{ for key in keys(local.aks) }
# AKS cluster configuration: ${key}
provider "azurerm" {
    alias = "${key}"
    features {}
}

provider "helm" {
    alias = "${key}"

    kubernetes {
        load_config_file = false
        host = module.${key}.kube_config_host
        cluster_ca_certificate = base64decode(module.${key}.kube_config_cluster_ca_certificate)
        client_certificate = base64decode(module.${key}.kube_config_client_certificate)
        client_key = base64decode(module.${key}.kube_config_client_key)
        #token = module.${key}.kube_config_token
    }
}

module "${key}" {
    source = "./modules/aks"

    aks = local.aks["${key}"]
    global = var.global

    providers = {
        azurerm = azurerm.${key}
        helm = helm.${key}
    }
}

output "${key}" {
    value = format("\n\nAKS Cluster Configuration: %s\n%s\n", "${key}", module.${key}.cluster_info)
}
%{ endfor }
EOF
}

