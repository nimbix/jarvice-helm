# main.tf - root module

terraform {
    required_version = "~> 1.0"
    #backend "local" {}

    # Make sure all providers are downloaded with the initial init
    required_providers {
        google = "~> 4.66.0"
        aws = "~> 3.64"
        azurerm = "~> 2.84"

        helm = "~> 2.4"
        kubernetes = "~> 2.6"

        null = "~> 3.1"
        local = "~> 2.1"
        random = "~> 3.1"
    }
}

# TODO: Uncomment and enable when count/for_each for providers is implemented:
# https://github.com/hashicorp/terraform/issues/9448
# https://github.com/hashicorp/terraform/issues/24476

#module "k8s" {
#    for_each = local.k8s
#
#    source = "./modules/k8s"
#
#    cluster = each.value
#    global = var.global
#
#    providers = {
#        kubernetes = kubernetes[each.key]
#        helm = helm[each.key]
#    }
#}

#module "gke" {
#    for_each = local.gke
#
#    source = "./modules/gke"
#
#    cluster = each.value
#    global = var.global
#
#    providers = {
#        google = google[each.key]
#        kubernetes = kubernetes[each.key]
#        helm = helm[each.key]
#    }
#}

#module "eks" {
#    for_each = local.eks
#
#    source = "./modules/eks"
#
#    cluster = each.value
#    global = var.global
#
#    providers = {
#        aws = aws[each.key]
#        kubernetes = kubernetes[each.key]
#        helm = helm[each.key]
#    }
#}

#module "aks" {
#    for_each = local.aks
#
#    source = "./modules/aks"
#
#    cluster = each.value
#    global = var.global
#
#    providers = {
#        azurerm = azurerm[each.key]
#        kubernetes = kubernetes[each.key]
#        helm = helm[each.key]
#    }
#}

# Dynamically create clusters definition file until for_each is enabled and
# working for providers (after terraform v1.0)
resource "local_file" "clusters" {
    filename = "${path.module}/clusters.tf"
    file_permission = "0664"
    directory_permission = "0775"

    content = <<EOF
# clusters.tf - cluster definitions (dynamically created using cluster configs)

################
# K8s clusters #
################
%{ for key in keys(local.k8s) }
# K8s cluster configuration: ${key}
provider "kubernetes" {
    alias = "${key}"

    config_path = module.${key}.kube_config["config_path"]
}

provider "helm" {
    alias = "${key}"

    kubernetes {
        config_path = module.${key}.kube_config["config_path"]
    }
}
%{ endfor }

%{ for key in keys(local.k8s) }
# K8s cluster configuration: ${key}
module "${key}" {
    source = "./modules/k8s"

    cluster = local.k8s["${key}"]
    global = var.global

    providers = {
        kubernetes = kubernetes.${key}
        helm = helm.${key}
    }
    depends_on = [local_file.clusters]
}

output "${key}" {
    value = format("\n\nK8s Cluster Configuration: %s\n%s\n", "${key}", module.${key}.cluster_info)
}
%{ endfor }
################
# GKE clusters #
################
%{ for key in keys(local.gke) }
# GKE cluster configuration: ${key}
provider "google" {
    alias = "${key}"

    region = local.gke["${key}"].location["region"]
    project = local.gke["${key}"].auth["project"]
    credentials = local.gke["${key}"].auth["credentials"]
}

provider "kubernetes" {
    alias = "${key}"

    host = module.${key}.kube_config["host"]
    cluster_ca_certificate = base64decode(module.${key}.kube_config["cluster_ca_certificate"])
    client_certificate = base64decode(module.${key}.kube_config["client_certificate"])
    client_key = base64decode(module.${key}.kube_config["client_key"])
    token = module.${key}.kube_config["token"]
}

provider "helm" {
    alias = "${key}"

    kubernetes {
        host = module.${key}.kube_config["host"]
        cluster_ca_certificate = base64decode(module.${key}.kube_config["cluster_ca_certificate"])
        client_certificate = base64decode(module.${key}.kube_config["client_certificate"])
        client_key = base64decode(module.${key}.kube_config["client_key"])
        token = module.${key}.kube_config["token"]
    }
}
%{ endfor }

%{ for key in keys(local.gke) }
# GKE cluster configuration: ${key}
module "${key}" {
    source = "./modules/gke"

    cluster = local.gke["${key}"]
    global = var.global

    providers = {
        google = google.${key}
        kubernetes = kubernetes.${key}
        helm = helm.${key}
    }
    depends_on = [local_file.clusters]
}

output "${key}" {
    value = format("\n\nGKE Cluster Configuration: %s\n%s\n", "${key}", module.${key}.cluster_info)
}
output "${key}_slurm" {
    value = module.${key}.slurm_info
}
%{ endfor }
###################
# GKE clusters v2 #
###################
%{ for key in keys(local.gkev2) }
# GKE cluster configuration: ${key}
provider "google" {
    alias = "${key}"

    region = local.gkev2["${key}"].location["region"]
    project = local.gkev2["${key}"].auth["project"]
    credentials = local.gkev2["${key}"].auth["credentials"]
}

provider "kubernetes" {
    alias = "${key}"

    host = module.${key}.kube_config["host"]
    cluster_ca_certificate = base64decode(module.${key}.kube_config["cluster_ca_certificate"])
    client_certificate = base64decode(module.${key}.kube_config["client_certificate"])
    client_key = base64decode(module.${key}.kube_config["client_key"])
    token = module.${key}.kube_config["token"]
}

provider "helm" {
    alias = "${key}"

    kubernetes {
        host = module.${key}.kube_config["host"]
        cluster_ca_certificate = base64decode(module.${key}.kube_config["cluster_ca_certificate"])
        client_certificate = base64decode(module.${key}.kube_config["client_certificate"])
        client_key = base64decode(module.${key}.kube_config["client_key"])
        token = module.${key}.kube_config["token"]
    }
}
%{ endfor }

%{ for key in keys(local.gkev2) }
# GKE v2 cluster configuration: ${key}
module "${key}" {
    source = "./modules/gkev2"

    cluster = local.gkev2["${key}"]
    global = var.global

    providers = {
        google = google.${key}
        kubernetes = kubernetes.${key}
        helm = helm.${key}
    }
    depends_on = [local_file.clusters]
}

output "${key}" {
    value = format("\n\nGKE v2 Cluster Configuration: %s\n%s\n", "${key}", module.${key}.cluster_info)
}
output "${key}_slurm" {
    value = module.${key}.slurm_info
}
%{ endfor }
################
# EKS clusters #
################
%{ for key in keys(local.eks) }
# EKS cluster configuration: ${key}
provider "aws" {
    alias = "${key}"

    region  = local.eks["${key}"].location["region"]
    access_key  = local.eks["${key}"].auth["access_key"]
    secret_key  = local.eks["${key}"].auth["secret_key"]
    ignore_tags {
      key_prefixes = lookup(local.eks["${key}"].meta, "allow_cluster_join", "") == "true" ? ["kubernetes.io/"] : []
    }
}

provider "kubernetes" {
    alias = "${key}"

    host = module.${key}.kube_config["host"]
    cluster_ca_certificate = base64decode(module.${key}.kube_config["cluster_ca_certificate"])
    client_certificate = base64decode(module.${key}.kube_config["client_certificate"])
    client_key = base64decode(module.${key}.kube_config["client_key"])
    token = module.${key}.kube_config["token"]
}

provider "helm" {
    alias = "${key}"

    kubernetes {
        host = module.${key}.kube_config["host"]
        cluster_ca_certificate = base64decode(module.${key}.kube_config["cluster_ca_certificate"])
        client_certificate = base64decode(module.${key}.kube_config["client_certificate"])
        client_key = base64decode(module.${key}.kube_config["client_key"])
        token = module.${key}.kube_config["token"]
    }
}
%{ endfor }

%{ for key in keys(local.eks) }
# EKS cluster configuration: ${key}
module "${key}" {
    source = "./modules/eks"

    cluster = local.eks["${key}"]
    global = var.global

    providers = {
        aws = aws.${key}
        kubernetes = kubernetes.${key}
        helm = helm.${key}
    }
    depends_on = [local_file.clusters]
}

output "${key}" {
    value = format("\n\nEKS Cluster Configuration: %s\n%s\n", "${key}", module.${key}.cluster_info)
}
output "${key}_slurm" {
    value = module.${key}.slurm_info
}
%{ endfor }
################
# AKS clusters #
################
%{ for key in keys(local.aks) }
# AKS cluster configuration: ${key}
provider "azurerm" {
    alias = "${key}"

    features {}
}

provider "helm" {
    alias = "${key}"

    kubernetes {
        host = module.${key}.kube_config["host"]
        cluster_ca_certificate = base64decode(module.${key}.kube_config["cluster_ca_certificate"])
        client_certificate = base64decode(module.${key}.kube_config["client_certificate"])
        client_key = base64decode(module.${key}.kube_config["client_key"])
        token = module.${key}.kube_config["token"]
    }
}
%{ endfor }

%{ for key in keys(local.aks) }
# AKS cluster configuration: ${key}
module "${key}" {
    source = "./modules/aks"

    cluster = local.aks["${key}"]
    global = var.global

    providers = {
        azurerm = azurerm.${key}
        helm = helm.${key}
    }
    depends_on = [local_file.clusters]
}

output "${key}" {
    value = format("\n\nAKS Cluster Configuration: %s\n%s\n", "${key}", module.${key}.cluster_info)
}
output "${key}_slurm" {
    value = module.${key}.slurm_info
}
%{ endfor }
EOF
}
