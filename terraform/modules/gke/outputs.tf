# outputs.tf - GKE module outputs
# use kubectl auth plugin after auth-provider is removed in k8s 1.26
locals {
  version_a = split(".", var.cluster.meta["kubernetes_version"])
  version_b = split(".", "1.26.0")
  version-test = [
    for i, j in reverse(range(length(local.version_a)))
    : signum(local.version_b[i] - tonumber(local.version_a[i])) * pow(10, j)
  ]
  # The version-compare value is -1, 0, or 1 if version_a is greater than, equal to or less than version_b respectively
  version-compare = signum(sum(local.version-test))
  a-less-than-b   = 1 == local.version-compare
  auth_kubeconfig = <<EOF
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
    server: ${local.kube_config["host"]}
    certificate-authority-data: ${local.kube_config["cluster_ca_certificate"]}
  name: ${google_container_cluster.jarvice.name}
users:
- name: ${google_container_cluster.jarvice.name}
  user:
    auth-provider:
      config:
        cmd-args: config config-helper --format=json
        cmd-path: gcloud
        expiry-key: '{.credential.token_expiry}'
        token-key: '{.credential.access_token}'
      name: gcp
EOF
  exec_kubeconfig = <<EOF
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
    server: ${local.kube_config["host"]}
    certificate-authority-data: ${local.kube_config["cluster_ca_certificate"]}
  name: ${google_container_cluster.jarvice.name}
users:
- name: ${google_container_cluster.jarvice.name}
  user:
    exec:
      apiVersion: client.authentication.k8s.io/v1beta1
      command: gke-gcloud-auth-plugin
      provideClusterInfo: true

EOF
}

resource "local_file" "kube_config" {
    filename = pathexpand(local.kube_config["config_path"])
    file_permission = "0600"
    directory_permission = "0775"
    content  = local.a-less-than-b == true ? local.auth_kubeconfig : local.exec_kubeconfig
}

output "kube_config" {
    value = local.kube_config
}

locals {
    helm_jarvice_values = yamldecode(module.helm.metadata["jarvice"]["values"])
    ingress_host = lookup(local.helm_jarvice_values["jarvice"], "JARVICE_CLUSTER_TYPE", "upstream") == "downstream" ? local.helm_jarvice_values["jarvice_k8s_scheduler"]["ingressHost"] : local.helm_jarvice_values["jarvice_mc_portal"]["ingressHost"]
    slurm_downstream_message =<<EOF
===============================================================================

    GKE cluster name: ${var.cluster.meta["cluster_name"]}
GKE cluster location: ${var.cluster.location["region"]}

       JARVICE chart: ${module.helm.jarvice_chart["version"]}
   JARVICE namespace: ${module.helm.metadata["jarvice"]["namespace"]}

Execute the following to begin using kubectl/helm with the new cluster:

export KUBECONFIG=${local.kube_config["config_path"]}

===============================================================================
EOF
}

output "cluster_info" {
    value = (lookup(local.helm_jarvice_values["jarvice"], "JARVICE_CLUSTER_TYPE", "upstream") == "downstream") && !module.common.jarvice_k8s_helm_values.enabled ?local.slurm_downstream_message:<<EOF
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

locals {
      slurm_hosts = [ for key in module.common.jarvice_slurm_schedulers : lookup(local.helm_jarvice_values["jarvice"], "JARVICE_CLUSTER_TYPE", "upstream") == "downstream" ? "https://${key.ingressHost}" : "http://jarvice-slurm-scheduler-${key.name}.${module.helm.metadata["jarvice"]["namespace"]}.svc.cluster.local:8080" ]
}

output "slurm_info" {
    value = length(local.slurm_hosts) == 0 ? null:<<EOF
%{ for key in local.slurm_hosts }
Add the slurm cluster URL to an upstream JARVICE cluster: ${key}
%{ endfor }
EOF

    depends_on = [module.helm]
}
