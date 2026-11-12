# [프로젝트명] — Go Workspace (멀티 서비스)

## Stack
Go · Go Workspace (`go.work`) · Gin · GORM + **sqlc** · golang-migrate · **golangci-lint** · **swaggo/swag** · testify + mockery

## Agents & Commands
`go-generator` / `go-modifier` / `go-tester` / `code-reviewer`. `/new module <svc>` 로 서비스 추가. 공통 커맨드는 단일 모듈과 동일.

## Go Workspace 구조
```
go.work                  # use ./services/api ./services/worker ./pkg/shared
services/
  api/
    go.mod
    cmd/main.go
    internal/{domain,usecase,repository,handler,middleware}/
    migrations/ · db/{query,sqlc}/ · mocks/ · testutil/
  worker/
    go.mod · cmd/main.go · internal/
pkg/shared/
  go.mod
  domain/ · errors/      # 서비스 공통 Entity, 타입, 에러
```

## 의존 규칙
| 모듈 | 의존 가능 | 의존 불가 |
|------|----------|----------|
| `pkg/shared` | (없음 — 순수) | `services/*` |
| `services/api` | `pkg/shared` | `services/worker` |
| `services/worker` | `pkg/shared` | `services/api` |

**레이어 의존 (각 서비스 내부)**: `handler` → `usecase` → `domain` ← `repository`. `domain/` 외부 import 금지.

## 공통 규칙
**레이어별 세부 규칙은 `AGENTS.go.md` 와 동일** — MUST/NEVER 섹션 그대로 적용.

## NEVER (멀티 추가)
- `services/api` 에서 `services/worker` import (반대도 금지)
- `pkg/shared` 에서 `services/*` import (순수 유지)

## 명령어
```bash
# workspace 루트
go test ./... / go vet ./... / go build ./...
go work sync

# 서비스 단위 (golangci-lint 는 workspace 미지원)
cd services/api && golangci-lint run ./...
cd services/api && swag init -g cmd/main.go -o docs
```

**상세 패턴**: `.agents/skills/go-patterns/SKILL.md`.

**커버리지 게이트**: git push 전 각 서비스 ≥80% + golangci-lint 통과 (`.claude/hooks/pre-push.sh`).

## 학습된 규칙
<!-- /rule 로 여기에 추가됩니다 -->

## Memory
세션 시작 시 `memory/MEMORY.md` 자동 로드.

> **AGENTS.md ≤ 300줄 캡** — 초과 시 상세는 `.agents/skills/` 또는 `docs/` 로 이관, 본문은 인덱스 한 줄로.
