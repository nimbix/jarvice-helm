# outputs.tf - helm module outputs

output "metadata" {
    value = {
        "cluster-autoscaler" = contains(keys(var.charts), "cluster-autoscaler") && length(helm_release.cluster_autoscaler) > 0 ? helm_release.cluster_autoscaler[0].metadata[0] : null,
        "external-dns" = contains(keys(var.charts), "external-dns") && length(helm_release.external_dns) > 0 ? helm_release.external_dns[0].metadata[0] : null,
        "traefik" = contains(keys(var.charts), "traefik") && length(helm_release.traefik) > 0 ? helm_release.traefik[0].metadata[0] : null,
        "jarvice" = helm_release.jarvice.metadata[0]
    }
}

