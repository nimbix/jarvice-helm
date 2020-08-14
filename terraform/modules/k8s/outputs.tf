# outputs.tf - K8s module outputs

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
        command = "mkdir -p ${dirname(pathexpand(self.triggers.path))} && kubectl --kubeconfig ${local.kube_config["config_path"]} -n ${var.cluster.helm.jarvice["namespace"]} get ingress ${local.jarvice_ingress_name} -o jsonpath='{.spec.rules[0].host}' 2>/dev/null >${pathexpand(self.triggers.path)} || /bin/true"
    }

    provisioner "local-exec" {
        when = destroy
        command = fileexists(self.triggers.path) ? "rm -f ${self.triggers.path}" : null
    }
}

resource "null_resource" "loadbalancer_host_file" {
    triggers = {
        path = local.jarvice_config["loadbalancer_host_path"]
        jarvice_revision = module.helm.metadata["jarvice"]["revision"]
        jarvice_version = module.helm.metadata["jarvice"]["version"]
        jarvice_values = module.helm.metadata["jarvice"]["values"]
    }

    provisioner "local-exec" {
        command = "mkdir -p ${dirname(pathexpand(self.triggers.path))} && kubectl --kubeconfig ${local.kube_config["config_path"]} -n ${var.cluster.helm.jarvice["namespace"]} get service ${local.jarvice_ingress_name}-lb -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null  >${pathexpand(self.triggers.path)} || /bin/true"
    }

    provisioner "local-exec" {
        when = destroy
        command = fileexists(self.triggers.path) ? "rm -f ${self.triggers.path}" : null
    }
}

locals {
    ingress_host = fileexists(null_resource.ingress_host_file.triggers.path) ? file(null_resource.ingress_host_file.triggers.path) : ""
    loadbalancer_host = fileexists(null_resource.loadbalancer_host_file.triggers.path) ? file(null_resource.loadbalancer_host_file.triggers.path) : ""

    jarvice_url = local.ingress_host != "" ? format("https://%s/", local.ingress_host) : local.loadbalancer_host != "" ? format("http://%s:8080/", local.loadbalancer_host) : "<undefined>"
}

locals {
    jarvice_chart = module.helm.metadata["jarvice"]["version"] != "0.1" ? module.helm.metadata["jarvice"]["version"] : contains(keys(var.cluster.helm.jarvice), "version") ? var.cluster.helm.jarvice.version : var.global.helm.jarvice.version
}

output "cluster_info" {
    value = <<EOF
===============================================================================

 K8s cluster name: ${var.cluster["cluster_name"]}

    JARVICE chart: ${local.jarvice_chart}
JARVICE namespace: ${module.helm.metadata["jarvice"]["namespace"]}

Execute the following to begin using kubectl/helm with the new cluster:

export KUBECONFIG=${local.kube_config["config_path"]}

${local.cluster_output_message}:

${local.jarvice_url}

===============================================================================
EOF
}

