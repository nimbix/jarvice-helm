# main.tf - helm module

terraform {
  required_providers {
    helm = "~> 1.3.2"
  }
}

resource "helm_release" "cluster_autoscaler" {
    count = contains(keys(var.charts), "cluster-autoscaler") ? 1 : 0

    name = "cluster-autoscaler"
    repository = "https://charts.helm.sh/stable"
    chart = "cluster-autoscaler"
    namespace = "kube-system"
    reuse_values = false
    reset_values = true
    render_subchart_notes = false
    timeout = 600

    values = [var.charts["cluster-autoscaler"]["values"]]
}

resource "helm_release" "metrics_server" {
    count = contains(keys(var.charts), "metrics-server") ? 1 : 0

    name = "metrics-server"
    repository = "https://charts.helm.sh/stable"
    chart = "metrics-server"
    namespace = "kube-system"
    reuse_values = false
    reset_values = true
    render_subchart_notes = false
    timeout = 600

    values = [var.charts["metrics-server"]["values"]]
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

resource "helm_release" "cert_manager" {
    count = contains(keys(var.charts), "cert-manager") ? 1 : 0

    name = "cert-manager"
    repository = "https://charts.jetstack.io"
    chart = "cert-manager"
    namespace = "cert-manager"
    create_namespace = true
    reuse_values = false
    reset_values = true
    render_subchart_notes = false
    timeout = 600

    values = [var.charts["cert-manager"]["values"]]
}

resource "helm_release" "traefik" {
    count = contains(keys(var.charts), "traefik") ? 1 : 0

    name = "traefik"
    repository = "https://charts.helm.sh/stable"
    chart = "traefik"
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
    devel = true
    version = local.jarvice_chart_is_dir ? null : local.jarvice_chart_version

    namespace = var.jarvice["namespace"]
    create_namespace = true
    reuse_values = false
    reset_values = true
    render_subchart_notes = false
    timeout = 600
    wait = false

    values = [
        fileexists(var.global["values_file"]) ? "# Values from file: ${var.global["values_file"]}\n\n${file(var.global["values_file"])}" : "",
        fileexists(var.jarvice["values_file"]) ? "# Values from file: ${var.jarvice["values_file"]}\n\n${file(var.jarvice["values_file"])}" : "",
        var.global["values_yaml"],
        var.jarvice["values_yaml"],
        var.common_values_yaml,
        var.cluster_values_yaml,
        local.jarvice_ingress_values
    ]

    depends_on = [helm_release.cert_manager, helm_release.traefik]
}

