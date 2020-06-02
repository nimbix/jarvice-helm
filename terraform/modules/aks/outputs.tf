provider "local" {
    version = "~> 1.4"
}

resource "local_file" "kube_config" {
    filename = pathexpand("~/.kube/config.jarvice.tf.aks")
    file_permission = "0600" 
    directory_permission = "0775"
    content = azurerm_kubernetes_cluster.jarvice.kube_config_raw
}

output "AKS" {
    value = <<EOF
=======================================================================

Execute the following to begin using kubectl/helm with the new cluster:

export KUBECONFIG=${local_file.kube_config.filename}

Open the portal URL to initialize JARVICE:

https://${azurerm_public_ip.jarvice.fqdn}/

==============================================================================
EOF
}

