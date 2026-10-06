{{- define "rules.names" }}
rules:
  - "alertmanager.rules"
  - "general.rules"
  - "kubernetes-storage"
  - "prometheus"
  - "kubernetes-apps"
{{- end }}

{{- define "rules.additionalLabels" }}
{{- if .Values.defaultRules.additionalRuleLabels }}
{{ toYaml .Values.defaultRules.additionalRuleLabels | indent 8 }}
{{- end }}
{{- end }}

{{- define "rules.clusterIdLabel" }}
{{- if .Values.defaultRules.clusterIdLabel }}
cluster_id: {{ .Values.global.cattle.clusterId }}
{{- end }}
{{- end }}