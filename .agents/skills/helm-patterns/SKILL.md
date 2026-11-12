---
name: helm-patterns
description: Helm chart 구조 · values 분리 · dependency · upgrade 안전 패턴.
---

# Helm Patterns

## 언제 Helm vs kustomize?

| 상황 | 도구 |
|------|------|
| 자기 앱 manifest | **kustomize** (단순, template 엔진 X) |
| 외부 OSS 배포 (Prometheus, Cert-Manager 등) | **Helm** (chart 생태계) |
| 라이브러리 chart 배포 (다른 팀에 제공) | **Helm** |

자기 앱에 Helm 쓰면 `_helpers.tpl` 추상화 폭증. 단순함 선호.

## 1. 디렉토리 구조

```
my-chart/
├── Chart.yaml                  # 메타 + dependencies
├── values.yaml                 # 디폴트 값
├── values.prod.yaml            # 환경별 override
├── values.staging.yaml
├── templates/
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── ingress.yaml
│   ├── _helpers.tpl
│   └── NOTES.txt
└── charts/                     # 의존성 chart (helm dep update 가 채움)
```

## 2. Chart.yaml

```yaml
apiVersion: v2
name: api-auth
description: Authentication service
type: application
version: 1.2.3                  # chart 버전 (SemVer)
appVersion: "1.2.3"             # 앱 이미지 태그
dependencies:
  - name: postgresql
    version: "13.2.x"
    repository: https://charts.bitnami.com/bitnami
    condition: postgresql.enabled
```

- `version` (chart) 과 `appVersion` (앱) 분리 — chart 만 수정 시 chart version 만 bump
- dependency `version` 도 `~>` pin (major 변경 차단)

## 3. values 계층

```bash
# 디폴트 → 환경 → CLI override
helm upgrade api ./my-chart \
  -f values.yaml \
  -f values.prod.yaml \
  --set image.tag=1.2.3
```

**`values.yaml` 은 안전 디폴트** — 운영에서 그대로 써도 안 깨질 값:
```yaml
replicaCount: 1                 # prod 에서 override
image:
  repository: ghcr.io/myorg/api-auth
  tag: ""                       # 비워두고 명시 주입 강제
  pullPolicy: IfNotPresent
resources:                      # 항상 정의
  requests: { cpu: 100m, memory: 256Mi }
  limits: { cpu: 500m, memory: 512Mi }
service:
  type: ClusterIP
ingress:
  enabled: false
postgresql:
  enabled: false                # prod 는 외부 RDS, dev 만 enable
```

## 4. Template Helper

```yaml
# templates/_helpers.tpl
{{- define "my-chart.fullname" -}}
{{- printf "%s-%s" .Release.Name .Chart.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "my-chart.labels" -}}
app.kubernetes.io/name: {{ include "my-chart.fullname" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}
```

리소스마다 표준 label 적용:
```yaml
metadata:
  labels:
    {{- include "my-chart.labels" . | nindent 4 }}
```

## 5. Upgrade 안전

```bash
# Atomic upgrade — 실패 시 자동 rollback
helm upgrade api ./my-chart \
  -f values.prod.yaml \
  --atomic --timeout 5m

# 또는
helm upgrade ... --wait --wait-for-jobs
```

- `--atomic` 으로 부분 적용 차단
- `helm history` + `helm rollback <release> <revision>` 로 빠른 복구

## 6. CRD 처리

- `crds/` 디렉토리는 **Helm 이 install 시 한 번만 적용**, upgrade 시 변경 안 함
- CRD 스키마 변경 시 kubectl 로 별도 적용 필요 (Helm 한계)

## 7. 의식적 배제

- **`tpl` 함수로 동적 템플릿** — 디버깅 지옥. 정말 필요한 경우만 (예: annotations)
- **`Chart.yaml` 수동 dependency 작성** — `helm dep update` 사용
- **values 에 secret 평문** — Sealed Secrets / External Secrets Operator
- **`helm install` 운영** — 항상 `helm upgrade --install` (idempotent)
- **`--force`** — 리소스 재생성, 다운타임 발생

## 8. CI 검증

```bash
helm lint ./my-chart
helm template ./my-chart -f values.prod.yaml | kubectl apply --dry-run=server -f -
```

PR 마다 `helm template` + `kubeval` 또는 `kube-linter` 로 정적 검증.
