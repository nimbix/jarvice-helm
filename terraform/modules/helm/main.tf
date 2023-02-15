# main.tf - helm module

terraform {
  required_providers {
    helm = "~> 2.4"
  }
}

resource "helm_release" "aws_load_balancer_controller" {
    count = contains(keys(var.charts), "aws-load-balancer-controller") ? 1 : 0

    name = "aws-load-balancer-controller"
    repository = "https://aws.github.io/eks-charts"
    chart = "aws-load-balancer-controller"
    version = "1.3.2"
    namespace = "kube-system"
    reuse_values = false
    reset_values = true
    max_history = 12
    render_subchart_notes = false
    timeout = 600

    values = [var.charts["aws-load-balancer-controller"]["values"]]
}

resource "helm_release" "cluster_autoscaler" {
    count = contains(keys(var.charts), "cluster-autoscaler") ? 1 : 0

    name = "cluster-autoscaler"
    repository = "https://kubernetes.github.io/autoscaler"
    chart = "cluster-autoscaler"
    version = "9.10.8"
    namespace = "kube-system"
    reuse_values = false
    reset_values = true
    max_history = 12
    render_subchart_notes = false
    timeout = 600

    values = [var.charts["cluster-autoscaler"]["values"]]
}

resource "helm_release" "metrics_server" {
    count = contains(keys(var.charts), "metrics-server") ? 1 : 0

    name = "metrics-server"
    repository = "https://kubernetes-sigs.github.io/metrics-server"
    chart = "metrics-server"
    version = "3.7.0"
    namespace = "kube-system"
    reuse_values = false
    reset_values = true
    max_history = 12
    render_subchart_notes = false
    timeout = 600

    values = [var.charts["metrics-server"]["values"]]
}

resource "helm_release" "external_dns" {
    count = contains(keys(var.charts), "external-dns") ? 1 : 0

    name = "external-dns"
    repository = "https://charts.bitnami.com/bitnami"
    chart = "external-dns"
    version = "6.5.6"
    namespace = "kube-system"
    reuse_values = false
    reset_values = true
    max_history = 12
    render_subchart_notes = false
    timeout = 600

    values = [var.charts["external-dns"]["values"]]

    depends_on = [helm_release.aws_load_balancer_controller]
}

resource "helm_release" "cert_manager" {
    count = contains(keys(var.charts), "cert-manager") ? 1 : 0

    name = "cert-manager"
    repository = "https://charts.jetstack.io"
    chart = "cert-manager"
    version = "v1.6.1"
    namespace = "cert-manager"
    create_namespace = true
    reuse_values = false
    reset_values = true
    max_history = 12
    render_subchart_notes = false
    timeout = 600

    values = [var.charts["cert-manager"]["values"]]

    depends_on = [helm_release.traefik, helm_release.external_dns]
}

resource "helm_release" "traefik" {
    count = contains(keys(var.charts), "traefik") ? 1 : 0

    name = "traefik"
    repository = "https://helm.traefik.io/traefik"
    chart = "traefik"
    version = "10.7.1"
    namespace = "kube-system"
    reuse_values = false
    reset_values = true
    max_history = 12
    render_subchart_notes = false
    timeout = 600

    values = [var.charts["traefik"]["values"]]

    depends_on = [helm_release.aws_load_balancer_controller, helm_release.external_dns]
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
    max_history = 12
    render_subchart_notes = false
    timeout = 600
    wait = false

    values = [
        fileexists(var.global["values_file"]) ? "# Values from file: ${var.global["values_file"]}\n\n${file(var.global["values_file"])}" : "",
        fileexists(var.jarvice["values_file"]) ? "# Values from file: ${var.jarvice["values_file"]}\n\n${file(var.jarvice["values_file"])}" : "",
        var.common_values_yaml,
        var.cluster_values_yaml,
        var.global["values_yaml"],
        var.jarvice["values_yaml"]
    ]

    depends_on = [helm_release.cluster_autoscaler, helm_release.metrics_server, helm_release.external_dns, helm_release.cert_manager, helm_release.traefik]
}


resource "kubernetes_config_map" "jarvice_bird_user_preset" {
    count = fileexists(local.jarvice_bird_user_preset) ? 1 : 0

    metadata {
        name = "jarvice-bird-user-preset"
        namespace = var.jarvice["namespace"]
    }

    data = {
        "user_dashboards_configuration_default.json" = "${file(local.jarvice_bird_user_preset)}"
    }

    depends_on = [helm_release.cluster_autoscaler, helm_release.metrics_server, helm_release.external_dns, helm_release.cert_manager, helm_release.traefik, helm_release.jarvice]

}
