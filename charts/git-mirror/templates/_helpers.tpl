{{- define "git-mirror.fullname" -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "git-mirror.labels" -}}
app.kubernetes.io/name: {{ .Chart.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version }}
{{- end -}}

{{- define "git-mirror.selectorLabels" -}}
app.kubernetes.io/name: {{ .Chart.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "git-mirror.gitEnv" -}}
- name: SOURCE_URL
  value: {{ .Values.source.url | quote }}
- name: REPO_NAME
  value: {{ .Values.repoName | quote }}
- name: GIT_TERMINAL_PROMPT
  value: "0"
{{- if .Values.source.token }}
- name: GIT_ASKPASS
  value: /scripts/askpass.sh
- name: GIT_USERNAME
  valueFrom:
    secretKeyRef:
      name: {{ include "git-mirror.fullname" . }}
      key: username
- name: GIT_TOKEN
  valueFrom:
    secretKeyRef:
      name: {{ include "git-mirror.fullname" . }}
      key: token
{{- end }}
{{- end -}}

{{- define "git-mirror.securityContext" -}}
allowPrivilegeEscalation: false
capabilities:
  drop: ["ALL"]
{{- end -}}
