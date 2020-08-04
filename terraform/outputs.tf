# outputs.tf - root module outputs

# TODO: terraform-v0.13
#output "AKS" {
#    value = length(local.aks) == 0 ? null : join("\n", [
#        for key in keys(local.aks):
#            format("\n\nAKS Cluster Configuration: %s\n%s\n", key, module.aks[key].cluster_info)
#    ])
#}

