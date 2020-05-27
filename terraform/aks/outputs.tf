provider "local" {
  version = "~> 1.4"
}

resource "local_file" "kube_config" {
  filename = pathexpand("~/.kube/config.jarvice.tf.aks")
  file_permission = "0600" 
  directory_permission = "0775"
  content = azurerm_kubernetes_cluster.jarvice.kube_config_raw
}

output "kube_config" {
  value = <<EOF
================================================================

Execute the following to begin using kubectl/helm with the new cluster:

export KUBECONFIG=${local_file.kube_config.filename}

Execute the following to get the JARVICE portal URL:

echo "http://$(kubectl -n jarvice-system get services jarvice-mc-portal-lb -o jsonpath='{.status.loadBalancer.ingress[0].ip}'):8080"

==============================================================================
EOF
}

#output "azurerm_public_ip_jarvice_ip_address" {
#  value = azurerm_public_ip.jarvice.ip_address
#}

#output "azurerm_public_ip_jarvice_fqdn" {
#  value = azurerm_public_ip.jarvice.fqdn
#}

