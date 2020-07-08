# outputs.tf - EKS module outputs

resource "local_file" "kube_config" {
    filename = pathexpand(local.kube_config["path"])
    file_permission = "0600" 
    directory_permission = "0775"
    content = module.eks.kubeconfig
}

output "kube_config_path" {
    value = local.kube_config["path"]
}

output "kube_config_host" {
    value = local.kube_config["host"]
}

output "kube_config_cluster_ca_certificate" {
    value = local.kube_config["cluster_ca_certificate"]
}

output "kube_config_client_certificate" {
    value = local.kube_config["client_certificate"]
}

output "kube_config_client_key" {
    value = local.kube_config["client_key"]
}

output "kube_config_token" {
    value = local.kube_config["token"]
}

output "cluster_info" {
    value = <<EOF
===============================================================================

  EKS cluster name: ${var.eks["cluster_name"]}
EKS cluster region: ${var.eks["region"]}

Execute the following to begin using kubectl/helm with the new cluster:

export KUBECONFIG=${local.kube_config["path"]}

${local.cluster_output_message}:

After setting KUBECONFIG, execute the following to get the host name:
kubectl -n kube-system get services traefik -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'

===============================================================================
EOF
}

