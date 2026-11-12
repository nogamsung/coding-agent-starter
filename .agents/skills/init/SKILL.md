---
name: init
description: 프로젝트 스택 선언 → 불필요한 agent/template/skill 제거 → AGENTS.md + settings.json 설치 + Second Brain 초기화
argument-hint: "[kotlin | kotlin-multi | go | go-multi | python | python-multi | nextjs | nextjs-multi | flutter | monorepo | infra | marketing | sales | product] (생략 시 자동 감지)"
disable-model-invocation: true
---

프로젝트의 스택을 설정하고 하네스를 구성합니다.
**모노레포** (backend + frontend + mobile 공존), **단일 스택**, **코드 없는 마케팅/세일즈 전담 모드** 를 지원합니다.

**선택한 스택:** $ARGUMENTS

---

## Step 1 — 스택 확인

### 1-1. `$ARGUMENTS` 해석

| 값 | 의미 |
|----|------|
| `kotlin` / `kotlin-multi` | Spring Boot 백엔드 (단일 / Gradle 멀티 모듈) |
| `go` / `go-multi` | Go Gin 백엔드 (단일 / Workspace 멀티 서비스) |
| `python` / `python-multi` | Python FastAPI 백엔드 (단일 / uv Workspace) |
| `nextjs` / `nextjs-multi` | Next.js 프론트엔드 (단일 / Turborepo) |
| `flutter` | Flutter 모바일 |
| `monorepo` | backend + frontend + mobile 모노레포 (자동 감지 강제) |
| `infra` | DevOps / IaC 전담 (Terraform · Kubernetes · Helm) — 코드 스택 외 별도 |
| `marketing` | 코드 없는 마케팅 전담 프로젝트 (랜딩 카피 · SEO · 콘텐츠 · 광고 · 이메일) |
| `sales` | 코드 없는 세일즈 전담 프로젝트 (덱 · 콜드메일 · 객관처리 · 가격 · 플레이북) |
| `product` | 코드 없는 Product Management 전담 (Discovery · Strategy · PRD · OKR · GTM · Analytics) |

### 1-2. 자동 감지 (인수 없을 때)

**먼저 모노레포 감지 시도**. 아래 역할 후보 디렉토리들을 **전부** 스캔 (동일 역할 다중 허용):

| 역할 | 허용 디렉토리 이름 패턴 (별칭 + suffix 허용) |
|------|---------------------------------------------|
| backend | `backend`, `api`, `server`, `backend-*`, `api-*`, `server-*` |
| frontend | `frontend`, `web`, `client`, `frontend-*`, `web-*`, `client-*` |
| mobile | `mobile`, `app`, `mobile-*`, `app-*` |

**이름 추출**:
- 기본 이름 (`backend`, `web`, `app` 등) → `name` 필드 생략 (role 이 유일한 경우)
- suffix 패턴 (`backend-auth`, `backend-ml`, `web-admin` 등) → suffix 부분이 `name` (`auth`, `ml`, `admin`)
- 동일 role 이 2개 이상이면 각 스택은 **반드시 `name`** 을 가져야 함 (없으면 사용자에게 수동 지정 요청)

각 디렉토리에서 아래 마커로 스택 타입 판정:

| 마커 (역할 디렉토리 기준) | 스택 타입 |
|---------------------------|-----------|
| `settings.gradle.kts` + `include(` | `kotlin-multi` |
| `build.gradle.kts` / `pom.xml` | `kotlin` |
| `go.work` | `go-multi` |
| `go.mod` | `go` |
| `pyproject.toml` + `[tool.uv.workspace]` | `python-multi` |
| `pyproject.toml` (fastapi 의존성) | `python` |
| `turbo.json` | `nextjs-multi` |
| `package.json` (`next` 의존성) | `nextjs` |
| `pubspec.yaml` | `flutter` |

**모노레포 판정 규칙:**

- **2개 이상** service 디렉토리 (동일 role 포함) 가 각자 유효한 스택 마커를 가지면 → `monorepo` 모드
- **1개** service 만 발견 → 사용자에게 "단일 스택으로 진행할까요, 아니면 단일-service 모노레포로 구성할까요?" 확인
- **0개** 발견 → 루트에서 기존 단일 스택 감지 (아래 표)

**동일 role 다중 감지 예시:**
```
my-project/
├── backend-auth/     (kotlin-multi)  → role=backend, name=auth
├── backend-ml/       (python)         → role=backend, name=ml
├── web/              (nextjs)         → role=frontend, name=web (또는 생략)
└── app/              (flutter)        → role=mobile,  name=app (또는 생략)
```
→ `stacks.json` 에 4개 service 등록, 같은 role 이어도 `name` 으로 구분됨

**이름 중복 금지**: 동일 role 내에서 `name` 이 같은 service 2개 불가. 감지 시 충돌이면 사용자에게 수정 요청.

> ⚠️ **infra/marketing/sales/product 모드는 자동 감지하지 않습니다.** 코드 마커 (`*.tf`, `Chart.yaml`, k8s manifest) 가 있어도 백엔드 프로젝트의 부속 인프라일 수 있으므로 가정하지 않습니다. 사용자에게 **명시 선택**을 요청합니다:
> ```
> 코드 스택이 감지되지 않았습니다. 아래 중 선택하세요:
>   1. infra      — DevOps / IaC 전담 (Terraform · K8s · Helm)
>   2. marketing  — 마케팅 전담 프로젝트 (코드 없음)
>   3. sales      — 세일즈 전담 프로젝트 (코드 없음)
>   4. product    — Product Management 전담 (pm-skills 플러그인 사용)
>   5. 취소 — 스택을 직접 명시 (예: /init kotlin)
> ```

**루트 단일 스택 감지 (폴백):**

| 감지 파일 | 스택 |
|-----------|------|
| `settings.gradle.kts` + `include(` 포함 | `kotlin-multi` |
| `build.gradle.kts` / `pom.xml` | `kotlin` |
| `go.work` | `go-multi` |
| `go.mod` | `go` |
| `pyproject.toml` + `[tool.uv.workspace]` | `python-multi` |
| `pyproject.toml` (`fastapi` 의존성) | `python` |
| `turbo.json` | `nextjs-multi` |
| `package.json` (`next` 의존성) | `nextjs` |
| `pubspec.yaml` | `flutter` |

감지 결과를 사용자에게 확인:
> "backend/ (kotlin-multi) + web/ (nextjs) + app/ (flutter) 모노레포를 감지했습니다. 이대로 진행할까요?"
>
> 또는
>
> "build.gradle.kts 를 감지했습니다. `kotlin` 단일 스택으로 진행할까요?"

감지 불가 시 직접 물어봅니다.

---

## Step 2 — 파일 정리

### 단일 스택 모드 — 유지 대상

| 스택 | 유지 agents | 유지 skills | 유지 templates |
|------|-------------|-------------|----------------|
| `kotlin` / `kotlin-multi` | kotlin-{gen,mod,test}, code-reviewer, **security-reviewer**, api-designer, ui-designer¹, github-actions-designer, **planner** | kotlin-patterns, db-patterns, api-design-patterns, github-actions-patterns, **security-patterns**, **docker-patterns**, **cache-patterns**, **observability-patterns** | AGENTS.kotlin[-multi], settings.kotlin[-multi], **prd**, **role-prompt** |
| `go` / `go-multi` | go-{gen,mod,test}, code-reviewer, **security-reviewer**, api-designer, github-actions-designer, **planner** | go-patterns, db-patterns, api-design-patterns, github-actions-patterns, **security-patterns**, **docker-patterns**, **cache-patterns**, **observability-patterns** | AGENTS.go[-multi], settings.go[-multi], **prd**, **role-prompt** |
| `python` / `python-multi` | python-{gen,mod,test}, **ai-{researcher,gen,mod,test}**, code-reviewer, **security-reviewer**, api-designer, github-actions-designer, **planner** | python-patterns, **ai-patterns**, **ai-eval-patterns**, db-patterns, api-design-patterns, github-actions-patterns, **security-patterns**, **docker-patterns**, **cache-patterns**, **observability-patterns** | AGENTS.python[-multi], settings.python[-multi], **prd**, **role-prompt** |
| `nextjs` / `nextjs-multi` | nextjs-{gen,mod,test}, code-reviewer, **security-reviewer**, ui-designer, github-actions-designer, **planner** | nextjs-patterns, ui-design-impl, github-actions-patterns, **security-patterns**, **docker-patterns**, **cache-patterns**, **observability-patterns** | AGENTS.nextjs[-multi], settings.nextjs[-multi], **prd**, **role-prompt** |
| `flutter` | flutter-{gen,mod,test}, code-reviewer, **security-reviewer**, ui-designer, github-actions-designer, **planner** | flutter-patterns, ui-design-impl, github-actions-patterns, **security-patterns**, **observability-patterns** | AGENTS.flutter, settings.flutter, **prd**, **role-prompt** |
| `infra` | **infra-generator**, code-reviewer, **security-reviewer**, github-actions-designer, **planner** | **terraform-patterns**, **kubernetes-patterns**, **helm-patterns**, github-actions-patterns, **security-patterns**, **docker-patterns**, **observability-patterns** | AGENTS.infra, settings.infra, **prd**, **role-prompt** |
| `marketing` | code-reviewer, **planner**, **gtm-planner** | (없음 — marketing-skills 플러그인 의존) | AGENTS.marketing, settings.marketing, **prd**, **role-prompt**, **marketing-plan**, **gtm-history**, **memory** |
| `sales` | code-reviewer, **planner**, **gtm-planner** | (없음 — marketing-skills 플러그인 의존) | AGENTS.sales, settings.sales, **prd**, **role-prompt**, **sales-plan**, **gtm-history**, **memory** |
| `product` | code-reviewer, **planner**, **gtm-planner** | (없음 — pm-skills 마켓플레이스 + marketing-skills 플러그인 의존) | AGENTS.product, settings.product, **prd**, **role-prompt**, **marketing-plan**, **sales-plan**, **gtm-history**, **memory** |

¹ `ui-designer` 는 백엔드 단독일 땐 제거. 모노레포에서는 frontend/mobile 이 있으면 자동 유지.

> `planner` agent 와 `prd`/`role-prompt` 템플릿은 **모든 스택에서 유지**합니다. `/start` · `/plan` 커맨드가 이들을 사용합니다.
>
> **marketing/sales/product 모드**: 코드 스택 관련 agent (`kotlin-*`, `go-*`, `python-*`, `nextjs-*`, `flutter-*`, `ui-designer`, `api-designer`, `github-actions-designer`) 와 코드 관련 skills (`*-patterns`, `db-patterns`, `api-design-patterns`, `ui-design-impl`, `github-actions-patterns`) · 템플릿 (`AGENTS.{코드스택}.md`, `settings.{코드스택}.json`) 을 **모두 제거**합니다. 작업은 marketing/sales 는 `marketing-skills` 플러그인, product 는 `pm-skills` 마켓플레이스 8개 플러그인(+ `marketing-skills`) 로 처리합니다.
>
> **infra 모드**: 코드 스택 generator/modifier/tester (`kotlin-*`, `go-*`, `python-*`, `nextjs-*`, `flutter-*`, `ai-*`) · `ui-designer` · `api-designer` 및 코드 skills (`kotlin-patterns`, `go-patterns`, `python-patterns`, `nextjs-patterns`, `flutter-patterns`, `ai-patterns`, `ai-eval-patterns`, `db-patterns`, `api-design-patterns`, `ui-design-impl`, `cache-patterns`) · 코드 stack templates 를 제거합니다. **유지**: `infra-generator`, `terraform-patterns`, `kubernetes-patterns`, `helm-patterns`, `docker-patterns`, `github-actions-patterns`, `security-patterns`, `observability-patterns`, `security-reviewer`, `github-actions-designer`.

### 모노레포 모드 — 유지 대상 (유니온)

감지된 스택들의 "유지 대상" **합집합**을 적용:

- **backend (kotlin/kotlin-multi)** 감지 → kotlin-{gen,mod,test}, api-designer, kotlin-patterns, db-patterns, api-design-patterns, **docker-patterns**, **cache-patterns**, AGENTS.kotlin[-multi], settings.kotlin[-multi]
- **backend (go/go-multi)** 감지 → go-{gen,mod,test}, api-designer, go-patterns, db-patterns, api-design-patterns, **docker-patterns**, **cache-patterns**, AGENTS.go[-multi], settings.go[-multi]
- **backend (python/python-multi)** 감지 → python-{gen,mod,test}, **ai-{researcher,gen,mod,test}**, api-designer, python-patterns, **ai-patterns**, **ai-eval-patterns**, db-patterns, api-design-patterns, **docker-patterns**, **cache-patterns**, AGENTS.python[-multi], settings.python[-multi]
- **frontend (nextjs/nextjs-multi)** 감지 → nextjs-{gen,mod,test}, ui-designer, nextjs-patterns, ui-design-impl, **docker-patterns**, **cache-patterns**, AGENTS.nextjs[-multi], settings.nextjs[-multi]
- **mobile (flutter)** 감지 → flutter-{gen,mod,test}, ui-designer, flutter-patterns, ui-design-impl, AGENTS.flutter, settings.flutter
- **공통 유지**: code-reviewer, **security-reviewer**, github-actions-designer, **planner**, github-actions-patterns, **security-patterns**, **observability-patterns**, AGENTS.monorepo.md, settings.monorepo.json, memory.md, **prd.md**, **role-prompt.md**

### 제거 — `init-cleanup.sh` 스크립트 호출 (v1.36.0+)

위 "유지 대상" 표는 **참조용 명세**일 뿐, 실제 제거는 `.claude/scripts/init-cleanup.sh` 가 deterministic 하게 수행:

**Step 2a — 사용자에게 보여줄 dry-run**:
```bash
# 단일 스택 (예: kotlin)
bash .claude/scripts/init-cleanup.sh kotlin

# 모노레포 (감지된 stack 인자 전달)
bash .claude/scripts/init-cleanup.sh monorepo kotlin nextjs flutter
```

dry-run 결과(예상 제거 파일 목록 + 보존 목록) 가 그대로 사용자 확인용. 자연어 추론 안 함.

**Step 2b — 사용자 확인 후 실 제거**:
```bash
bash .claude/scripts/init-cleanup.sh kotlin --apply
```

**보존 (스크립트 강제)**:
- `agents/custom/`, `commands/custom/`, `hooks/custom/`, `skills/custom/`
- `settings.local.json`, `.starter-version*`
- `commands/` 전체 (디스패처는 모든 모드에서 사용)

**제거 대상** (스크립트 자동 계산):
- 위 유지 목록에 없는 `agents/*.md`, `skills/*/SKILL.md`, `templates/*` 파일
- `.github/assets/` 디렉토리 (스타터 대표 이미지)

> **커맨드는 전부 유지**합니다. `/new`, `/plan`, `/review` 는 역할 prefix 로 스택 분기를 내부 처리합니다.

> ⚠️ **자연어 인스트럭션으로 직접 `rm` 실행 금지** — 스크립트 사용. 14 mode 각각 deterministic 보장 + custom/ 보존 + 권한 1회 수락 (`Bash(bash .claude/scripts/*)`).

---

## Step 3 — 하네스 파일 설치

> 🔒 **AGENTS.md ≤ 300줄 캡 (모든 모드 공통)** — 설치/병합한 모든 AGENTS.md 의 줄 수 검사. 초과 시 상세를 `.agents/skills/{topic}/SKILL.md` 또는 `docs/{topic}.md` 로 이관, AGENTS.md 는 인덱스 한 줄. (post-edit-lint.sh 가 자동 가드)

**공통 패턴 — 모든 모드**:
1. **AGENTS.md 설치** — 신규: `cp .claude/templates/AGENTS.{mode}.md ./AGENTS.md` · 기존: "아키텍처 규칙", "MUST", "NEVER" 섹션만 병합 (덮어쓰기 전 사용자 확인). 첫 줄 `[프로젝트명]` 교체.
2. **settings.json 설치** — 신규: `cp .claude/templates/settings.{mode}.json ./.claude/settings.json` · 기존: `hooks` + `permissions` 만 템플릿으로 업데이트, `enabledPlugins` 는 기존 유지.

### 3-A. 단일 스택 모드 — 추가 동작 없음

`.claude/stacks.json` 생성 안 함. `pre-push.sh` 가 루트 감지 폴백.

### 3-B. 모노레포 모드 — `.claude/stacks.json` + 역할별 AGENTS.md

#### 3-B-1. `.claude/stacks.json` 생성 (단일 진실의 원천)

```json
{
  "mode": "monorepo",
  "stacks": [
    { "role": "backend",  "name": "auth", "type": "kotlin-multi", "path": "backend-auth" },
    { "role": "backend",  "name": "ml",   "type": "python",       "path": "backend-ml" },
    { "role": "frontend", "type": "nextjs", "path": "web" },
    { "role": "mobile",   "type": "flutter", "path": "app" }
  ]
}
```

**스키마**:
- `role` — `backend` / `frontend` / `mobile` (표준 이름, 디렉토리 별칭과 무관)
- `name` — **optional** (role 유일 시 생략, 2개 이상이면 필수). 충돌 금지.
- `type` / `path` — 감지된 스택 타입 / 실제 디렉토리

**name 추출**: 기본 별칭(`backend`/`api`/`server`/`frontend`/`web`/`client`/`mobile`/`app`) → 생략 · suffix(`backend-auth`) → suffix 가 name.

**Service 식별자**: `name` 있으면 `role:name` (예: `backend:auth`), 없으면 `role` (예: `frontend`). `/new`, `/start`, `/plan`, `pre-push.sh`, `settings.monorepo.json` hooks 모두 이 파일 참조.

#### 3-B-2. 루트 AGENTS.md — `cp .claude/templates/AGENTS.monorepo.md ./AGENTS.md`
플레이스홀더 (`[프로젝트명]`, `[{role}-path]`, `[{role}-stack]`) 를 stacks.json 값으로 치환. 감지 안 된 역할의 행은 표에서 제거.

#### 3-B-3. 역할별 AGENTS.md — 각 stack 마다 `cp templates/AGENTS.{type}.md ./{path}/AGENTS.md`
첫 줄 `[프로젝트명]` 교체 + 역할명 추가 → `# MyApp / backend — Kotlin Spring Boot`. 기존 파일 있으면 덮어쓰기 전 확인.

#### 3-B-4. 루트 settings.json — `cp templates/settings.monorepo.json ./.claude/settings.json`
**감지된 스택에 없는 도구 권한 제거**:
- kotlin 없음 → `Bash(./gradlew *)`, `Bash(./mvnw *)`
- go 없음 → `Bash(go *)`
- python 없음 → `Bash(uv *)`, `Bash(python *)`, `Bash(pytest *)`, `Bash(ruff *)`, `Bash(mypy *)`, `Bash(alembic *)`, `Bash(uvicorn *)`
- frontend 없음 → `Bash(npm *)`, `Bash(node *)`
- mobile 없음 → `Bash(flutter *)`, `Bash(dart *)`

`enabledPlugins` 도 미사용 plugin (kotlin-lsp 등) 제거. **하위 디렉토리에 별도 `.claude/` 만들지 않음** (루트 1개만 유효).

### 3-C. Marketing / Sales / Product 모드 — 코드 없음

`.claude/stacks.json` 생성 안 함 (코드 빌드/테스트 의미 없음). settings 의 `pre-push.sh` · `post-edit-lint.sh` · `Stop` 훅 없음 (`safety-guard.sh` · `session-start.sh` · `usage-counter.sh` 만).

**필수 plugin 설치 안내** (Step 6 완료 메시지에 자동 포함):

| 모드 | 필수 plugin |
|------|------------|
| marketing / sales | `/plugin install marketing-skills@marketingskills` |
| product | `/plugin marketplace add phuryn/pm-skills` + 8개 `pm-*` (toolkit / product-discovery / product-strategy / execution / go-to-market / market-research / data-analytics / marketing-growth) · 선택적으로 marketing-skills |

### 3-D. Infra 모드 — Terraform/K8s/Helm

`.claude/stacks.json` 생성 안 함. `pre-push.sh` 의 lint 명령은 stack 무관 (terraform fmt 등).

---

### 3-공통. 커버리지 게이트 훅

`.claude/hooks/pre-push.sh` 확인. `bootstrap.sh` 로 설치했으면 이미 존재. 없으면 복사. 훅은 `.claude/stacks.json` 유무로 모드를 자동 감지합니다.

> **marketing/sales 모드 예외**: `settings.{marketing,sales}.json` 에는 `pre-push.sh` 훅이 등록돼 있지 않으므로 이 단계는 **건너뜁니다** (파일만 남아 있어도 실행되지 않음).

### 3-공통. Second Brain 초기화

`/init` 은 새 프로젝트 시작이므로 **기존 memory 가 있어도 항상 초기화**:

```bash
mkdir -p memory
cp .claude/templates/memory.md ./memory/MEMORY.md
```

초기화 후 사용자에게 **한 번에** 질문:

> 1. 이 프로젝트의 목적 또는 배경을 한 줄로 설명해주세요.
> 2. 주요 도메인이나 핵심 기능은 무엇인가요?
> 3. 특별한 제약사항이 있나요? (마감일, 성능 요구사항, 팀 규모)
> 4. 연동할 외부 시스템이나 참고 레퍼런스가 있나요? (없으면 생략)

답변을 받으면 `memory/MEMORY.md` 에 아래 두 항목 기록:

```markdown
## YYYY-MM-DD: 프로젝트 시작

**카테고리:** 결정

- **프로젝트명:** [프로젝트명]
- **모드:** 단일 / 모노레포
- **스택:** [단일: kotlin] 또는 [모노레포: backend(kotlin-multi) + web(nextjs) + app(flutter)]
- **목적:** [질문 1 답변]
- **핵심 기능:** [질문 2 답변]
- **제약사항:** [질문 3 답변]
- **외부 연동:** [질문 4 답변 또는 없음]

---

## YYYY-MM-DD: Claude Code 하네스 구성

**카테고리:** 참고

/init [스택 또는 monorepo] 으로 하네스를 구성했습니다.
- AGENTS.md: 아키텍처 규칙 및 코딩 컨벤션 (모노레포일 경우 루트 인덱스 + 역할별 AGENTS.md)
- .claude/settings.json: 권한 및 훅 설정
- .claude/stacks.json: 스택 매니페스트 (모노레포만)
- memory/MEMORY.md: Second Brain 초기화

앞으로 중요한 결정·교훈은 /memory add 로 기록하세요.
```

---

## Step 4 — .gitignore 초기 설정

```bash
grep -q "\.worktrees/" .gitignore 2>/dev/null || echo ".worktrees/" >> .gitignore
git add .gitignore
git commit -m "chore: .worktrees/ gitignore 추가" 2>/dev/null || true
```

> `.worktrees/` 가 gitignore 에 없으면 worktree 디렉토리가 git 에 추적될 위험이 있습니다.

---

## Step 5 — Git 브랜치 전략 (신규 프로젝트만)

사용자에게 선택 요청 (기본값 A):

> **A. main + dev** (권장)
> ```
> main ← dev ← feature/* / fix/* / hotfix/* / ...
> ```
> - `dev`: 개발 통합 (스테이징), `main`: 프로덕션
> - PR: `feature/*` → `dev`, 릴리즈: `dev` → `main`
>
> **B. main only**
> ```
> main ← feature/* / fix/* / hotfix/* / ...
> ```
> - `main` 하나만, PR: `feature/*` → `main` 바로 머지

### A 선택

```bash
git checkout -b dev
git push -u origin dev
```

GitHub 브랜치 보호 안내:
- **main**: PR 필수 + status checks + restrict push
- **dev**: PR 필수 + status checks

#### 옵션 — Docker 배포 사이클 설치 (main+dev 선택 시만)

사용자에게 질문: "ghcr Docker 이미지 + dev→main 버전 사이클(latest-dev / latest-prd) 을 설치할까요?"
**예** 선택 시:

```bash
mkdir -p .github/workflows .github/scripts
cp .claude/templates/cicd/dev-ci.yml          .github/workflows/dev-ci.yml
cp .claude/templates/cicd/release-promote.yml .github/workflows/release-promote.yml
cp .claude/templates/cicd/next-version.sh     .github/scripts/next-version.sh
chmod +x .github/scripts/next-version.sh
cp .claude/templates/cicd/Dockerfile.example  Dockerfile   # 사용자가 자기 앱에 맞게 수정
```

설치 후 안내: repo Settings → Actions → Workflow permissions = **Read and write** 필요.
사이클·버전 규칙·주의사항 상세는 `.claude/templates/cicd/README.md`.

### B 선택

`dev` 생성하지 않음. `main` 하나만 사용.

GitHub 브랜치 보호 안내:
- **main**: PR 필수 + status checks + restrict push

> ℹ️ `/new worktree` 는 `dev` 존재 여부로 전략을 자동 감지합니다. `dev` 없으면 자동으로 `main` 을 베이스로 사용.

---

## Step 6 — 완료 메시지

**모든 모드 공통 출력**:
```
✅ 프로젝트 하네스 구성 완료
프로젝트: [이름]   모드: [선택 스택]   제거된 파일: N개

[5 기둥]
  1. 컨텍스트:    AGENTS.md ✅              (monorepo: + 역할별 AGENTS.md)
  2. CI/CD 게이트: settings.json hooks ✅    (코드 모드만 lint/test, marketing/sales/product 는 safety+session)
  3. 도구 경계:   settings.json permissions ✅
  4. 피드백 루프: /rule ✅
  5. 팀 지식:    memory/MEMORY.md ✅
[Git] main+dev 또는 main only · .worktrees/ gitignore 등록 · monorepo: .claude/stacks.json 매니페스트

이제 할 일 (공통):
  1. AGENTS.md 커스터마이징
  2. /start <기능>             # worktree + PRD + 자동 구현 (모노레포는 병렬)
  3. /plan <기능>              # 설계만, --light 가벼운 변경, --gtm 전략 문서
  4. AI 실수 시 /rule, 중요 결정은 /memory add
```

**모드별 추가 안내 (필요 시만 출력)**:

| 모드 | 추가 출력 |
|------|----------|
| 단일 코드 스택 | `/new <Resource>` 스캐폴딩 · 멀티 모듈은 `/new module <name>` |
| 모노레포 | `/new {backend\|frontend\|mobile} <sub> <Name>` 역할 prefix · `/plan {role} <기능>` · `git push` 시 활성 스택 모두 커버리지 |
| `marketing` / `sales` | ⚠️ `/plugin install marketing-skills@marketingskills` 필요 · `/marketing context` 권장 · `/marketing <카테고리>` 작업 |
| `product` | ⚠️ `/plugin marketplace add phuryn/pm-skills` + 8개 `pm-*` 설치 필요 · `/discover`/`/strategy`/`/write-prd`/`/plan-okrs`/`/plan-launch`/`/north-star` 사용 |
| `infra` | `/start` 로 Terraform/K8s/Helm 작업 · `terraform plan` / `kubectl --dry-run=server` / `helm lint` 검증
