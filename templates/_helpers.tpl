{{/* vim: set filetype=mustache: */}}
{{/*
Expand the name of the chart.
*/}}
{{- define "jarvice.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "jarvice.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
JARVICE registry for images
*/}}
{{- define "jarvice.registry" -}}
{{- if .Values.jarvice_registry_proxy.enabled -}}
{{- printf "localhost:%s" (.Values.jarvice_registry_proxy.nodePort | toString) -}}
{{- else -}}
{{- printf "%s" .Values.jarvice.JARVICE_SYSTEM_REGISTRY -}}
{{- end -}}
{{- end -}}

{{/*
JARVICE registry substitution for images
*/}}
{{- define "jarvice.registrysub" -}}
{{- if .Values.jarvice_registry_proxy.enabled -}}
{{- printf "localhost:%s/%s" (.Values.jarvice_registry_proxy.nodePort | toString) (trimPrefix (printf "%s/" .Values.jarvice.JARVICE_SYSTEM_REGISTRY) .image) -}}
{{- else -}}
{{- printf "%s" .image -}}
{{- end -}}
{{- end -}}

{{/*
JARVICE registry auths
*/}}
{{- define "jarvice.dockerconfigjson" -}}
{{- if .Values.jarvice.imagePullRegistries -}}
{{- $auths := (list) -}}
{{- range .Values.jarvice.imagePullRegistries -}}
{{- $auths = append $auths (printf "\"%s\": {\"auth\": \"%s\"}" . $.Values.jarvice.imagePullSecret) -}}
{{- end -}}
{{- printf "{\"auths\": {%s}}" ($auths | join ",") | b64enc -}}
{{- else -}}
{{- if .Values.jarvice.JARVICE_SYSTEM_REGISTRY_ALT -}}
{{- printf "{\"auths\": {\"%s\": {\"auth\": \"%s\"},\"%s\": {\"auth\": \"%s\"}}}" (include "jarvice.registry" .) .Values.jarvice.imagePullSecret .Values.jarvice.JARVICE_SYSTEM_REGISTRY_ALT .Values.jarvice.imagePullSecret | b64enc -}}
{{- else -}}
{{- printf "{\"auths\": {\"%s\": {\"auth\": \"%s\"}}}" (include "jarvice.registry" .) .Values.jarvice.imagePullSecret | b64enc -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
JARVICE tag for images
*/}}
{{- define "jarvice.tag" -}}
{{- if hasPrefix "jarvice-" .Chart.Annotations.tag -}}
{{- printf "%s" .Chart.Annotations.tag -}}
{{- else if (not (empty .Values.jarvice.JARVICE_IMAGES_TAG)) -}}
{{- printf "%s" .Values.jarvice.JARVICE_IMAGES_TAG -}}
{{- else -}}
{{- print "jarvice-master" -}}
{{- end -}}
{{- end -}}

{{/*
JARVICE version for images
*/}}
{{- define "jarvice.version" -}}
{{- if (not (empty .Values.jarvice.JARVICE_IMAGES_VERSION)) -}}
{{- printf "-%s" .Values.jarvice.JARVICE_IMAGES_VERSION -}}
{{- else if (not (empty .Chart.Annotations.version)) -}}
{{- printf "-%s" .Chart.Annotations.version | trimSuffix "-development" | trimSuffix "-testing" -}}
{{- end -}}
{{- end -}}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "jarvice.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create app name and version as used by the app label.
*/}}
{{- define "jarvice.app" -}}
{{- printf "%s-%s" .Chart.Name .Chart.AppVersion | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create release annotations for metadata.
*/}}
{{- define "jarvice.release_annotations" }}
chart: {{ template "jarvice.chart" . }}
jarvice: {{ template "jarvice.app" . }}
release: {{ .Release.Name }}
{{- end }}

{{/*
Create release labels for metadata.
*/}}
{{- define "jarvice.release_labels" }}
app: {{ template "jarvice.name" . }}
heritage: {{ .Release.Service }}
{{- end }}

{{/*
JARVICE no_proxy
*/}}
{{- define "jarvice.no_proxy" -}}
{{- $k8s_cluster_ip := (lookup "v1" "Service" "default" "kubernetes").spec.clusterIP -}}
{{- $jxe_services := (list "jarvice-api" "jarvice-dal" "jarvice-db" "jarvice-idmapper" "jarvice-k8s-scheduler" "jarvice-license-manager" "jarvice-mc-portal" "jarvice-scheduler" "jarvice-smtpd") -}}
{{- $jarvice_system_ns := .Release.Namespace -}}
{{- $jarvice_k8s_cluster_domain := "cluster.local" -}}
{{- if (not (empty .Values.jarvice.JARVICE_SYSTEM_NAMESPACE)) -}}
{{- $jarvice_system_ns = .Values.jarvice.JARVICE_SYSTEM_NAMESPACE -}}
{{- end -}}
{{- if (not (empty .Values.jarvice.JARVICE_K8S_CLUSTER_DOMAIN)) -}}
{{- $jarvice_k8s_cluster_domain = .Values.jarvice.JARVICE_K8S_CLUSTER_DOMAIN -}}
{{- end -}}
{{- printf "%s,%s,%s.%s,%s.%s.svc,%s.%s.svc.%s,svc,svc.%s,localhost,127.0.0.1" $k8s_cluster_ip ($jxe_services | join ",") ($jxe_services | join (printf ".%s," $jarvice_system_ns)) $jarvice_system_ns ($jxe_services | join (printf ".%s.svc," $jarvice_system_ns)) $jarvice_system_ns ($jxe_services | join (printf ".%s.svc.%s," $jarvice_system_ns $jarvice_k8s_cluster_domain )) $jarvice_system_ns $jarvice_k8s_cluster_domain $jarvice_k8s_cluster_domain -}}
{{- end -}}

{{/*
Create hostAlias for JARVICE
*/}}
{{- define "jarvice.hostAliases" -}}
{{- if try(.Values.jarvice.JARVICE_CLUSTER_TYPE, "downstream") == "upstream" }}
  {{- $service := (lookup "v1" "Service" "kube-system" "traefik") }}
  {{- if $service }}
    {{- range $index, $ingress := $service.status.loadBalancer.ingress }}
- ip: "{{- $ingress.ip }}"
  hostnames:
      {{- $ingressHosts := list }}
      {{- if $.Values.jarvice_api.enabled }}
        {{- if (not (empty $.Values.jarvice_api.ingressHost)) }}
        {{- $ingressHosts = printf "%s" $.Values.jarvice_api.ingressHost | append $ingressHosts }}
        {{- end }}
      {{- end }}
      {{- if $.Values.jarvice_bird.enabled }}
        {{- if (not (empty $.Values.jarvice_bird.ingressHost)) -}}
        {{- $ingressHosts = printf "%s" $.Values.jarvice_bird.ingressHost | append $ingressHosts }}
        {{- end }}
      {{- end }}
      {{- if $.Values.jarvice_license_manager.enabled }}
        {{- if (not (empty $.Values.jarvice_license_manager.ingressHost)) }}
        {{- $ingressHosts = printf "%s" $.Values.jarvice_license_manager.ingressHost | append $ingressHosts }}
        {{- end }}
      {{- end }}
      {{- if $.Values.jarvice_mc_portal.enabled }}
        {{- if (not (empty $.Values.jarvice_mc_portal.ingressHost)) }}
        {{- $ingressHosts = printf "%s" $.Values.jarvice_mc_portal.ingressHost | append $ingressHosts }}
        {{- end }}
      {{- end }}
      {{- if $.Values.keycloakx.enabled }}
        {{- with index $.Values.keycloakx.ingress.rules 0 }}
          {{- if (not (empty .host)) }}
          {{- $ingressHosts = printf "%s" .host | append $ingressHosts }}
          {{- end }}
        {{- end }}
      {{- end }}
      {{- $ingressHosts = $ingressHosts | uniq }}
      {{- range $ingressHosts }}
  - "{{ . }}"
      {{- end }}
    {{- end }}
  {{- end }}
{{- end }}
{{- end }}
