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
{{- if semverCompare "^0.1" .Chart.Version -}}
{{- if (not (empty .Values.jarvice.JARVICE_IMAGES_VERSION)) -}}
{{- printf "-%s" .Values.jarvice.JARVICE_IMAGES_VERSION -}}
{{- end -}}
{{- else -}}
{{- printf "-%s" .Chart.Version | trimSuffix "-development" | trimSuffix "-testing" -}}
{{- end -}}
{{- end -}}

{{/*
Get ingressHost for the portal
*/}}
{{- define "jarvice.ingressHostPortal" -}}
{{- if hasSuffix ".gethostbyname.nip.io" .Values.jarvice_mc_portal.ingressHost -}}
{{- printf "%s.%s.nip.io" (trimSuffix ".gethostbyname.nip.io" .Values.jarvice_mc_portal.ingressHost) (getHostByName (first (lookup "v1" "Service" .Values.jarvice_mc_portal.ingressServiceNamespace .Values.jarvice_mc_portal.ingressService).status.loadBalancer.ingress).hostname) -}}
{{- else if hasSuffix ".nip.io" .Values.jarvice_mc_portal.ingressHost -}}
{{- printf "%s.%s.nip.io" (trimSuffix ".nip.io" .Values.jarvice_mc_portal.ingressHost) (first (lookup "v1" "Service" .Values.jarvice_mc_portal.ingressServiceNamespace .Values.jarvice_mc_portal.ingressService).status.loadBalancer.ingress).ip -}}
{{- else if or (eq "lookupip" .Values.jarvice_mc_portal.ingressHost) (eq "-" .Values.jarvice_mc_portal.ingressHost) -}}
{{- printf "%s" (first (lookup "v1" "Service" .Values.jarvice_mc_portal.ingressServiceNamespace .Values.jarvice_mc_portal.ingressService).status.loadBalancer.ingress).ip -}}
{{- else if eq "lookup" .Values.jarvice_mc_portal.ingressHost -}}
{{- printf "%s" (first (lookup "v1" "Service" .Values.jarvice_mc_portal.ingressServiceNamespace .Values.jarvice_mc_portal.ingressService).status.loadBalancer.ingress).hostname -}}
{{- else -}}
{{- printf "%s" .Values.jarvice_mc_portal.ingressHost -}}
{{- end -}}
{{- end -}}

{{/*
Get ingressHost for the API endpoint
*/}}
{{- define "jarvice.ingressHostApi" -}}
{{- if hasSuffix ".gethostbyname.nip.io" .Values.jarvice_api.ingressHost -}}
{{- printf "%s.%s.nip.io" (trimSuffix ".gethostbyname.nip.io" .Values.jarvice_api.ingressHost) (getHostByName (first (lookup "v1" "Service" .Values.jarvice_api.ingressServiceNamespace .Values.jarvice_api.ingressService).status.loadBalancer.ingress).hostname) -}}
{{- else if hasSuffix ".nip.io" .Values.jarvice_api.ingressHost -}}
{{- printf "%s.%s.nip.io" (trimSuffix ".nip.io" .Values.jarvice_api.ingressHost) (first (lookup "v1" "Service" .Values.jarvice_api.ingressServiceNamespace .Values.jarvice_api.ingressService).status.loadBalancer.ingress).ip -}}
{{- else if or (eq "lookupip" .Values.jarvice_api.ingressHost) (eq "-" .Values.jarvice_api.ingressHost) -}}
{{- printf "%s" (first (lookup "v1" "Service" .Values.jarvice_api.ingressServiceNamespace .Values.jarvice_api.ingressService).status.loadBalancer.ingress).ip -}}
{{- else if eq "lookup" .Values.jarvice_api.ingressHost -}}
{{- printf "%s" (first (lookup "v1" "Service" .Values.jarvice_api.ingressServiceNamespace .Values.jarvice_api.ingressService).status.loadBalancer.ingress).hostname -}}
{{- else -}}
{{- printf "%s" .Values.jarvice_api.ingressHost -}}
{{- end -}}
{{- end -}}

{{/*
Get ingressHost for the k8s-scheduler
*/}}
{{- define "jarvice.ingressHostK8sScheduler" -}}
{{- if hasSuffix ".gethostbyname.nip.io" .Values.jarvice_k8s_scheduler.ingressHost -}}
{{- printf "%s.%s.nip.io" (trimSuffix ".gethostbyname.nip.io" .Values.jarvice_k8s_scheduler.ingressHost) (getHostByName (first (lookup "v1" "Service" .Values.jarvice_k8s_scheduler.ingressServiceNamespace .Values.jarvice_k8s_scheduler.ingressService).status.loadBalancer.ingress).hostname) -}}
{{- else if hasSuffix ".nip.io" .Values.jarvice_k8s_scheduler.ingressHost -}}
{{- printf "%s.%s.nip.io" (trimSuffix ".nip.io" .Values.jarvice_k8s_scheduler.ingressHost) (first (lookup "v1" "Service" .Values.jarvice_k8s_scheduler.ingressServiceNamespace .Values.jarvice_k8s_scheduler.ingressService).status.loadBalancer.ingress).ip -}}
{{- else if or (eq "lookupip" .Values.jarvice_k8s_scheduler.ingressHost) (eq "-" .Values.jarvice_k8s_scheduler.ingressHost) -}}
{{- printf "%s" (first (lookup "v1" "Service" .Values.jarvice_k8s_scheduler.ingressServiceNamespace .Values.jarvice_k8s_scheduler.ingressService).status.loadBalancer.ingress).ip -}}
{{- else if eq "lookup" .Values.jarvice_k8s_scheduler.ingressHost -}}
{{- printf "%s" (first (lookup "v1" "Service" .Values.jarvice_k8s_scheduler.ingressServiceNamespace .Values.jarvice_k8s_scheduler.ingressService).status.loadBalancer.ingress).hostname -}}
{{- else -}}
{{- printf "%s" .Values.jarvice_k8s_scheduler.ingressHost -}}
{{- end -}}
{{- end -}}

{{/*
Get ingressHost for the license manager
*/}}
{{- define "jarvice.ingressHostLicenseManager" -}}
{{- if hasSuffix ".gethostbyname.nip.io" .Values.jarvice_license_manager.ingressHost -}}
{{- printf "%s.%s.nip.io" (trimSuffix ".gethostbyname.nip.io" .Values.jarvice_license_manager.ingressHost) (getHostByName (first (lookup "v1" "Service" .Values.jarvice_license_manager.ingressServiceNamespace .Values.jarvice_license_manager.ingressService).status.loadBalancer.ingress).hostname) -}}
{{- else if hasSuffix ".nip.io" .Values.jarvice_license_manager.ingressHost -}}
{{- printf "%s.%s.nip.io" (trimSuffix ".nip.io" .Values.jarvice_license_manager.ingressHost) (first (lookup "v1" "Service" .Values.jarvice_license_manager.ingressServiceNamespace .Values.jarvice_license_manager.ingressService).status.loadBalancer.ingress).ip -}}
{{- else if or (eq "lookupip" .Values.jarvice_license_manager.ingressHost) (eq "-" .Values.jarvice_license_manager.ingressHost) -}}
{{- printf "%s" (first (lookup "v1" "Service" .Values.jarvice_license_manager.ingressServiceNamespace .Values.jarvice_license_manager.ingressService).status.loadBalancer.ingress).ip -}}
{{- else if eq "lookup" .Values.jarvice_license_manager.ingressHost -}}
{{- printf "%s" (first (lookup "v1" "Service" .Values.jarvice_license_manager.ingressServiceNamespace .Values.jarvice_license_manager.ingressService).status.loadBalancer.ingress).hostname -}}
{{- else -}}
{{- printf "%s" .Values.jarvice_license_manager.ingressHost -}}
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
Return apiVersion for Ingress.
*/}}
{{- define "apiVersion.ingress" -}}
{{- if and false (semverCompare ">=1.19-0" .Capabilities.KubeVersion.GitVersion) -}}
{{- print "networking.k8s.io/v1" -}}
{{- else -}}
{{- print "networking.k8s.io/v1beta1" -}}
{{- end -}}
{{- end -}}

{{/*
Return apiVersion for PriorityClass.
*/}}
{{- define "apiVersion.priorityClass" -}}
{{- if semverCompare ">=1.14-0" .Capabilities.KubeVersion.GitVersion -}}
{{- print "scheduling.k8s.io/v1" -}}
{{- else -}}
{{- print "scheduling.k8s.io/v1beta1" -}}
{{- end -}}
{{- end -}}
