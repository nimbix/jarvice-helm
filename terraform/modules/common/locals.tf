# locals.tf - common module local variable definitions

locals {
    jarvice_values_file = replace(replace(var.cluster.helm.jarvice["values_file"], "<region>", contains(keys(var.cluster), "location") ? var.cluster.location["region"] : ""), "<cluster_name>", var.cluster.meta["cluster_name"])

    jarvice_helm_override_yaml = fileexists(local.jarvice_values_file) ? file(local.jarvice_values_file) : ""

    jarvice_helm_values_min_defaults = <<EOF
jarvice:
  JARVICE_CLUSTER_TYPE: "upstream"
  JARVICE_PVC_VAULT_NAME: persistent
  JARVICE_PVC_VAULT_STORAGECLASS: jarvice-user
  JARVICE_PVC_VAULT_ACCESSMODES:  # e.g. "ReadWriteMany,ReadOnlyMany"
  JARVICE_PVC_VAULT_SIZE:         # gigabytes
EOF
    jarvice_helm_values = merge(
        lookup(yamldecode(local.jarvice_helm_values_min_defaults), "jarvice", {}),
        lookup(yamldecode("XXXdummy: value\n\n${fileexists(var.global.helm.jarvice["values_file"]) ? file(var.global.helm.jarvice["values_file"]) : ""}"), "jarvice", {}),
        lookup(yamldecode("XXXdummy: value\n\n${local.jarvice_helm_override_yaml}"), "jarvice", {}),
        lookup(yamldecode("XXXdummy: value\n\n${var.global.helm.jarvice["values_yaml"]}"), "jarvice", {}),
        lookup(yamldecode("XXXdummy: value\n\n${var.cluster.helm.jarvice["values_yaml"]}"), "jarvice", {})
    )

    jarvice_cluster_type = local.jarvice_helm_values["JARVICE_CLUSTER_TYPE"] == "downstream" ? "downstream" : "upstream"
}

locals {
    system_nodes_type = var.cluster.system_node_pool["nodes_type"] != null ? var.cluster.system_node_pool["nodes_type"] : local.jarvice_cluster_type == "downstream" ? var.system_nodes_type_downstream : var.system_nodes_type_upstream
    system_nodes_num = var.cluster.system_node_pool["nodes_num"] != null ? var.cluster.system_node_pool["nodes_num"] : local.jarvice_cluster_type == "downstream" ? 3 : 4
}

locals {
    mc_arch = lookup(var.cluster.meta, "arch", "x86_64")
    mc_name = local.mc_arch == "arm64" ? "na" : "n"

    jarvice_machines_add = <<EOF
[{"mc_name":"${local.mc_name}0", "mc_description":"2 core, 16GB RAM (CPU only)", "mc_cores":"2", "mc_slots":"2", "mc_gpus":"0", "mc_ram":"16", "mc_swap":"8", "mc_scratch":"64", "mc_devices":"", "mc_properties":"node-role.jarvice.io/jarvice-compute=true", "mc_slave_properties":"node-role.jarvice.io/jarvice-compute=true", "mc_slave_gpus":"0", "mc_slave_ram":"16", "mc_scale_min":"1", "mc_scale_max":"1", "mc_scale_select":"", "mc_lesser":"1", "mc_price":"0.00", "mc_priority":"0", "mc_privs":"", "mc_arch":"${local.mc_arch}"}, {"mc_name":"${local.mc_name}1", "mc_description":"4 core, 32GB RAM (CPU Only)", "mc_cores":"4", "mc_slots":"4", "mc_gpus":"0", "mc_ram":"32", "mc_swap":"16", "mc_scratch":"100", "mc_devices":"", "mc_properties":"node-role.jarvice.io/jarvice-compute=true", "mc_slave_properties":"node-role.jarvice.io/jarvice-compute=true", "mc_slave_gpus":"0", "mc_slave_ram":"32", "mc_scale_min":"1", "mc_scale_max":"1", "mc_scale_select":"", "mc_lesser":"1", "mc_price":"0.00", "mc_priority":"0", "mc_privs":"", "mc_arch":"${local.mc_arch}"}, {"mc_name":"${local.mc_name}3", "mc_description":"16 core, 128GB RAM (CPU Only)", "mc_cores":"16", "mc_slots":"16", "mc_gpus":"0", "mc_ram":"128", "mc_swap":"64", "mc_scratch":"500", "mc_devices":"", "mc_properties":"node-role.jarvice.io/jarvice-compute=true", "mc_slave_properties":"node-role.jarvice.io/jarvice-compute=true", "mc_slave_gpus":"0", "mc_slave_ram":"128", "mc_scale_min":"1", "mc_scale_max":"256", "mc_scale_select":"", "mc_lesser":"1", "mc_price":"0.00", "mc_priority":"0", "mc_privs":"", "mc_arch":"${local.mc_arch}"}]
EOF
}

locals {
    ssh_public_key_file = lookup(var.cluster.meta, "ssh_public_key", null) != null ? lookup(var.cluster.meta, "ssh_public_key", null) : lookup(var.global.meta, "ssh_public_key", null)
    ssh_public_key = local.ssh_public_key_file == null ? "" : fileexists(local.ssh_public_key_file) ? file(local.ssh_public_key_file) : ""
}

locals {
    cluster_values_yaml = <<EOF
# common cluster override values
jarvice:
  tolerations: '[{"key": "node-role.jarvice.io/jarvice-system", "effect": "NoSchedule", "operator": "Exists"}]'
  nodeAffinity: '{"requiredDuringSchedulingIgnoredDuringExecution": {"nodeSelectorTerms": [{"matchExpressions": [{"key": "node-role.jarvice.io/jarvice-system", "operator": "Exists"}]}, {"matchExpressions": [{"key": "node-role.kubernetes.io/jarvice-system", "operator": "Exists"}]}] }}'

  JARVICE_PVC_VAULT_NAME: ${local.jarvice_helm_values["JARVICE_PVC_VAULT_NAME"] == null ? "persistent" : local.jarvice_helm_values["JARVICE_PVC_VAULT_NAME"]}
  JARVICE_PVC_VAULT_STORAGECLASS: ${local.jarvice_helm_values["JARVICE_PVC_VAULT_STORAGECLASS"] == null ? "jarvice-user" : local.jarvice_helm_values["JARVICE_PVC_VAULT_STORAGECLASS"]}
  JARVICE_PVC_VAULT_STORAGECLASS_PROVISIONER: ${var.storage_class_provisioner}
  JARVICE_PVC_VAULT_ACCESSMODES: ${local.jarvice_helm_values["JARVICE_PVC_VAULT_ACCESSMODES"] == null ? "ReadWriteOnce" : local.jarvice_helm_values["JARVICE_PVC_VAULT_ACCESSMODES"]}
  JARVICE_PVC_VAULT_SIZE: ${local.jarvice_helm_values["JARVICE_PVC_VAULT_SIZE"] == null ? 10 : local.jarvice_helm_values["JARVICE_PVC_VAULT_SIZE"]}

  JARVICE_POD_SCHED_MULTIPLIERS: '{"cpu": 0, "memory": 0, "ephemeral-storage": 0, "pods": 0}'

  daemonsets:
    nodeAffinity: '{"requiredDuringSchedulingIgnoredDuringExecution": {"nodeSelectorTerms": [{"matchExpressions": [{"key": "node-role.jarvice.io/jarvice-compute", "operator": "Exists"}]}, {"matchExpressions": [{"key": "node-role.kubernetes.io/jarvice-compute", "operator": "Exists"}]}] }}'
    lxcfs:
      enabled: true

jarvice_db:
  persistence:
    enabled: true
    storageClassProvisioner: ${var.storage_class_provisioner}

jarvice_bird_server:
  persistence:
    enabled: true
    storageClassProvisioner: ${var.storage_class_provisioner}

jarvice_dal:
  env:
    JARVICE_MACHINES_ADD: '${local.jarvice_machines_add}'

jarvice_k8s_scheduler:
  env:
    JARVICE_UNFS_NODE_SELECTOR: '{"node-role.jarvice.io/jarvice-system": "true"}'

jarvice_dockerbuild:
  tolerations: '[{"key": "node-role.jarvice.io/jarvice-dockerbuild", "effect": "NoSchedule", "operator": "Exists"}]'
  nodeAffinity: '{"requiredDuringSchedulingIgnoredDuringExecution": {"nodeSelectorTerms": [{"matchExpressions": [{"key": "node-role.jarvice.io/jarvice-dockerbuild", "operator": "Exists"}]}] }}'
  persistence:
    enabled: true
    storageClassProvisioner: ${var.storage_class_provisioner_dockerbuild}

jarvice_dockerbuild_pvc_gc:
  enabled: true
EOF
}

locals {
    cluster_output_message = local.jarvice_cluster_type == "downstream" ? "Add the downstream cluster URL to an upstream JARVICE cluster" : "Open the portal URL to initialize JARVICE"
}

