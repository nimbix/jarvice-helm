# outputs.tf - CAPG module outputs

output "cluster_id" {
    description = "CAPG cluster identifier"
    value = var.enabled ? local.workload_cluster_name : ""
}

output "cluster_endpoint" {
    description = "CAPG cluster API endpoint"
    value = var.enabled ? try(data.external.workload_cluster_info.result.endpoint, "") : ""
}

output "cluster_ca_certificate" {
    description = "CAPG cluster CA certificate"
    value = var.enabled ? try(data.external.workload_cluster_info.result.ca_certificate, "") : ""
    sensitive = true
}

output "cluster_token" {
    description = "CAPG cluster access token"
    value = var.enabled ? try(data.external.workload_cluster_info.result.token, "") : ""
    sensitive = true
}

output "kube_config" {
    description = "CAPG cluster kube config (compatible format)"
    value = var.enabled ? {
        host = try(data.external.workload_cluster_info.result.endpoint, "")
        cluster_ca_certificate = try(data.external.workload_cluster_info.result.ca_certificate, "")
        client_certificate = ""
        client_key = ""
        token = try(data.external.workload_cluster_info.result.token, "")
        username = ""
        password = ""
        insecure = false
        config_path = ""
        config_context = ""
        config_context_auth_info = ""
        config_context_cluster = ""
        exec = {}
    } : {
        host = ""
        cluster_ca_certificate = ""
        client_certificate = ""
        client_key = ""
        token = ""
        username = ""
        password = ""
        insecure = false
        config_path = ""
        config_context = ""
        config_context_auth_info = ""
        config_context_cluster = ""
        exec = {}
    }
    sensitive = true
}

output "kubeconfig" {
    description = "CAPG cluster kubeconfig content"
    value = var.enabled ? try(templatefile("${path.module}/templates/kubeconfig.yaml.tpl", {
        cluster_name = local.workload_cluster_name
        endpoint = data.external.workload_cluster_info.result.endpoint
        ca_certificate = data.external.workload_cluster_info.result.ca_certificate
        token = data.external.workload_cluster_info.result.token
    }), "") : ""
    sensitive = true
}

output "cluster_location" {
    description = "CAPG cluster location information"
    value = var.enabled ? {
        project = local.project
        region = local.region
        zones = local.zones
    } : {
        project = ""
        region = ""
        zones = []
    }
}

output "cluster_info" {
    description = "CAPG cluster information"
    value = var.enabled ? {
        cluster_name = local.workload_cluster_name
        management_cluster = local.management_cluster_name
        project = local.project
        region = local.region
        zones = local.zones
        kubernetes_version = var.meta["kubernetes_version"]
    } : {
        cluster_name = ""
        management_cluster = ""
        project = ""
        region = ""
        zones = []
        kubernetes_version = ""
    }
}

# Compatibility outputs for other modules
output "slurm_info" {
    description = "Slurm cluster information (empty for CAPG)"
    value = {}
}
