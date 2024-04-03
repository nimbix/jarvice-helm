# outputs.tf - helm module outputs

output "metadata" {
    value = {
        "cluster-autoscaler" = contains(keys(var.charts), "cluster-autoscaler") && length(helm_release.cluster_autoscaler) > 0 ? helm_release.cluster_autoscaler[0].metadata[0] : null,
        "external-dns" = contains(keys(var.charts), "external-dns") && length(helm_release.external_dns) > 0 ? helm_release.external_dns[0].metadata[0] : null,
        "traefik" = contains(keys(var.charts), "traefik") && length(helm_release.traefik) > 0 ? helm_release.traefik[0].metadata[0] : null,
        "jarvice" = contains(keys(var.charts), "jarvice") && length(helm_release.jarvice) > 0 ? helm_release.jarvice[0] : null
    }
}

output "jarvice_chart" {
    value = {
        "repository" = local.jarvice_chart_is_dir ? null : local.jarvice_chart_repository,
        "version" = local.jarvice_chart_version != null ? local.jarvice_chart_version : contains(keys(var.charts), "jarvice") && length(helm_release.jarvice) > 0 ? helm_release.jarvice[0].metadata[0]["version"] : ""
    }
}

