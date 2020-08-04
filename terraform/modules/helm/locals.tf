# locals.tf - helm module local variable definitions

locals {
    jarvice_chart_is_dir = var.jarvice["version"] == null ? false : fileexists("${pathexpand(var.jarvice["version"])}/Chart.yaml")
}

