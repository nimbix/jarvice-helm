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
JARVICE version for images
*/}}
{{- define "jarvice.version" -}}
{{- if semverCompare "^2.0.18-0" .Chart.Version -}}
{{- printf "-%s" .Chart.Version -}}
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
