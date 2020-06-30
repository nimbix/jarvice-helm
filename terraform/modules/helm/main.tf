# main.tf - helm module

terraform {
  required_providers {
    helm = "~> 1.2"
  }
}

resource "helm_release" "traefik" {
    name = "traefik"
    repository = "https://kubernetes-charts.storage.googleapis.com"
    chart = "traefik"
    #version = "1.85.0"
    namespace = "kube-system"
    reuse_values = false
    reset_values = true
    render_subchart_notes = false
    timeout = 600

    values = [var.traefik_values]
}

resource "helm_release" "jarvice" {
    name = "jarvice"
    chart = "./"
    #version = "3.0.0"
    namespace = var.jarvice["namespace"]
    create_namespace = true
    reuse_values = false
    reset_values = true
    render_subchart_notes = true
    timeout = 600

    values = [
        "# values.yaml\n\n${file("values.yaml")}",
        fileexists(var.jarvice["override_yaml_file"]) ? "# ${var.jarvice["override_yaml_file"]}\n\n${file("${var.jarvice["override_yaml_file"]}")}" : "",
        "${var.global["override_yaml_values"]}",
        "${var.jarvice["override_yaml_values"]}",
        "${var.cluster_override_yaml_values}"
    ]

    #depends_on = var.traefik_deploy ? [helm_release.traefik] : []
}

