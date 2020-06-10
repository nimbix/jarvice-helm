provider "local" {
    version = "~> 1.4"
}

resource "local_file" "kube_config" {
    filename = pathexpand(local.kube_config)
    file_permission = "0600" 
    directory_permission = "0775"
    content = azurerm_kubernetes_cluster.jarvice.kube_config_raw
}

output "AKS" {
    value = <<EOF
=========================================================================

AKS cluster name: ${var.aks["cluster_name"]}
AKS cluster zone: ${var.aks["location"]}

Execute the following to begin using kubectl/helm with the new cluster:

export KUBECONFIG=${local.kube_config}

${local.cluster_output_message}:

https://${azurerm_public_ip.jarvice.fqdn}/

===============================================================================
EOF
}

