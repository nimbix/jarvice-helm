# locals.tf - helm module local variable definitions

locals {
    jarvice_chart_repository = contains(keys(var.jarvice), "repository") ? var.jarvice["repository"] : contains(keys(var.global), "repository") ? var.global["repository"] : "https://nimbix.github.io/jarvice-helm/"

    jarvice_chart_version = contains(keys(var.jarvice), "version") ? var.jarvice["version"] : var.global["version"]

    jarvice_chart_is_dir = local.jarvice_chart_version == null ? false : fileexists("${pathexpand(local.jarvice_chart_version)}/Chart.yaml")

    jarvice_user_cacert = contains(keys(var.jarvice), "user_cacert") ? var.jarvice["user_cacert"] : "ca-certificate.crt"

    jarvice_user_java_cacert = contains(keys(var.jarvice), "user_java_cacert") ? var.jarvice["user_java_cacert"] : "cacerts"
}

locals {
    user_cacert = fileexists(local.jarvice_user_cacert) ? file(local.jarvice_user_cacert) : ""
    java_cacert = fileexists(local.jarvice_user_java_cacert) ? filebase64(local.jarvice_user_java_cacert) : ""
}

locals {
    user_cacert_values_yaml =  <<EOF
jarvice:
  cacert:
    user:
      configMap: jarvice-cacert
EOF

    java_cacert_values_yaml = <<EOF
jarvice:
  cacert:
    java:
      configMap: jarvice-java-cacert
EOF

}
