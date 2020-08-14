# outputs.tf - EKS module outputs

resource "local_file" "kube_config" {
    filename = pathexpand(local.kube_config["config_path"])
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
        command = "mkdir -p ${dirname(pathexpand(self.triggers.path))} && kubectl --kubeconfig ${local_file.kube_config.filename} -n ${var.cluster.helm.jarvice["namespace"]} get ingress ${local.jarvice_ingress_name} -o jsonpath='{.spec.rules[0].host}' >${pathexpand(self.triggers.path)}"
    }

    provisioner "local-exec" {
        when = destroy
        command = fileexists(self.triggers.path) ? "rm -f ${self.triggers.path}" : null
    }
}

locals {
    jarvice_chart = module.helm.metadata["jarvice"]["version"] != "0.1" ? module.helm.metadata["jarvice"]["version"] : contains(keys(var.cluster.helm.jarvice), "version") ? var.cluster.helm.jarvice.version : var.global.helm.jarvice.version
}

output "cluster_info" {
    value = <<EOF
===============================================================================

    EKS cluster name: ${var.cluster["cluster_name"]}
EKS cluster location: ${var.cluster["region"]}

       JARVICE chart: ${local.jarvice_chart}
   JARVICE namespace: ${module.helm.metadata["jarvice"]["namespace"]}

Execute the following to begin using kubectl/helm with the new cluster:

export KUBECONFIG=${local.kube_config["config_path"]}

${local.cluster_output_message}:

https://${fileexists(null_resource.ingress_host_file.triggers.path) ? file(null_resource.ingress_host_file.triggers.path) : "<unknown>"}/

===============================================================================
EOF
}

