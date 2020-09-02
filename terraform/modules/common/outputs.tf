# outputs.tf - common module outputs

output "jarvice_values_file" {
    value = local.jarvice_values_file
}

#output "jarvice_helm_values" {
#    value = local.jarvice_helm_values
#}

output "jarvice_cluster_type" {
    value = local.jarvice_cluster_type
}

output "system_nodes_type" {
    value = local.system_nodes_type
}

output "system_nodes_num" {
    value = local.system_nodes_num
}

output "ssh_public_key" {
    value = local.ssh_public_key
}

output "cluster_values_yaml" {
    value = local.cluster_values_yaml
}

output "cluster_output_message" {
    value = local.cluster_output_message
}

