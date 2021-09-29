# outputs.tf - GKE module outputs

resource "local_file" "kube_config" {
    filename = pathexpand(local.kube_config["config_path"])
    file_permission = "0600" 
    directory_permission = "0775"
    content  = <<EOF
apiVersion: v1
kind: Config
preferences:
  colors: true
current-context: ${google_container_cluster.jarvice.name}
contexts:
- context:
    cluster: ${google_container_cluster.jarvice.name}
    namespace: default
    user: ${google_container_cluster.jarvice.name}
  name: ${google_container_cluster.jarvice.name}
clusters:
- cluster:
    server: https://${local.kube_config["host"]}
    certificate-authority-data: ${local.kube_config["cluster_ca_certificate"]}
  name: ${google_container_cluster.jarvice.name}
users:
- name: ${google_container_cluster.jarvice.name}
  user:
    auth-provider:
      config:
        access-token: ${local.kube_config["token"]}
        cmd-args: config config-helper --format=json
        cmd-path: gcloud
        expiry-key: '{.credential.token_expiry}'
        token-key: '{.credential.access_token}'
      name: gcp
EOF
}

output "kube_config" {
    value = local.kube_config
}

locals {
    helm_jarvice_values = yamldecode(module.helm.metadata["jarvice"]["values"])
    ingress_host = lookup(local.helm_jarvice_values["jarvice"], "JARVICE_CLUSTER_TYPE", "upstream") == "downstream" ? local.helm_jarvice_values["jarvice_k8s_scheduler"]["ingressHost"] : local.helm_jarvice_values["jarvice_mc_portal"]["ingressHost"]
}

output "cluster_info" {
    value = <<EOF
===============================================================================

    GKE cluster name: ${var.cluster.meta["cluster_name"]}
GKE cluster location: ${var.cluster.location["region"]}

       JARVICE chart: ${module.helm.jarvice_chart["version"]}
   JARVICE namespace: ${module.helm.metadata["jarvice"]["namespace"]}

Execute the following to begin using kubectl/helm with the new cluster:

export KUBECONFIG=${local.kube_config["config_path"]}

${module.common.cluster_output_message}:

https://${local.ingress_host}/

===============================================================================
EOF

    depends_on = [module.helm]
}

