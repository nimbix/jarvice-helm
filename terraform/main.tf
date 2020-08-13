# main.tf - root module

terraform {
    required_version = "~> 0.13.0"
    #backend "local" {}

    required_providers {
        google = "~> 3.32.0"
        google-beta = "~> 3.32.0"
        aws = "~> 2.68.0"
        azurerm = "~> 2.20"

        helm = "~> 1.2"
        kubernetes = "~> 1.12"

        null = "~> 2.1"
        local = "~> 1.4"
        template = "~> 2.1"
        random = "~> 2.3"
    }
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
%{ for key in keys(local.k8s) }
# K8s cluster configuration: ${key}
provider "kubernetes" {
    alias = "${key}"

    load_config_file = true
    config_path = module.${key}.kube_config["config_path"]
}

provider "helm" {
    alias = "${key}"

    kubernetes {
        load_config_file = true
        config_path = module.${key}.kube_config["config_path"]
    }
}

module "${key}" {
    source = "./modules/k8s"

    cluster = local.k8s["${key}"]
    global = var.global

    providers = {
        kubernetes = kubernetes.${key}
        helm = helm.${key}
    }
}

output "${key}" {
    value = format("\n\nK8s Cluster Configuration: %s\n%s\n", "${key}", module.${key}.cluster_info)
}
%{ endfor }
##############################################################################
%{ for key in keys(local.gke) }
# GKE cluster configuration: ${key}
provider "google" {
    alias = "${key}"
    zone = local.gke["${key}"].location
    region = join("-", slice(split("-", local.gke["${key}"].location), 0, 2))
    project = local.gke["${key}"].auth["project"]
    credentials = local.gke["${key}"].auth["credentials"]
}

provider "google-beta" {
    alias = "${key}"
    zone = local.gke["${key}"].location
    region = join("-", slice(split("-", local.gke["${key}"].location), 0, 2))
    project = local.gke["${key}"].auth["project"]
    credentials = local.gke["${key}"].auth["credentials"]
}

provider "kubernetes" {
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
    access_key  = local.eks["${key}"].auth["access_key"]
    secret_key  = local.eks["${key}"].auth["secret_key"]
}

provider "kubernetes" {
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

