# outputs.tf - AKS module outputs

resource "local_file" "kube_config" {
    filename = pathexpand(local.kube_config["path"])
    file_permission = "0600" 
    directory_permission = "0775"
    content = azurerm_kubernetes_cluster.jarvice.kube_config_raw
}

output "kube_config_path" {
    value = local.kube_config["path"]
}

output "kube_config_client_certificate" {
    value = local.kube_config["client_certificate"]
}

output "kube_config_client_key" {
    value = local.kube_config["client_key"]
}

output "kube_config_cluster_ca_certificate" {
    value = local.kube_config["cluster_ca_certificate"]
}

output "kube_config_host" {
    value = local.kube_config["host"]
}

output "AKS" {
    value = <<EOF
===============================================================================

    AKS cluster name: ${var.aks["cluster_name"]}
AKS cluster location: ${var.aks["location"]}

Execute the following to begin using kubectl/helm with the new cluster:

export KUBECONFIG=${local.kube_config["path"]}

${local.cluster_output_message}:

https://${azurerm_public_ip.jarvice.fqdn}/

===============================================================================
EOF
}

