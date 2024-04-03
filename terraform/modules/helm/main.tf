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
    version = "1.4.7"
    namespace = "kube-system"
    reuse_values = false
    reset_values = true
    max_history = 12
    render_subchart_notes = false
    timeout = 600

    values = [var.charts["aws-load-balancer-controller"]["values"]]
}

resource "helm_release" "aws_ebs_csi_driver" {
    count = contains(keys(var.charts), "aws-ebs-csi-driver") ? 1 : 0

    name = "aws-ebs-csi-driver"
    repository = "https://kubernetes-sigs.github.io/aws-ebs-csi-driver"
    chart = "aws-ebs-csi-driver"
    version = "2.21.0"
    namespace = "kube-system"
    reuse_values = false
    reset_values = true
    max_history = 12
    render_subchart_notes = false
    timeout = 600

    values = [var.charts["aws-ebs-csi-driver"]["values"]]
}

resource "helm_release" "cluster_autoscaler" {
    count = contains(keys(var.charts), "cluster-autoscaler") ? 1 : 0

    name = "cluster-autoscaler"
    repository = "https://kubernetes.github.io/autoscaler"
    chart = "cluster-autoscaler"
    version = "9.18.1"
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

resource "helm_release" "namespace" {
    count =  fileexists(local.jarvice_user_cacert) || fileexists(local.jarvice_user_java_cacert) ? 1 : 0

    name = var.jarvice["namespace"]
    repository = "https://ameijer.github.io/k8s-as-helm"
    chart = "namespace"
    version = "1.1.0"
    reuse_values = false
    reset_values = true
    max_history = 12
    render_subchart_notes = false
    timeout = 600

    depends_on = [helm_release.aws_load_balancer_controller, helm_release.external_dns]
}

resource "kubernetes_config_map" "jarvice_user_cacert" {
    count = fileexists(local.jarvice_user_cacert) ? 1 : 0

    metadata {
        name = "jarvice-cacert"
        namespace = var.jarvice["namespace"]
    }

    data = {
        "ca-certificates.crt" = "${file(local.jarvice_user_cacert)}"
    }

    depends_on = [helm_release.cluster_autoscaler, helm_release.metrics_server, helm_release.external_dns, helm_release.cert_manager, helm_release.traefik, helm_release.namespace]

}

resource "kubernetes_config_map" "jarvice_java_cacert" {
    count = fileexists(local.jarvice_user_java_cacert) ? 1 : 0

    metadata {
        name = "jarvice-java-cacert"
        namespace = var.jarvice["namespace"]
    }

    binary_data = {
        "cacerts" = "${filebase64(local.jarvice_user_java_cacert)}"
    }

    depends_on = [helm_release.cluster_autoscaler, helm_release.metrics_server, helm_release.external_dns, helm_release.cert_manager, helm_release.traefik, helm_release.namespace]

}

resource "helm_release" "jarvice" {
    count = contains(lookup(var.cluster.meta), "jarvice") ? 1 : 0
    
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
        fileexists(local.jarvice_user_cacert) ? local.user_cacert_values_yaml : "",
        fileexists(local.jarvice_user_java_cacert) ? local.java_cacert_values_yaml : "",
        var.cluster_values_yaml,
        var.global["values_yaml"],
        var.jarvice["values_yaml"]
    ]

    depends_on = [helm_release.cluster_autoscaler, helm_release.metrics_server, helm_release.external_dns, helm_release.cert_manager, helm_release.traefik, kubernetes_config_map.jarvice_user_cacert, kubernetes_config_map.jarvice_java_cacert]
}
