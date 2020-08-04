# main.tf - root module

terraform {
    required_version = "~> 0.12.29"
    #backend "local" {}
}

# TODO: terraform-v0.13
#module "aks" {
#    for_each = local.aks
#
#    source = "./modules/aks"
#
#    cluster = each.value
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
%{ for key in keys(local.gke) }
# GKE cluster configuration: ${key}
provider "google" {
    alias = "${key}"
    zone = local.gke["${key}"].location
    region = join("-", slice(split("-", local.gke["${key}"].location), 0, 2))
    project = local.gke["${key}"].project
    credentials = local.gke["${key}"].credentials
}

provider "google-beta" {
    alias = "${key}"
    zone = local.gke["${key}"].location
    region = join("-", slice(split("-", local.gke["${key}"].location), 0, 2))
    project = local.gke["${key}"].project
    credentials = local.gke["${key}"].credentials
}

provider "kubernetes" {
    version = "~> 1.11"
    alias = "${key}"

    load_config_file = false
    host = module.${key}.kube_config["host"]
    cluster_ca_certificate = base64decode(module.${key}.kube_config["cluster_ca_certificate"])
    client_certificate = base64decode(module.${key}.kube_config["client_certificate"])
    client_key = base64decode(module.${key}.kube_config["client_key"])
    token = module.${key}.kube_config["token"]
    username = module.${key}.kube_config["username"]
    password = module.${key}.kube_config["password"]
}

provider "helm" {
    alias = "${key}"

    kubernetes {
        load_config_file = false
        host = module.${key}.kube_config["host"]
        cluster_ca_certificate = base64decode(module.${key}.kube_config["cluster_ca_certificate"])
        client_certificate = base64decode(module.${key}.kube_config["client_certificate"])
        client_key = base64decode(module.${key}.kube_config["client_key"])
        token = module.${key}.kube_config["token"]
        username = module.${key}.kube_config["username"]
        password = module.${key}.kube_config["password"]
    }
}

module "${key}" {
    source = "./modules/gke"

    cluster = local.gke["${key}"]
    global = var.global

    providers = {
        google = google.${key}
        google-beta = google-beta.${key}
        kubernetes = kubernetes.${key}
        helm = helm.${key}
    }
}

output "${key}" {
    value = format("\n\nGKE Cluster Configuration: %s\n%s\n", "${key}", module.${key}.cluster_info)
}
%{ endfor }
##############################################################################
%{ for key in keys(local.eks) }
# EKS cluster configuration: ${key}
provider "aws" {
    alias = "${key}"
    region  = local.eks["${key}"].region
}

provider "kubernetes" {
    version = "~> 1.11"
    alias = "${key}"

    load_config_file = false
    host = module.${key}.kube_config["host"]
    cluster_ca_certificate = base64decode(module.${key}.kube_config["cluster_ca_certificate"])
#    client_certificate = base64decode(module.${key}.kube_config["client_certificate"])
#    client_key = base64decode(module.${key}.kube_config["client_key"])
    token = module.${key}.kube_config["token"]
}

provider "helm" {
    alias = "${key}"

    kubernetes {
        load_config_file = false
        host = module.${key}.kube_config["host"]
        cluster_ca_certificate = base64decode(module.${key}.kube_config["cluster_ca_certificate"])
#        client_certificate = base64decode(module.${key}.kube_config["client_certificate"])
#        client_key = base64decode(module.${key}.kube_config["client_key"])
        token = module.${key}.kube_config["token"]
    }
}

module "${key}" {
    source = "./modules/eks"

    cluster = local.eks["${key}"]
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
        host = module.${key}.kube_config["host"]
        cluster_ca_certificate = base64decode(module.${key}.kube_config["cluster_ca_certificate"])
        client_certificate = base64decode(module.${key}.kube_config["client_certificate"])
        client_key = base64decode(module.${key}.kube_config["client_key"])
        #token = module.${key}.kube_config["token"]
    }
}

module "${key}" {
    source = "./modules/aks"

    cluster = local.aks["${key}"]
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

