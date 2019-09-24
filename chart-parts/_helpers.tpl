{{/*
Define the standard labels that will be applied to all objects in this chart.
*/}}
{{- define "scf.labels" }}
    app.kubernetes.io/instance: {{ .Release.Name | quote }}
    app.kubernetes.io/managed-by: {{ .Release.Service | quote }}
    app.kubernetes.io/name: {{ default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" | quote }}
    app.kubernetes.io/version: {{ default .Chart.Version .Chart.AppVersion | quote }}
    helm.sh/chart: {{ printf "%s-%s" .Chart.Name (.Chart.Version | replace "+" "_") | quote }}
{{- end }}

{{/*
Define the role based labels that will be applied to all objects in this chart.
*/}}
{{- define "scf.role-labels" }}
    app.kubernetes.io/component: {{ quote . }}
    skiff-role-name: {{ quote . }}
{{- end }}
