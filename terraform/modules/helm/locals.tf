# locals.tf - helm module local variable definitions

locals {
    jarvice_chart_repository = contains(keys(var.jarvice), "repository") ? var.jarvice["repository"] : contains(keys(var.global), "repository") ? var.global["repository"] : "https://nimbix.github.io/jarvice-helm/"

    jarvice_chart_version = contains(keys(var.jarvice), "version") ? var.jarvice["version"] : var.global["version"]

    jarvice_chart_is_dir = local.jarvice_chart_version == null ? false : fileexists("${pathexpand(local.jarvice_chart_version)}/Chart.yaml")

    jarvice_user_cacert = contains(keys(var.jarvice), "user_cacert") ? var.jarvice["user_cacert"] : "ca-certificate.crt"

    jarvice_user_java_cacert = contains(keys(var.jarvice), "user_java_cacert") ? var.jarvice["user_java_cacert"] : "cacerts"

    keycloak_chart_repository = contains(keys(var.keycloak), "repository") ? var.keycloak["repository"] : contains(keys(var.global), "repository") ? var.global["repository"] : "https://codecentric.github.io/helm-charts/"

    keycloak_chart_version = contains(keys(var.keycloak), "version") ? var.keycloak["version"] : var.global["version"]

    keycloak_user = contains(keys(var.keycloak), "keycloak_user") ? var.keycloak["keycloak_user"] : "jarvice"

    keycloak_pass = contains(keys(var.keycloak), "keycloak_pass") ? var.keycloak["keycloak_pass"] : "Pass1234"

    keycloak_ingress = contains(keys(var.keycloak), "keycloak_ingress") ? var.keycloak["keycloak_ingress"] : ""

    keycloak_realm_json = contains(keys(var.keycloak), "keycloak_realm") ? var.keycloak["keycloak_realm"] : "realm.json"

    keycloak_cert_issuer = contains(keys(var.keycloak), "keycloak_cert_issuer") ? var.keycloak["keycloak_cert_issuer"] : "letsencrypt-staging"

    keycloak_values_yaml = <<EOF
extraVolumes: |
  - name: jarvice-realm
    configMap:
      name: jarvice-keycloak-realm

extraVolumeMounts: |
  - name: jarvice-realm
    mountPath: "/realm/"
    readOnly: true

extraEnv: |
  - name: KEYCLOAK_USER
    value: ${local.keycloak_user}
  - name: KEYCLOAK_PASSWORD
    value: ${local.keycloak_pass}
  - name: PROXY_ADDRESS_FORWARDING
    value: "true"
  - name: KEYCLOAK_IMPORT
    value: /realm/realm.json
ingress:
  enabled: true
  annotations:
    cert-manager.io/issuer: ${local.keycloak_cert_issuer}
  ingressClassName: traefik
  rules:
  - host: ${local.keycloak_ingress}
    paths:
    - path: /
      pathType: Prefix
  tls:
  - hosts:
    - ${local.keycloak_ingress}
    secretName: tls-${local.keycloak_ingress}
EOF
}

