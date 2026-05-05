{{- define "rancher-monitoring.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "rancher-monitoring.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := include "rancher-monitoring.name" . -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "rancher-monitoring.namespace" -}}
{{- default .Release.Namespace .Values.namespaceOverride -}}
{{- end -}}

{{- define "rancher-monitoring.chartref" -}}
{{- printf "%s-%s" .Chart.Name (.Chart.Version | replace "+" "_") -}}
{{- end -}}

{{- define "rancher-monitoring.labels" -}}
app.kubernetes.io/name: {{ include "rancher-monitoring.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/part-of: {{ include "rancher-monitoring.name" . }}
helm.sh/chart: {{ include "rancher-monitoring.chartref" . }}
chart: {{ include "rancher-monitoring.chartref" . }}
release: {{ .Release.Name | quote }}
heritage: {{ .Release.Service | quote }}
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end -}}

{{- define "rancher-monitoring.selectorLabels" -}}
app.kubernetes.io/name: {{ include "rancher-monitoring.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "kube-prometheus-stack.name" -}}
{{- include "rancher-monitoring.name" . -}}
{{- end -}}

{{- define "kube-prometheus-stack.fullname" -}}
{{- include "rancher-monitoring.fullname" . -}}
{{- end -}}

{{- define "kube-prometheus-stack.namespace" -}}
{{- include "rancher-monitoring.namespace" . -}}
{{- end -}}

{{- define "kube-prometheus-stack.labels" -}}
{{- include "rancher-monitoring.labels" . -}}
{{- end -}}

{{- define "rancher-monitoring.dashboardArtifacts.enabled" -}}
{{- if .Values.dashboardArtifacts.enabled -}}true{{- else if .Values.grafana.forceDeployDashboards -}}true{{- end -}}
{{- end -}}

{{- define "rancher-monitoring.dashboardNamespace" -}}
{{- if .Values.dashboardArtifacts.namespace -}}
{{- .Values.dashboardArtifacts.namespace -}}
{{- else -}}
{{- .Values.grafana.defaultDashboards.namespace -}}
{{- end -}}
{{- end -}}

{{- define "rancher-monitoring.dashboardLabel" -}}
{{- if .Values.dashboardArtifacts.label -}}
{{- .Values.dashboardArtifacts.label -}}
{{- else -}}
{{- .Values.grafana.sidecar.dashboards.label -}}
{{- end -}}
{{- end -}}

{{- define "rancher-monitoring.dashboardLabelValue" -}}
{{- if .Values.dashboardArtifacts.labelValue -}}
{{- .Values.dashboardArtifacts.labelValue -}}
{{- else -}}
{{- default "1" .Values.grafana.sidecar.dashboards.labelValue -}}
{{- end -}}
{{- end -}}

{{- define "rancher-monitoring.dashboardAnnotations" -}}
{{- $annotations := .Values.dashboardArtifacts.annotations -}}
{{- if empty $annotations -}}
{{- $annotations = .Values.grafana.sidecar.dashboards.annotations -}}
{{- end -}}
{{- with $annotations -}}
{{ toYaml . }}
{{- end -}}
{{- end -}}

{{- define "rancher-monitoring.dashboardLabels" -}}
{{- $label := include "rancher-monitoring.dashboardLabel" . -}}
{{- if $label }}
{{ $label }}: {{ include "rancher-monitoring.dashboardLabelValue" . | quote }}
{{- end }}
app.kubernetes.io/component: dashboard-artifact
app: {{ include "rancher-monitoring.name" . }}-dashboards
{{ include "rancher-monitoring.labels" . }}
{{- end -}}

{{- define "system_default_registry" -}}
{{- if .Values.global.cattle.systemDefaultRegistry -}}
{{- printf "%s/" .Values.global.cattle.systemDefaultRegistry -}}
{{- end -}}
{{- end -}}
