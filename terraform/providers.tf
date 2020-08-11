# providers.tf - root module providers

#provider "local" {
#    version = "~> 1.4"
#}

# TODO: terraform-v0.13
#provider "google" {
#  version     = "~> 3.27.0"
  #credentials = file("account.json")
  #project     = var.gcp_project
  #region      = var.gcp_region
#}

# TODO: terraform-v0.13
#provider "aws" {
#  version = "~> 2.68.0"
#  #region  = var.aws_region
#  #profile = var.aws_profile
#}

# TODO: terraform-v0.13
#provider "azurerm" {
#    for_each = local.aks
#
#    alias = each.key
#    version = "~> 2.13"
#    features {}
#}

#provider "azurerm" {
#    version = "~> 2.13"
#    features {}
#}

# TODO: terraform-v0.13
#provider "helm" {
#    for_each = local.aks
#
#    alias = each.key
#    version = "~> 1.2"
#
#    kubernetes {
#        load_config_file = true
#        config_path = pathexpand("~/.kube/config-tf.aks")
#    }
#}

