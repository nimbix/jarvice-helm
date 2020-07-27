# outputs.tf - EKS module outputs

resource "local_file" "kube_config" {
    filename = pathexpand(local.kube_config["path"])
    file_permission = "0600" 
    directory_permission = "0775"
    content = module.eks.kubeconfig
}

output "kube_config" {
    value = local.kube_config
}

resource "null_resource" "ingress_host_file" {
    triggers = {
        path = local.jarvice_config["ingress_host_path"]
        jarvice_revision = module.helm.metadata["jarvice"]["revision"]
        jarvice_version = module.helm.metadata["jarvice"]["version"]
        jarvice_values = module.helm.metadata["jarvice"]["values"]
    }

    provisioner "local-exec" {
        command = "kubectl --kubeconfig ${local_file.kube_config.filename} -n ${var.eks.helm.jarvice["namespace"]} get ingress jarvice-mc-portal -o jsonpath='{.spec.rules[0].host}' >${pathexpand(local.jarvice_config["ingress_host_path"])}"
    }

    provisioner "local-exec" {
        when = destroy
        command = fileexists(self.triggers.path) ? "rm -f ${self.triggers.path}" : null
    }
}

output "cluster_info" {
    value = <<EOF
===============================================================================

  EKS cluster name: ${var.eks["cluster_name"]}
EKS cluster region: ${var.eks["region"]}

Execute the following to begin using kubectl/helm with the new cluster:

export KUBECONFIG=${local.kube_config["path"]}

${local.cluster_output_message}:

https://${file(lookup(null_resource.ingress_host_file.triggers, "path", null))}/

===============================================================================
EOF
}

