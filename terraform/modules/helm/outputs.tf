# outputs.tf - helm module outputs

output "metadata" {
    value = {
        "traefik" = var.traefik_values != null ? helm_release.traefik[0].metadata[0] : null,
        "jarvice" = helm_release.jarvice.metadata[0]
    }
}

