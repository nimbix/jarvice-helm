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
    user: ${local.kube_config["username"]}
  name: ${google_container_cluster.jarvice.name}
clusters:
- cluster:
    server: https://${local.kube_config["host"]}
    certificate-authority-data: ${local.kube_config["cluster_ca_certificate"]}
  name: ${google_container_cluster.jarvice.name}
users:
- name: ${local.kube_config["username"]}
  user:
    username: ${local.kube_config["username"]}
    password: ${local.kube_config["password"]}
    client-certificate-data: ${local.kube_config["client_certificate"]}
    client-key-data: ${local.kube_config["client_key"]}
EOF
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
        command = "mkdir -p ${dirname(pathexpand(self.triggers.path))} && kubectl --kubeconfig ${local_file.kube_config.filename} -n kube-system get service traefik -o jsonpath='{.status.loadBalancer.ingress[0].ip}' >${pathexpand(self.triggers.path)}"
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

    GKE cluster name: ${var.cluster.meta["cluster_name"]}
GKE cluster location: ${var.cluster.location["region"]}

       JARVICE chart: ${local.jarvice_chart}
   JARVICE namespace: ${module.helm.metadata["jarvice"]["namespace"]}

Execute the following to begin using kubectl/helm with the new cluster:

export KUBECONFIG=${local.kube_config["config_path"]}

${module.common.cluster_output_message}:

https://${fileexists(null_resource.ingress_host_file.triggers.path) ? file(null_resource.ingress_host_file.triggers.path) : "<undefined>"}/

===============================================================================
EOF
}

