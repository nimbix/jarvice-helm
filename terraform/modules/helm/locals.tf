# locals.tf - helm module local variable definitions

locals {
    jarvice_chart_repository = contains(keys(var.jarvice), "repository") ? var.jarvice["repository"] : contains(keys(var.global), "repository") ? var.global["repository"] : "https://nimbix.github.io/jarvice-helm/"

    jarvice_chart_version = contains(keys(var.jarvice), "version") ? var.jarvice["version"] : var.global["version"]

    jarvice_chart_is_dir = local.jarvice_chart_version == null ? false : fileexists("${pathexpand(local.jarvice_chart_version)}/Chart.yaml")

    jarvice_helm_values = merge(
        yamldecode("XXXdummy: value\n\n${fileexists(var.global["values_file"]) ? file(var.global["values_file"]) : ""}"),
        yamldecode("XXXdummy: value\n\n${fileexists(var.jarvice["values_file"]) ? file(var.jarvice["values_file"]) : ""}"),
        yamldecode("XXXdummy: value\n\n${var.global["values_yaml"]}"),
        yamldecode("XXXdummy: value\n\n${var.jarvice["values_yaml"]}"),
        yamldecode("XXXdummy: value\n\n${var.common_values_yaml}")
    )

    jarvice_api = lookup(local.jarvice_helm_values, "jarvice_api", null)
    jarvice_ingress_api = local.jarvice_api == null ? "" : <<EOF
jarvice_api:
  XXXdummy: XXXdummyvalue
  ${lookup(local.jarvice_api, "ingressHost", null) == null ? "" : "ingressHost: ${local.jarvice_api["ingressHost"]}"}
  ${lookup(local.jarvice_api, "ingressPath", null) == null ? "" : "ingressHost: ${local.jarvice_api["ingressPath"]}"}
EOF

    jarvice_mc_portal = lookup(local.jarvice_helm_values, "jarvice_mc_portal", null)
    jarvice_ingress_mc_portal = local.jarvice_mc_portal == null ? "" : <<EOF
jarvice_mc_portal:
  XXXdummy: XXXdummyvalue
  ${lookup(local.jarvice_mc_portal, "ingressHost", null) == null ? "" : "ingressHost: ${local.jarvice_mc_portal["ingressHost"]}"}
  ${lookup(local.jarvice_mc_portal, "ingressPath", null) == null ? "" : "ingressHost: ${local.jarvice_mc_portal["ingressPath"]}"}
EOF

    jarvice_k8s_scheduler = lookup(local.jarvice_helm_values, "jarvice_k8s_scheduler", null)
    jarvice_ingress_k8s_scheduler = local.jarvice_k8s_scheduler == null ? "" : <<EOF
jarvice_k8s_scheduler:
  XXXdummy: XXXdummyvalue
  ${lookup(local.jarvice_k8s_scheduler, "ingressHost", null) == null ? "" : "ingressHost: ${local.jarvice_k8s_scheduler["ingressHost"]}"}
  ${lookup(local.jarvice_k8s_scheduler, "ingressPath", null) == null ? "" : "ingressHost: ${local.jarvice_k8s_scheduler["ingressPath"]}"}
EOF

    jarvice_ingress_values = <<EOF
# local.jarvice_ingress_values
${local.jarvice_ingress_api}

${local.jarvice_ingress_mc_portal}

${local.jarvice_ingress_k8s_scheduler}
EOF
}

