# providers.tf - root module providers

# TODO: Uncomment and enable when count/for_each for providers is implemented:
# https://github.com/hashicorp/terraform/issues/9448
# https://github.com/hashicorp/terraform/issues/24476

#provider "google" {
#    for_each = local.gke
#    alias = each.key
#
#    region = local.gke[each.key].location["region"]
#    project = local.gke[each.key].auth["project"]
#    credentials = local.gke[each.key].auth["credentials"]
#}

#provider "google-beta" {
#    for_each = local.gke
#    alias = each.key
#
#    region = local.gke[each.key].location["region"]
#    project = local.gke[each.key].auth["project"]
#    credentials = local.gke[each.key].auth["credentials"]
#}

#provider "aws" {
#    for_each  = local.eks
#    alias = each.key
#
#    region  = local.eks[each.key].region
#    access_key  = local.eks[each.key].auth["access_key"]
#    secret_key  = local.eks[each.key].auth["secret_key"]
#}

#provider "azurerm" {
#    for_each = local.aks
#    alias = each.key
#
#    features {}
#}

#provider "kubernetes" {
#    for_each = local.all_enabled
#    alias = "${key}"
#
#    load_config_file = module[each.key].kube_config["host"] == null ? true : false
#
#    config_path = module[each.key].kube_config["config_path"]
#    host = module[each.key].kube_config["host"]
#    cluster_ca_certificate = base64decode(module[each.key].kube_config["cluster_ca_certificate"])
#    client_certificate = base64decode(module[each.key].kube_config["client_certificate"])
#    client_key = base64decode(module[each.key].kube_config["client_key"])
#    token = module[each.key].kube_config["token"]
#    username = module[each.key].kube_config["username"]
#    password = module[each.key].kube_config["password"]
#}

#provider "helm" {
#    for_each = local.all_enabled
#    alias = "${key}"
#
#    kubernetes {
#        load_config_file = module[each.key].kube_config["host"] == null ? true : false
#
#        config_path = module[each.key].kube_config["config_path"]
#        host = module[each.key].kube_config["host"]
#        cluster_ca_certificate = base64decode(module[each.key].kube_config["cluster_ca_certificate"])
#        client_certificate = base64decode(module[each.key].kube_config["client_certificate"])
#        client_key = base64decode(module[each.key].kube_config["client_key"])
#        token = module[each.key].kube_config["token"]
#        username = module[each.key].kube_config["username"]
#        password = module[each.key].kube_config["password"]
#    }
#}

