---
name: terraform-patterns
description: Terraform 모듈 구조 · state 관리 · naming · workspace · drift 검출 패턴.
---

# Terraform Patterns

## 1. 디렉토리 구조

```
infra/
├── modules/                    # 재사용 가능한 모듈
│   ├── vpc/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── versions.tf
│   └── eks-cluster/
└── envs/                       # 환경별 root 모듈
    ├── prod/
    │   ├── main.tf            # modules/* 호출
    │   ├── backend.tf         # state backend
    │   ├── providers.tf
    │   └── terraform.tfvars
    ├── staging/
    └── dev/
```

**모듈 vs root** 구분:
- `modules/*` 은 **재사용 단위** — provider 정의 X, backend 정의 X
- `envs/*` 은 **배포 단위** — provider/backend/state 보유

## 2. State 관리

**Remote backend 필수** (S3 + DynamoDB lock 기본):

```hcl
# envs/prod/backend.tf
terraform {
  backend "s3" {
    bucket         = "my-tfstate-prod"
    key            = "infra/terraform.tfstate"
    region         = "ap-northeast-2"
    dynamodb_table = "tfstate-lock"
    encrypt        = true
  }
}
```

- **state 파일은 git 에 커밋 금지** (`*.tfstate*` gitignore)
- 환경별 state 분리 (`envs/prod/` ≠ `envs/staging/`) — cross-env blast radius 차단
- `terraform_remote_state` 로 다른 stack output 참조 시 read-only data source

## 3. Naming

리소스 이름은 `{env}-{service}-{purpose}`:
```hcl
resource "aws_s3_bucket" "uploads" {
  bucket = "${var.env}-${var.service}-uploads"  # prod-api-auth-uploads
}
```

- 변수 `env`, `service`, `region` 은 모든 모듈 공통 input
- tag 정책: `Environment`, `Service`, `Owner`, `ManagedBy=terraform` 모든 리소스에

## 4. Versioning

```hcl
# versions.tf (모듈마다)
terraform {
  required_version = "~> 1.7"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
```

- `~>` (pessimistic) 로 minor 업데이트 허용, major 핀
- `terraform.lock.hcl` 은 git 커밋 (재현 가능성)

## 5. Workspace 사용 X

`terraform workspace` 는 환경 분리에 부적합 — 같은 backend 의 다른 key 만 다를 뿐 blast radius 동일. **디렉토리 분리** 가 안전.

예외: 동일 환경의 multi-region 배포는 workspace 가능 (`prod-apne2`, `prod-use1`).

## 6. Sensitive 데이터

```hcl
variable "db_password" {
  type      = string
  sensitive = true
}
```

- `sensitive = true` 로 plan/apply 출력 마스킹
- `tfvars` 에 평문 secret 금지 — AWS Secrets Manager / SOPS 사용
- `output` 도 `sensitive = true` 명시

## 7. Drift 검출

```bash
terraform plan -detailed-exitcode  # exit 2 = drift 있음
```

CI 에서 daily cron 으로 실행 → drift 발견 시 alert. `apply` 자동 X.

## 8. 의식적 배제

- **`count` 로 0/1 토글** — `dynamic` block 또는 `for_each` 가 더 명확
- **`local-exec` 남용** — terraform 외부 부수 효과는 추적 불가. 정말 필요하면 `null_resource` + trigger
- **이미 배포된 리소스 import 없이 재생성** — 운영 데이터 손실. `terraform import` 또는 `removed` block (1.7+) 활용
- **provider 버전 미고정** — 무인 배포 환경에서 silent breaking change

## 9. CI/CD 통합

```yaml
# .github/workflows/terraform.yml (PR 트리거)
- run: terraform fmt -check
- run: terraform init
- run: terraform validate
- run: terraform plan -out=tfplan
- uses: hashicorp/terraform-github-actions/.../comment  # PR 코멘트
```

- `apply` 는 PR merge 후 main 에서만, 수동 approve 게이트
- 모듈 변경 시 affected envs 만 plan (path filter)
