# locals.tf - common module local variable definitions

locals {
    jarvice_values_file = replace(replace("${var.cluster.helm.jarvice["values_file"]}", "<region>", "${contains(keys(var.cluster), "location") ? var.cluster.location["region"] : ""}"), "<cluster_name>", "${var.cluster.meta["cluster_name"]}")

    jarvice_helm_override_yaml = fileexists(local.jarvice_values_file) ? "${file("${local.jarvice_values_file}")}" : ""

    jarvice_helm_values = merge(lookup(yamldecode("XXXdummy: value\n\n${fileexists(var.global.helm.jarvice["values_file"]) ? file(var.global.helm.jarvice["values_file"]) : ""}"), "jarvice", {}), lookup(yamldecode("XXXdummy: value\n\n${local.jarvice_helm_override_yaml}"), "jarvice", {}), lookup(yamldecode("XXXdummy: value\n\n${var.global.helm.jarvice["values_yaml"]}"), "jarvice", {}), lookup(yamldecode("XXXdummy: value\n\n${var.cluster.helm.jarvice["values_yaml"]}"), "jarvice", {}))

    jarvice_cluster_type = local.jarvice_helm_values["JARVICE_CLUSTER_TYPE"] == "downstream" ? "downstream" : "upstream"
}

locals {
    system_nodes_type = var.cluster.system_node_pool["nodes_type"] != null ? var.cluster.system_node_pool["nodes_type"] : local.jarvice_cluster_type == "downstream" ? var.system_nodes_type_downstream : var.system_nodes_type_upstream
    system_nodes_num = var.cluster.system_node_pool["nodes_num"] != null ? var.cluster.system_node_pool["nodes_num"] : local.jarvice_cluster_type == "downstream" ? 2 : 3
}

locals {
    ssh_public_key = contains(keys(var.cluster.meta), "ssh_public_key") == false ? null : var.cluster.meta["ssh_public_key"] != null ? file(var.cluster.meta["ssh_public_key"]) : file(var.global.meta["ssh_public_key"])
}

locals {
    cluster_values_yaml = <<EOF
# common cluster override values
jarvice:
  tolerations: '[{"key": "node-role.jarvice.io/jarvice-system", "effect": "NoSchedule", "operator": "Exists"}]'
  nodeSelector: '{"node-role.jarvice.io/jarvice-system": "true"}'

  JARVICE_PVC_VAULT_NAME: ${local.jarvice_helm_values["JARVICE_PVC_VAULT_NAME"] == null ? "persistent" : local.jarvice_helm_values["JARVICE_PVC_VAULT_NAME"]}
  JARVICE_PVC_VAULT_STORAGECLASS: ${local.jarvice_helm_values["JARVICE_PVC_VAULT_STORAGECLASS"] == null ? "jarvice-user" : local.jarvice_helm_values["JARVICE_PVC_VAULT_STORAGECLASS"]}
  JARVICE_PVC_VAULT_STORAGECLASS_PROVISIONER: ${var.storage_class_provisioner}
  JARVICE_PVC_VAULT_ACCESSMODES: ${local.jarvice_helm_values["JARVICE_PVC_VAULT_ACCESSMODES"] == null ? "ReadWriteOnce" : local.jarvice_helm_values["JARVICE_PVC_VAULT_ACCESSMODES"]}
  JARVICE_PVC_VAULT_SIZE: ${local.jarvice_helm_values["JARVICE_PVC_VAULT_SIZE"] == null ? 10 : local.jarvice_helm_values["JARVICE_PVC_VAULT_SIZE"]}

  daemonsets:
    lxcfs:
      enabled: true
      tolerations: '[{"key": "node-role.jarvice.io/jarvice-compute", "effect": "NoSchedule", "operator": "Exists"}]'
      nodeSelector: '{"node-role.jarvice.io/jarvice-compute": "true"}'

jarvice_db:
  persistence:
    enabled: true
    storageClassProvisioner: ${var.storage_class_provisioner}

jarvice_dal:
  env:
    JARVICE_MACHINES_ADD: '[{"mc_name":"n0", "mc_description":"2 core, 16GB RAM (CPU only)", "mc_cores":"2", "mc_slots":"2", "mc_gpus":"0", "mc_ram":"16", "mc_swap":"8", "mc_scratch":"64", "mc_devices":"", "mc_properties":"node-role.jarvice.io/jarvice-compute=true", "mc_slave_properties":"node-role.jarvice.io/jarvice-compute=true", "mc_slave_gpus":"0", "mc_slave_ram":"16", "mc_scale_min":"1", "mc_scale_max":"1", "mc_scale_select":"", "mc_lesser":"1", "mc_price":"0.00", "mc_priority":"0", "mc_privs":"", "mc_arch":"x86_64"}, {"mc_name":"n1", "mc_description":"4 core, 32GB RAM (CPU Only)", "mc_cores":"4", "mc_slots":"4", "mc_gpus":"0", "mc_ram":"32", "mc_swap":"16", "mc_scratch":"100", "mc_devices":"", "mc_properties":"node-role.jarvice.io/jarvice-compute=true", "mc_slave_properties":"node-role.jarvice.io/jarvice-compute=true", "mc_slave_gpus":"0", "mc_slave_ram":"32", "mc_scale_min":"1", "mc_scale_max":"1", "mc_scale_select":"", "mc_lesser":"1", "mc_price":"0.00", "mc_priority":"0", "mc_privs":"", "mc_arch":"x86_64"}, {"mc_name":"n3", "mc_description":"16 core, 128GB RAM (CPU Only)", "mc_cores":"16", "mc_slots":"16", "mc_gpus":"0", "mc_ram":"128", "mc_swap":"64", "mc_scratch":"500", "mc_devices":"", "mc_properties":"node-role.jarvice.io/jarvice-compute=true", "mc_slave_properties":"node-role.jarvice.io/jarvice-compute=true", "mc_slave_gpus":"0", "mc_slave_ram":"128", "mc_scale_min":"1", "mc_scale_max":"256", "mc_scale_select":"", "mc_lesser":"1", "mc_price":"0.00", "mc_priority":"0", "mc_privs":"", "mc_arch":"x86_64"}]'
EOF
}

locals {
    cluster_output_message = local.jarvice_cluster_type == "downstream" ? "Add the downstream cluster URL to an upstream JARVICE cluster" : "Open the portal URL to initialize JARVICE"
}

