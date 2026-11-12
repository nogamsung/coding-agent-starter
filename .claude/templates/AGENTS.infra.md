# [프로젝트명] — DevOps / Infrastructure

## Stack
Terraform · Kubernetes (kustomize) · Helm · External Secrets Operator · GitHub Actions

## Agents & Commands
| 목적 | Agent / Command |
|------|----------------|
| Terraform 모듈 / K8s manifest / Helm chart 생성 | `infra-generator` |
| 코드 리뷰 | `code-reviewer` · `/review` |
| GitHub Actions 워크플로 | `github-actions-designer` |
| 신규 기능 시작 | `/start <기능>` (worktree + PRD + 자동 구현) |
| 설계만 / 추가 PRD | `/plan <기능>` |
| 커밋/PR/머지 | `/commit` · `/pr` · `/merge` |
| Second Brain | `/memory [add\|search]` |

## Git 전략
| 브랜치 | 역할 |
|--------|------|
| `main` | 프로덕션 — PR+CI 필수 (apply 게이트) |
| `dev` | staging 환경 자동 apply 대상 |
| `{feature\|fix\|hotfix\|chore}/{name}` | 작업 브랜치 |

`main` 직접 push 금지. apply 는 항상 PR merge 후 main 에서.

## 디렉토리 구조 (권장)
```
infra/                           # Terraform
├── modules/                     # 재사용 모듈 (provider/backend X)
│   ├── vpc/
│   └── eks-cluster/
└── envs/                        # 배포 단위 (provider/backend O)
    ├── prod/
    ├── staging/
    └── dev/

k8s/                             # Kubernetes manifest (kustomize)
├── base/
└── overlays/{prod,staging,dev}/

charts/                          # Helm (외부 OSS 또는 라이브러리 chart)
└── my-app/
    ├── Chart.yaml
    ├── values.yaml
    └── templates/

.github/workflows/
├── terraform-plan.yml           # PR 트리거
├── terraform-apply.yml          # main merge 후 수동 approve
└── k8s-deploy.yml
```

## MUST
- **Terraform state remote 저장** — S3 + DynamoDB lock. 환경별 분리.
- **모든 리소스 태그**: `Environment`, `Service`, `Owner`, `ManagedBy=terraform`
- **K8s Pod 필수 항목**: resources requests/limits + liveness/readiness probes
- **image tag = SemVer 명시** — `latest` 금지
- **Secret 은 ExternalSecret / SOPS / Sealed Secrets** — Plain Secret 금지 (base64 = 평문)
- **`terraform plan -detailed-exitcode`** drift 검출을 daily cron 으로
- **`helm upgrade --atomic`** — 부분 적용 차단

## NEVER
- `*.tfstate*` git 커밋
- `terraform workspace` 로 환경 분리 (디렉토리 분리 권장)
- `latest` image tag 운영 사용
- `replicas: 1` 운영 (rolling update 다운타임)
- `hostPath` 볼륨, `privileged: true`
- `kubectl edit` / `kubectl scale` 운영 (drift 발생)
- Helm 으로 자기 앱 배포 (kustomize 권장)
- secret 평문 commit (SOPS 등 암호화 필수)
- `terraform apply` 자동 (수동 approve 게이트)

## 명령어
```bash
# Terraform
terraform fmt -check / terraform validate / terraform plan -out=tfplan
terraform apply tfplan

# Kubernetes
kubectl apply -k k8s/overlays/prod/ --dry-run=server
kustomize build k8s/overlays/prod/ | kube-linter lint -

# Helm
helm lint ./charts/my-app
helm template ./charts/my-app -f values.prod.yaml | kubectl apply --dry-run=server -f -
helm upgrade my-app ./charts/my-app --atomic --timeout 5m
```

**상세 패턴**:
- Terraform: `.agents/skills/terraform-patterns/SKILL.md`
- Kubernetes: `.agents/skills/kubernetes-patterns/SKILL.md`
- Helm: `.agents/skills/helm-patterns/SKILL.md`
- GitHub Actions: `.agents/skills/github-actions-patterns/SKILL.md`
- Observability: `.agents/skills/observability-patterns/SKILL.md`
- 보안: `.agents/skills/security-patterns/SKILL.md`

## Memory
세션 시작 시 `memory/MEMORY.md` 자동 로드. 인프라 변경, 장애 회고, 비용 결정, 운영 사고 → 자동 기록.

> **AGENTS.md ≤ 300줄 캡** — 초과 시 상세는 `.agents/skills/` 또는 `docs/` 로 이관, 본문은 인덱스 한 줄로.
