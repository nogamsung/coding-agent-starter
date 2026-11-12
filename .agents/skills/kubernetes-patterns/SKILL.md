---
name: kubernetes-patterns
description: Kubernetes manifest 구조 · kustomize overlay · secret · resource limits · probes 패턴.
---

# Kubernetes Patterns

## 1. 디렉토리 구조 (kustomize)

```
k8s/
├── base/                       # 환경 무관 공통
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── configmap.yaml
│   └── kustomization.yaml
└── overlays/
    ├── prod/
    │   ├── kustomization.yaml  # base + patch
    │   ├── replicas-patch.yaml
    │   └── resources-patch.yaml
    ├── staging/
    └── dev/
```

**kustomize 우선** — Helm 은 외부 chart 배포용, 자기 앱은 kustomize 가 단순 (template 엔진 없음).

## 2. 필수 manifest 항목

### Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-auth
  labels:
    app.kubernetes.io/name: api-auth
    app.kubernetes.io/managed-by: kustomize
spec:
  replicas: 2                            # overlay 에서 환경별 조정
  strategy:
    type: RollingUpdate
    rollingUpdate: { maxUnavailable: 0, maxSurge: 1 }
  selector:
    matchLabels: { app.kubernetes.io/name: api-auth }
  template:
    metadata:
      labels: { app.kubernetes.io/name: api-auth }
    spec:
      containers:
        - name: api
          image: ghcr.io/myorg/api-auth:1.2.3   # 항상 명시 태그, latest 금지
          ports: [{ containerPort: 8080 }]
          resources:                             # 필수 — 미설정 시 노드 OOM
            requests: { cpu: 100m, memory: 256Mi }
            limits:   { cpu: 500m, memory: 512Mi }
          livenessProbe:                         # 필수
            httpGet: { path: /healthz, port: 8080 }
            initialDelaySeconds: 30
            periodSeconds: 10
          readinessProbe:                        # 필수 — 트래픽 라우팅 결정
            httpGet: { path: /readyz, port: 8080 }
            periodSeconds: 5
          env:
            - { name: DATABASE_URL, valueFrom: { secretKeyRef: { name: api-secrets, key: database_url } } }
```

- **image tag = latest 금지** — 재현 불가, 롤백 어려움
- **resources 미설정 = 안티패턴** — 노드 압박 시 random kill
- **liveness ≠ readiness** — liveness 는 재시작 트리거, readiness 는 트래픽 차단

### Service / Ingress

```yaml
apiVersion: v1
kind: Service
metadata: { name: api-auth }
spec:
  type: ClusterIP                         # 기본 — LB 는 Ingress 가 처리
  selector: { app.kubernetes.io/name: api-auth }
  ports: [{ port: 80, targetPort: 8080 }]
```

## 3. Secret 관리

**Plain Secret 금지** (base64 = 평문). 다음 중 하나:

| 방법 | 적합성 |
|------|-------|
| **External Secrets Operator** + AWS Secrets Manager / Vault | 운영 환경 표준 |
| **SOPS** + age/PGP | git 에 암호화 commit 필요 시 |
| **Sealed Secrets** | bitnami, 클러스터 내 controller |

```yaml
# ExternalSecret 예시
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata: { name: api-secrets }
spec:
  refreshInterval: 1h
  secretStoreRef: { name: aws-sm, kind: SecretStore }
  target: { name: api-secrets }
  data:
    - { secretKey: database_url, remoteRef: { key: prod/api/db_url } }
```

## 4. Namespace 정책

- 환경별 namespace (`prod`, `staging`) 또는 팀별 (`team-payments`) — 한 클러스터 multi-tenancy
- `default` 사용 금지
- NetworkPolicy 로 namespace 간 통신 명시 (default deny)

## 5. ResourceQuota / LimitRange

각 namespace 에 quota 강제 — runaway pod 방지:

```yaml
apiVersion: v1
kind: ResourceQuota
metadata: { name: team-quota, namespace: team-payments }
spec:
  hard:
    requests.cpu: "20"
    requests.memory: 40Gi
    limits.memory: 80Gi
    persistentvolumeclaims: "10"
```

## 6. 의식적 배제

- **`hostPath` 볼륨** — 노드 의존성, 보안 위험
- **`privileged: true`** — 거의 항상 잘못된 설계
- **NodePort 직접 노출** — Ingress / LoadBalancer 사용
- **`namespace: default`** — multi-tenancy 깨짐
- **`replicas: 1` 운영** — rolling update 시 다운타임. 최소 2

## 7. 디버깅 표준

```bash
kubectl describe pod <name> -n <ns>     # event 확인
kubectl logs <pod> -n <ns> --previous   # 이전 컨테이너 로그
kubectl exec -it <pod> -n <ns> -- sh    # 임시 진입
kubectl top pod -n <ns>                 # 리소스 사용
```

- `kubectl edit` 운영에서 금지 — drift 발생. `kubectl apply` 만.
- `kubectl scale --replicas` 도 일시 조치만, manifest 갱신 + git commit
