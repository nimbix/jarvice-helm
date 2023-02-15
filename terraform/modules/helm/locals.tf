# locals.tf - helm module local variable definitions

locals {
    jarvice_chart_repository = contains(keys(var.jarvice), "repository") ? var.jarvice["repository"] : contains(keys(var.global), "repository") ? var.global["repository"] : "https://nimbix.github.io/jarvice-helm/"

    jarvice_chart_version = contains(keys(var.jarvice), "version") ? var.jarvice["version"] : var.global["version"]

    jarvice_chart_is_dir = local.jarvice_chart_version == null ? false : fileexists("${pathexpand(local.jarvice_chart_version)}/Chart.yaml")

    jarvice_bird_user_preset =  contains(keys(var.jarvice), "bird_user_preset") ? var.jarvice["bird_user_preset"] : "jarvice-bird-user-preset"

}

