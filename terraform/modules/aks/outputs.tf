# outputs.tf - AKS module outputs

resource "local_file" "kube_config" {
    filename = pathexpand(local.kube_config["config_path"])
    file_permission = "0600" 
    directory_permission = "0775"
    content = azurerm_kubernetes_cluster.jarvice.kube_config_raw
}

output "kube_config" {
    value = local.kube_config
}

locals {
    helm_jarvice_values = yamldecode(module.helm.metadata["jarvice"]["values"])
    ingress_host = lookup(local.helm_jarvice_values["jarvice"], "JARVICE_CLUSTER_TYPE", "upstream") == "downstream" ? local.helm_jarvice_values["jarvice_k8s_scheduler"]["ingressHost"] : local.helm_jarvice_values["jarvice_mc_portal"]["ingressHost"]
    slurm_downstream_message =<<EOF
===============================================================================

    AKS cluster name: ${var.cluster.meta["cluster_name"]}
AKS cluster location: ${var.cluster.location["region"]}

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

    AKS cluster name: ${var.cluster.meta["cluster_name"]}
AKS cluster location: ${var.cluster.location["region"]}

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
      slurm_hosts = [ for key in module.common.jarvice_slurm_schedulers : lookup(local.helm_jarvice_values["jarvice"], "JARVICE_CLUSTER_TYPE", "upstream") == "downstream" ? "http://${key.ingressHost}" : "http://jarvice-slurm-scheduler-${key.name}.${module.helm.metadata["jarvice"]["namespace"]}.svc.cluster.local:8080" ]
}

output "slurm_info" {
    value = length(local.slurm_hosts) == 0 ? null:<<EOF
%{ for key in local.slurm_hosts }
Add the slurm cluster URL to an upstream JARVICE cluster: ${key}
%{ endfor }
EOF

    depends_on = [module.helm]
}
