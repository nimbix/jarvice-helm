# outputs.tf - helm module outputs

output "metadata" {
    value = {
        "cluster_autoscaler" = var.cluster_autoscaler_values == null ? null : length(helm_release.cluster_autoscaler) > 0 ? helm_release.cluster_autoscaler[0].metadata[0] : null,
        "external_dns" = var.external_dns_values == null ? null : length(helm_release.external_dns) > 0 ? helm_release.external_dns[0].metadata[0] : null,
        "traefik" = var.traefik_values == null ? null : length(helm_release.traefik) > 0 ? helm_release.traefik[0].metadata[0] : null,
        "jarvice" = helm_release.jarvice.metadata[0]
    }
}

