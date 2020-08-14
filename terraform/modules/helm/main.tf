# main.tf - helm module

terraform {
  required_providers {
    helm = "~> 1.2"
  }
}

resource "helm_release" "cluster_autoscaler" {
    count = contains(keys(var.charts), "cluster-autoscaler") ? 1 : 0

    name = "cluster-autoscaler"
    repository = "https://kubernetes-charts.storage.googleapis.com"
    chart = "cluster-autoscaler"
    namespace = "kube-system"
    reuse_values = false
    reset_values = true
    render_subchart_notes = false
    timeout = 600

    values = [var.charts["cluster-autoscaler"]["values"]]
}

resource "helm_release" "external_dns" {
    count = contains(keys(var.charts), "external-dns") ? 1 : 0

    name = "external-dns"
    repository = "https://charts.bitnami.com/bitnami"
    chart = "external-dns"
    namespace = "kube-system"
    reuse_values = false
    reset_values = true
    render_subchart_notes = false
    timeout = 600

    values = [var.charts["external-dns"]["values"]]
}

resource "helm_release" "traefik" {
    count = contains(keys(var.charts), "traefik") ? 1 : 0

    name = "traefik"
    repository = "https://kubernetes-charts.storage.googleapis.com"
    chart = "traefik"
    #version = "1.85.0"
    namespace = "kube-system"
    reuse_values = false
    reset_values = true
    render_subchart_notes = false
    timeout = 600

    values = [var.charts["traefik"]["values"]]
}

resource "helm_release" "jarvice" {
    name = "jarvice"
    repository = local.jarvice_chart_is_dir ? null : local.jarvice_chart_repository
    chart = local.jarvice_chart_is_dir ? pathexpand(local.jarvice_chart_version) : "jarvice"
    version = local.jarvice_chart_is_dir ? null : local.jarvice_chart_version

    namespace = var.jarvice["namespace"]
    create_namespace = true
    reuse_values = false
    reset_values = true
    render_subchart_notes = false
    timeout = 600
    wait = false

    values = [
        fileexists("values.yaml") ? "# values.yaml\n\n${file("values.yaml")}" : "",
        fileexists(var.jarvice["override_yaml_file"]) ? "# ${var.jarvice["override_yaml_file"]}\n\n${file("${var.jarvice["override_yaml_file"]}")}" : "",
        "${var.global["override_yaml_values"]}",
        "${var.jarvice["override_yaml_values"]}",
        "${var.cluster_override_yaml_values}"
    ]

    depends_on = [helm_release.traefik]
}

