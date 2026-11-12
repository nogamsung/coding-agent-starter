<div align="center">

# Coding Agent Starter

**Claude Code · Codex 하네스를 10초 만에 구성하는 설정 모음 — 둘 다 써도, 하나만 써도**

[**🇰🇷 한국어**](README.md) · [**🇬🇧 English**](README.en.md)

<br/>

[![Claude](https://img.shields.io/badge/Claude-Code-FF6B35?logo=anthropic&logoColor=white)](https://claude.ai/code)
[![Codex](https://img.shields.io/badge/OpenAI-Codex-412991?logo=openai&logoColor=white)](https://developers.openai.com/codex)
[![Version](https://img.shields.io/badge/version-2.0.1-blue)](CHANGELOG.md)
[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)

<br/>

![Kotlin](https://img.shields.io/badge/Kotlin-Spring_Boot-7F52FF?logo=kotlin&logoColor=white)
![Next.js](https://img.shields.io/badge/Next.js-000000?logo=next.js&logoColor=white)
![Flutter](https://img.shields.io/badge/Flutter-02569B?logo=flutter&logoColor=white)
![Go](https://img.shields.io/badge/Go-Gin-00ADD8?logo=go&logoColor=white)
![Python](https://img.shields.io/badge/Python-FastAPI-009688?logo=fastapi&logoColor=white)

</div>

---

## 개요

코딩 에이전트(Claude Code · Codex)를 프로젝트에서 바로 활용할 수 있도록 **skill, 에이전트, 훅, 템플릿**을 미리 세팅한 스타터입니다. (구 `claude-code-starter`)

<p align="center"><picture><source media="(prefers-color-scheme: dark)" srcset="docs/assets/architecture-ko-dark.svg"><img src="docs/assets/architecture-ko-light.svg" alt="규칙 한 벌을 Claude Code 와 Codex 가 함께 읽는 구조" width="880"></picture></p>

- **Claude Code · Codex 공용** — 지침 `AGENTS.md` 하나, skill `.agents/skills/` 한 벌, 훅 `.claude/hooks/` 한 벌을 두 에이전트가 같이 쓴다. `--platform claude|codex|both` 로 설치
- **에이전트 무관 게이트** — git 훅(`.claude/githooks`)이 빌드 → 테스트 → 커버리지 push 게이트 · gitleaks 시크릿 스캔 · 허브 소스 커밋 차단을 Claude·Codex·터미널 어디서든 강제. CI 가 같은 판정 스크립트로 재검증
- **worktree 강제 · 안전 가드** — 메인 체크아웃은 허브 전용(소스 편집 차단), dev/main 삭제·force push 차단, 끝난 작업 브랜치 삭제는 무확인
- **교차 리뷰** — `/pr` 이 반대 플랫폼 모델(Claude 작업은 Codex, Codex 작업은 Claude)로 리뷰. `/handoff` 로 에이전트 간 작업 인계
- `/init` 한 번으로 스택에 맞는 하네스 구성 (스택 자동 감지)
- 스택별 전문 subagent로 생성·수정·테스트 역할 분리
- **디스패처 skill** — `/new`, `/plan`, `/review` 세 개로 모든 생성·계획·리뷰 작업 통합 (Codex 는 `$new` 처럼 호출)
- AI가 실수할 때마다 `/rule` 로 규칙을 누적해 점점 정교해지는 피드백 루프
- `memory/MEMORY.md` 세션 시작 시 자동 로드 — 과거 결정·교훈이 항상 컨텍스트에 포함
- **Git Worktree 기반 병렬 작업** — `/new worktree` 로 여러 기능 동시 개발
- **멀티 모듈 지원** — Gradle 멀티 모듈 / Turborepo / Go Workspace
- **DB 설계 자동화** — `/plan db` 로 MySQL 스키마 → Flyway/golang-migrate SQL
- **API 설계 자동화** — `/plan api` 로 REST API 설계 → OpenAPI 3.0 YAML → 코드 생성
- **모노레포 모드** — `backend/` + `frontend/` + `mobile/` 공존 자동 감지 → 역할별 AGENTS.md + 경로 가드 hooks
- **`/start` 단일 진입점** — 신규 기능 한 번에: worktree + PRD + 역할별 프롬프트 + 자동 구현. 단일 스택은 무확인, 모노레포는 1회만 확인
- **기획자 에이전트** — `/plan` (또는 `/start`) 가 요청 → PRD + 역할별 구현 프롬프트 자동 생성. Agent Teams 로 병렬 구현도 옵션
- **`/commit` → `/pr` → `/merge` 자동 체인** — 각 단계에서 다음 단계를 제안(수락 시 연결 실행). 완전 자동이 아닌 "연속 확인" 체인

**지원 스택:** Kotlin Spring Boot · Next.js · Flutter · Go Gin · Python FastAPI (+ AI/ML) · Infra (Terraform·Kubernetes·Helm)
**코드 없는 모드:** Marketing · Sales · Product

> **v2.0.0 Breaking Change** — `CLAUDE.md` → `AGENTS.md`, 커맨드 → `.agents/skills/`. [v2 마이그레이션 가이드](#v2-마이그레이션-v1x--v200) 참고.

---

## 빠른 시작

### 1. `.claude` 폴더 설치 (신규 프로젝트 / 기존 프로젝트 공통)

**방법 A — 부트스트랩 스크립트 (권장)**

```bash
curl -fsSL https://raw.githubusercontent.com/nogamsung/coding-agent-starter/main/bootstrap.sh | bash
```

- 하네스가 **없으면** install 모드, **있으면** update 모드 — 사용자 자산은 기본 보존
- 플랫폼은 설치된 CLI 로 자동 감지 (`claude` 만 → claude, `codex` 만 → codex, 둘 다/없음 → both) · 이후 update 는 기록된 값 유지

**옵션 (curl | bash 에 인자 전달):**

```bash
curl -fsSL ...bootstrap.sh | bash -s -- --platform codex      # claude | codex | both
curl -fsSL ...bootstrap.sh | bash -s -- --version v2.0.0      # 특정 버전으로 핀
curl -fsSL ...bootstrap.sh | bash -s -- --no-preserve         # 사용자 자산까지 전체 교체
```

| 플랫폼 | 설치 |
|--------|------|
| 공통 | `.agents/skills/` (skill 원본) · `.claude/{agents,hooks,githooks,scripts,templates}` |
| `claude` | `.claude/settings.json` · `.claude/skills → ../.agents/skills` |
| `codex` | `.codex/{config.toml,hooks.json,rules/,agents/}` (agents 는 `.claude/agents` 에서 생성) |

**보존 규약** — update 시 자동 보존:
```
.agents/skills/<내 skill>/        # 스타터가 배포하지 않는 이름
.claude/{agents,hooks}/custom/   .claude/commands/custom/ (v1 레거시)
.claude/settings.local.json       .codex/config.toml      .codex/rules/<내 규칙>
memory/  AGENTS.md                # 절대 건드리지 않음
```
> ⚠️ 스타터 skill 을 직접 고치면 update 때 교체됩니다 — 다른 이름으로 복사해 쓰세요.

**방법 B — Plugin marketplace** (Claude 전용, 실험적)

```
/plugin marketplace add nogamsung/coding-agent-starter
/plugin install coding-agent-starter@coding-agent-starter
```

> ⚠️ plugin 경로는 skill·agent 만 다룹니다. 훅·템플릿·settings·Codex 설정은 **bootstrap.sh** 로.

**방법 C — 에이전트 안에서 업데이트·롤백** (이미 설치된 프로젝트)

```
/starter check                      # 현재·최신·이전 버전 + 플랫폼
/starter update                     # 전체 갱신 (사용자 자산 보존)
/starter update --platform both     # Codex 추가 (플랫폼 전환)
/starter rollback                   # 직전 버전으로 되돌리기

/upgrade                            # 카테고리별 변경 통계 (dry-run)
/upgrade apply skills,hooks         # 일부 카테고리만 선택 갱신
/upgrade optional archify           # 선택 skill 설치 (optional-skills.json)
```

> Codex 에서는 `/starter` 대신 `$starter` 또는 "스타터 업데이트해줘" 처럼 부릅니다 (모든 skill 동일).

### 2. 스택 초기화 (Claude Code 또는 Codex)

```
/init                # 자동 감지
/init kotlin         # Kotlin Spring Boot (단일 모듈)
/init kotlin-multi   # Kotlin (Gradle 멀티 모듈: api/domain/infra)
/init nextjs         # Next.js (단일 앱)
/init nextjs-multi   # Next.js (Turborepo: apps/web + packages/ui,lib,config)
/init flutter        # Flutter 모바일
/init go             # Go Gin (단일 서비스)
/init go-multi       # Go (Workspace: services/api,worker + pkg/shared)
/init python         # Python FastAPI (단일 서비스)
/init python-multi   # Python (uv Workspace: services/api,worker + packages/shared)
/init infra          # DevOps / IaC 전담 (Terraform · Kubernetes · Helm)
/init marketing      # 코드 없는 마케팅 전담 (랜딩 카피·SEO·콘텐츠·광고)
/init sales          # 코드 없는 세일즈 전담 (덱·콜드메일·객관처리·가격)
/init product        # 코드 없는 Product Management 전담 (Discovery·Strategy·PRD·OKR·GTM·Analytics)
```

> **marketing / sales** 모드는 `marketing-skills@marketingskills` 플러그인을 사용합니다. 미설치 상태면 `/plugin install marketing-skills@marketingskills` 를 실행하세요.
>
> **product** 모드는 `phuryn/pm-skills` 마켓플레이스 8개 플러그인(pm-toolkit, pm-product-discovery, pm-product-strategy, pm-execution, pm-go-to-market, pm-market-research, pm-data-analytics, pm-marketing-growth) 을 사용합니다. 미설치 상태면 `/plugin marketplace add phuryn/pm-skills` → 각 `/plugin install pm-*@pm-skills` 실행.

<details>
<summary><code>/init</code>이 하는 일</summary>

1. 스택 자동 감지 (인수 생략 시)
2. 선택 스택과 무관한 agent·template·패턴 skill 제거 (워크플로 skill 은 전부 유지 — 디스패처가 분기)
3. `CLAUDE.md` 가 있으면 `AGENTS.md` 로 이전 제안 (남아 있으면 Claude Code 가 AGENTS.md 를 무시)
4. `AGENTS.md` 설치 — 아키텍처 규칙, 컨벤션 (Claude·Codex 공통)
5. `.claude/settings.json` 설치 (플랫폼 `claude`·`both`) — 스택별 허용 명령어 + 훅. Codex 는 `.codex/` 가 같은 훅·규칙을 사용
6. `.claude/stacks.json` 생성 (모든 모드) — 훅의 기준 파일 + `harness` 옵션
7. git 훅 설정 (코드 모드, 사용자 확인 후) — `core.hooksPath=.claude/githooks`
8. `memory/MEMORY.md` 초기화 — 프로젝트 정보 인터뷰 후 기록
9. `dev` 브랜치 생성 + `.worktrees/` gitignore 등록

</details>

### 3. 기능 개발 시작

```bash
# 권장 — 단일 진입점 (worktree + PRD + 자동 구현 한 번에)
/start 로그인 기능              # worktree(feature/login) + PRD + 역할 프롬프트 + 자동 generator
/start 결제 취소 --gtm          # + 마케팅·세일즈 GTM 문서

/pr                            # 작업 완료 후 PR 생성 (→ /merge 자동 제안)
/merge                         # GitHub 머지 + main 최신화 + 태그 + worktree 정리

# 또는 단계별로 — 더 세밀한 제어
/new feature-login             # worktree만 생성
/plan 로그인 기능               # PRD + 역할 프롬프트만 (실행 없음)
/plan 로그인 기능 --teams       # PRD 후 즉시 generator 실행
/new User                      # 개별 리소스 스캐폴딩 (스택 자동 감지)
```

---

## 워크플로

<p align="center"><picture><source media="(prefers-color-scheme: dark)" srcset="docs/assets/workflow-ko-dark.svg"><img src="docs/assets/workflow-ko-light.svg" alt="기능 하나의 흐름: /start → /commit → /pr → CI → /merge → 정리" width="880"></picture></p>

```
/start <기능 설명>             # 1. 신규 기능 한 번에: worktree + PRD + 자동 구현
/commit                        # 2. 커밋 → 피처 브랜치면 /pr 자동 제안
/pr                            # 3. (제안 수락) PR 생성 → /merge 자동 제안
/merge                         # 4. (제안 수락) 머지 실행 + 태그 + 정리

# 더 세밀한 제어가 필요한 경우:
/new feature-login             # worktree만 생성
/plan <기능>                   # PRD + 역할별 프롬프트 (실행 없음)
/plan <기능> --teams           # PRD 후 generator 실행
/plan <기능> --light           # 가벼운 단일 변경 계획
/plan api Order                # API 설계 (OpenAPI 3.0 YAML)
/plan db "..."                 # DB 설계 (Migration SQL)
/new User                      # 개별 리소스 스캐폴딩 (스택 자동 감지)
/test <파일>                   # 테스트 자동 생성
/review staged                 # 독립 리뷰
/rule <실수 설명>              # AI 실수를 AGENTS.md 규칙 등록
/memory add <내용>             # 결정·교훈 수동 기록 (조회는 자동 로드됨)
```

---

## 브랜치 전략

```
main  ←──── dev  ←──── feature/{name}
(배포)      (통합)      fix/{name}
                        hotfix/{name}
                        refactor/{name}
                        chore/{name}
```

각 브랜치는 `.worktrees/{type}-{name}/` 에 격리된 작업공간으로 생성됩니다.
타입: `feature` · `fix` · `hotfix` · `refactor` · `chore` · `docs` · `test` · `perf`
여러 터미널 / Claude Code·Codex 세션에서 **병렬 작업** 가능.

> ⚠️ **Git 브랜치 네이밍 제약**: `dev`와 `dev/feature-*` 는 refs 구조상 공존 불가. 피처 브랜치는 `dev/` 대신 `feature/`, `fix/` 등 독립 prefix를 사용합니다.

---

## Skill (워크플로 17개 + 패턴 20개)

> v2.0.0 — 구 커맨드(`.claude/commands/*.md`)가 `.agents/skills/<name>/SKILL.md` 로 이전됐습니다. Claude 는 `/name`, Codex 는 `$name` 으로 부릅니다.
> 부작용이 큰 skill(`init`·`rule`·`release`·`upgrade`·`starter`·`merge`·`handoff`)은 명시적으로 불렀을 때만 실행됩니다.

### 디스패처 (서브명령)

| skill | 인자 | 설명 |
|--------|------|------|
| `/new` | `<Name>` | **자동 감지** — 스택(go/kotlin→api, nextjs→component, flutter→screen) 또는 이름 패턴(`feature-*`→worktree, `ci\|release\|publish`→workflow)으로 분기 |
| | `<sub> <Name>` (override) | `api` / `component` / `screen` / `module` / `workflow` / `worktree` 명시 지정 |
| | `<role> <sub> <Name>` (모노레포) | 역할 prefix — `backend` / `frontend` / `mobile` 로 대상 스택 경로 지정 |
| `/start` | `<기능>` | **신규 기능 단일 진입점** — worktree + PRD + 역할 프롬프트 + 자동 구현 |
| | `<기능> --no-worktree` | 이미 worktree 안일 때 |
| | `<기능> --output-only` | 파일만 생성, 자동 실행 없음 |
| | `<기능> --marketing\|--sales\|--gtm` | + GTM 문서 |
| `/plan` | `<기능>` | PRD + 역할별 구현 프롬프트 (실행 없음) |
| | `<기능> --teams` | PRD 후 즉시 generator 병렬 실행 |
| | `<기능> --light` | 가벼운 단일 변경 계획 (PRD 없이) |
| | `api <Resource>` | REST API 설계 → OpenAPI 3.0 YAML |
| | `db <도메인>` | MySQL 스키마 → Migration SQL |
| | `<기능> --marketing\|--sales\|--gtm` | + GTM 문서 |
| | `<role> ...` (모노레포) | 역할 prefix — `/plan backend api User`, `/plan backend db order` |
| `/review` | (없음) / `<파일>` / `staged` / `diff` | 범용 코드 리뷰 |
| | `api` | REST 컨벤션·보안·OpenAPI 리뷰 |

### 단일 skill

| skill | 설명 |
|--------|------|
| `/init [stack]` | 스택 감지 및 하네스 구성 |
| `/test [파일]` | 테스트 코드 자동 생성 |
| `/commit [힌트]` | Conventional Commits 커밋 + `/pr` 자동 제안 (피처 브랜치) |
| `/pr` | PR 생성 + `/merge` 자동 제안 |
| `/merge [auto]` | GitHub 머지 실행 + main 최신화 + 버전 태그 + worktree 정리 |
| `/rule <설명>` | AI 실수를 AGENTS.md 규칙으로 등록 |
| `/memory [add\|search]` | Second Brain 기억 추가·검색 (전체 조회는 자동 로드) |
| `/marketing [category task\|자연어]` | 마케팅 작업 라우터 — 35개 `marketing-skills:*` 스킬을 6개 카테고리로 분기 |
| `/starter [check\|update\|rollback]` | 스타터 버전 확인 / 전체 갱신 / 롤백 (`--platform` 으로 플랫폼 전환) |
| `/upgrade [diff\|apply <카테고리>\|optional <name>]` | 최신 스타터와 카테고리별 비교·선택 갱신, 선택 skill 설치 |
| `/harness [check\|doctor\|dry-run\|size\|lint-settings]` | 하네스(settings·.codex·hooks·agents·skills) 검증·dry-run·자동 수정 제안 |
| `/handoff [clear]` | 다른 에이전트(Claude↔Codex)·새 세션에 넘길 인계 메모 — 다음 세션 시작 시 자동 표시 |
| `/release [patch\|minor\|major]` | VERSION + CHANGELOG bump + commit (+ /pr) |

### 패턴 skill (on-demand 참고서)

에이전트가 해당 작업을 할 때 스스로 읽습니다. `/init` 이 스택에 맞는 것만 남깁니다.

- **스택**: `kotlin-patterns` · `go-patterns` · `python-patterns` · `nextjs-patterns` · `flutter-patterns` · `ai-patterns` · `ai-eval-patterns`
- **설계·인프라**: `api-design-patterns` · `db-patterns` · `cache-patterns` · `docker-patterns` · `github-actions-patterns` · `terraform-patterns` · `kubernetes-patterns` · `helm-patterns`
- **횡단**: `security-patterns` · `observability-patterns` · `ui-design-impl` · `motion-patterns` · `mcp-presets`

---

## Agents

| Agent | 역할 |
|-------|------|
| `code-reviewer` | 정확성 · 보안 · 성능 · 유지보수성 리뷰 (전 스택) |
| `ui-designer` | DESIGN.md 기반 디자인 시스템 (Next.js: Tailwind 토큰, Flutter: ThemeData) |
| `github-actions-designer` | CI/CD · 릴리스 · Docker 배포 워크플로 설계 |
| `kotlin-{generator\|modifier\|tester}` | Kotlin Spring Boot 코드 생성·수정·테스트 |
| `nextjs-{generator\|modifier\|tester}` | Next.js 코드 생성·수정·테스트 |
| `flutter-{generator\|modifier\|tester}` | Flutter 코드 생성·수정·테스트 |
| `go-{generator\|modifier\|tester}` | Go Gin 코드 생성·수정·테스트 |
| `python-{generator\|modifier\|tester}` | Python FastAPI 코드 생성·수정·테스트 |
| `ai-{researcher\|generator\|modifier\|tester}` | AI/ML — 리서치 · 코드 생성 · 튜닝 · 테스트 (Python 전용) |
| `infra-generator` | Terraform / Kubernetes / Helm 생성 (단일 agent — modifier/tester 분리 없음) |
| `api-designer` | REST API 설계 전문 (OpenAPI 3.0 YAML) — Kotlin · Go · Python 전용 |
| `planner` | 기획자 — 요청 → PRD + 역할별 구현 프롬프트 작성 (코드는 작성하지 않음). `/start` 또는 `/plan` 이 호출 |
| `gtm-planner` | Go-To-Market 전담 — PRD 기반으로 `marketing.md` + `sales.md` 초안, `docs/gtm/` 스냅샷 · 히스토리 적립. `/start` 또는 `/plan --marketing\|--sales\|--gtm` 플래그가 호출 |
| `security-reviewer` | OWASP Top 10 + 시크릿 유출 + 의존성 CVE 검토 전담. `/pr` Step 1.5 에서 자동 호출 → Critical 발견 시 PR 차단 |

---

## 스택별 기술 표준

| 항목 | Kotlin Spring Boot | Go Gin | Python FastAPI | Next.js | Flutter |
|------|-------------------|--------|----------------|---------|---------|
| ORM / 쿼리 | JPA + **QueryDSL** | GORM + **sqlc** | **SQLAlchemy 2.0 (async)** | — | — |
| Migration | Flyway | golang-migrate | **Alembic** | — | — |
| API 문서 | **SpringDoc OpenAPI** | **swaggo/swag** | **FastAPI 내장 OpenAPI** | — | — |
| Lint / Format | ktlint | **golangci-lint** | **ruff** | ESLint | dart analyze |
| Type Check | kotlinc | `go vet` | **mypy (strict)** | tsc | — |
| Package Manager | Gradle | Go modules | **uv** | npm | pub |
| Docker 배포 | ✅ GHCR | ✅ GHCR | ✅ GHCR | ✅ GHCR | ❌ |

---

## 플러그인 (스택별 자동 설치)

`/init` 이 `.claude/settings.json` 의 `enabledPlugins` 로 켭니다 (Claude 전용). 스택별 최소 필수만 넣습니다.

### 공통

| 플러그인 | 대상 | 설명 |
|---------|------|------|
| `github` | 전 모드 | GitHub 레포 · PR · 이슈 관리 |
| `commit-commands` | 전 모드 | 커밋·푸시·PR 생성 원스텝 |
| `hookify` | 전 모드 | 반복 실수를 자동 방지 훅으로 등록 |
| `feature-dev` | 코드 스택 · infra | 탐색→설계→구현→리뷰 단계별 개발 |

### 스택·모드별 추가

| 플러그인 | 스택·모드 | 설명 |
|---------|------|------|
| `kotlin-lsp` | Kotlin | 타입 오류 · 심볼 참조 실시간 지원 |
| `typescript-lsp` | Next.js | TypeScript 코드 인텔리전스 |
| `frontend-design` | Next.js | UI 패턴 · 접근성 가이드 |
| `playwright` | Next.js | E2E 브라우저 테스트 자동화 |
| `marketing-skills` | Marketing · Sales · Product | 카피·SEO·CRO·광고·세일즈 skill 모음 |
| `pm-*` (8개) | Product | Discovery · Strategy · Execution · GTM · Analytics 등 PM skill |

> 모노레포는 역할에 해당하는 스택 플러그인을 합칩니다. `CLAUDE.md` 를 만드는 `claude-md-management` 플러그인은 쓰지 않습니다 (CI 로 차단).

---

## 자동 훅

<p align="center"><picture><source media="(prefers-color-scheme: dark)" srcset="docs/assets/hooks-ko-dark.svg"><img src="docs/assets/hooks-ko-light.svg" alt="한 턴 동안 훅이 도는 시점" width="880"></picture></p>


훅 스크립트는 `.claude/hooks/` 한 벌 — Claude 는 `settings.json`, Codex 는 `.codex/hooks.json` 이 부릅니다. 모든 훅은 `.claude/stacks.json` 이 없으면 조용히 끝나고, 옵션은 `stacks.json` 의 `harness` 블록으로 켜고 끕니다.

| 훅 | 이벤트 | 동작 | 옵션 (기본) |
|----|--------|------|------|
| `session-start.sh` | 세션 시작 | git·스택 요약 · 인계 메모(`/handoff`) 표시 | — |
| `safety-guard.sh` | Bash 전 | force push·dev/main 삭제·`rm -rf /`·DROP 차단, 끝난 작업 브랜치 삭제는 무확인 허용 | 항상 |
| `worktree-guard.sh` | 편집 전 | 메인 체크아웃(허브)에서 소스 편집 차단 → worktree 안내 | `worktreeGuard` (true) |
| `post-edit-lint.sh` | 편집 후 | 확장자별 즉시 lint · AGENTS.md 300줄 캡 | — |
| `stop-tests.sh` | 턴 종료 (Claude) | 바뀐 스택만 테스트 · 변경 없으면 건너뜀 · 막지 않음 | `stopTests` (true) |
| `pre-push.sh` + `build-gate.sh` | git push | 빌드 → 변경 범위 테스트 → 커버리지 (`coverage-gate.py`, CI 와 같은 판정) | `buildGate` (true) · `coverage` (90) |
| `memory-sync.sh` | 세션 시작·종료 | 저장소 `memory/` 를 원본으로 링크·커밋 (여러 PC·worktree·에이전트 공유) | `memorySync` (off) |
| `model-router.sh` | subagent 호출 | 작업 난이도로 모델 티어 선택 (TypeSafe 키 필요) | `modelRouter` (off) |
| `usage-counter.sh` | 도구 사용 후 (Claude) | 도구 이름별 사용 횟수를 로컬 `.claude/.usage.json` 에만 집계 (외부 전송 없음) | `telemetry` (off) |
| `codex-adapter.sh` | Codex 전용 | `apply_patch` 를 파일별 Claude 형식 입력으로 바꿔 위 훅에 전달 | — |

**git 훅** (`bash .claude/scripts/setup-git-hooks.sh` → `core.hooksPath=.claude/githooks`): `pre-commit` = Codex agent 동기화 검사 · gitleaks · 허브 소스 커밋 차단, `pre-push` = 위 push 게이트. 에이전트 밖 터미널에서도 동작합니다.

<p align="center"><picture><source media="(prefers-color-scheme: dark)" srcset="docs/assets/push-gate-ko-dark.svg"><img src="docs/assets/push-gate-ko-light.svg" alt="push 게이트: 빌드 → 테스트 → 커버리지" width="880"></picture></p>


**수동 도구**: `dev-smoke.sh smoke|up|down` (변경 스택 실제 기동·헬스체크) · `timing.sh` (단계별 소요 시간 기록) · `cross-review.sh` (교차 리뷰).

| 스택 | 편집 후 lint | 턴 종료 테스트 | push 커버리지 |
|------|-------------|---------------|--------------|
| Kotlin | `ktlint` | `gradlew test` | JaCoCo ≥ 90% |
| Next.js | `eslint` | `tsc` + `jest` | Jest ≥ 90% |
| Flutter | `dart analyze` | `flutter test` | lcov ≥ 90% |
| Go | `go vet` | `go vet` + `go test` | cover ≥ 90% |
| Python | `ruff check` | `ruff` + `mypy` (+ pytest) | coverage.py ≥ 90% |

---

## v2 마이그레이션 (v1.x → v2.0.0)

```bash
curl -fsSL https://raw.githubusercontent.com/nogamsung/coding-agent-starter/main/bootstrap.sh | bash   # 또는 /starter update
bash .claude/scripts/migrate-agents-md.sh --apply    # CLAUDE.md → AGENTS.md (루트·역할별)
/init                                                # .claude/stacks.json 생성 (v2 훅은 이게 있어야 동작)
```

| v1 | v2 |
|----|----|
| `CLAUDE.md` · `templates/CLAUDE.{stack}.md` | `AGENTS.md` · `templates/AGENTS.{stack}.md` — CLAUDE.md 가 남아 있으면 Claude Code 가 AGENTS.md 를 무시 |
| `.claude/commands/*.md` | `.agents/skills/<name>/SKILL.md` (호출 이름 동일: `/commit`, `/pr`, …) |
| `.claude/skills/*.md` | `.agents/skills/<name>/SKILL.md` · `.claude/skills` 는 심볼릭 링크 |
| `.claude/skills/custom/*.md` | update 시 `.agents/skills/<name>/SKILL.md` 로 자동 이전 |
| 단일 스택은 stacks.json 없음 | 모든 모드에 `.claude/stacks.json` (+ `harness` 옵션) |
| 스택별 인라인 Stop 명령 | `stop-tests.sh` (변경 범위만) |

> Claude Code ≥ 2.1.277 이 AGENTS.md 를 읽습니다. 더 오래된 버전이면 CLAUDE.md 에 `@AGENTS.md` 한 줄만 두는 방법도 있지만 권장하지 않습니다.

---

## 디렉토리 구조

```
coding-agent-starter/
├── AGENTS.md                 # 이 저장소 지침 (Claude·Codex 공통)
├── .agents/skills/           # skill 원본 — <name>/SKILL.md
│   ├── init/ start/ new/ plan/ review/ test/ commit/ pr/ merge/ release/
│   ├── rule/ memory/ marketing/ harness/ starter/ upgrade/ handoff/
│   └── {kotlin,go,python,nextjs,flutter,ai,…}-patterns/ ui-design-impl/ motion-patterns/ mcp-presets/
├── .claude/
│   ├── agents/               # subagent 원본 (스택별 generator/modifier/tester + 공통)
│   ├── skills -> ../.agents/skills
│   ├── hooks/                # 공용 훅 (lib.sh · safety/worktree guard · pre-push · build-gate · stop-tests · memory-sync · …)
│   ├── githooks/             # pre-commit · pre-push (core.hooksPath)
│   ├── scripts/              # init-cleanup · gen-codex-agents · coverage-gate · cross-review · setup-git-hooks · migrate-agents-md · tests/
│   ├── templates/            # AGENTS.{stack}.md · settings.{stack}.json · cicd/ · gitleaks.toml · optional-skills.json · prd/role-prompt/memory
│   └── .starter-{version,platform,skills}   # 설치 메타 (팀 공유)
├── .codex/                   # config.toml · hooks.json · rules/default.rules · agents/*.toml (생성물)
├── memory/
│   └── MEMORY.md             # 이 레포의 Second Brain
├── docs/                     # 기능 스펙 + GTM (필요 시 자동 생성)
│   ├── assets/                       # (스타터 저장소 전용) README 애니메이션 SVG — gen-diagrams.py 생성물, 배포 안 됨
│   ├── specs/
│   │   ├── {feature}.md               # PRD
│   │   └── {feature}/
│   │       ├── {role}.md              # 역할별 구현 프롬프트 (backend/frontend/mobile)
│   │       ├── marketing.md           # 살아있는 마케팅 전략 (/plan --marketing|--gtm)
│   │       └── sales.md               # 살아있는 세일즈 전략 (/plan --sales|--gtm)
│   └── gtm/
│       ├── history.md                 # 날짜/버전 인덱스
│       └── {YYYY-MM-DD}-{feature}/    # 스냅샷 (릴리스 시 freeze)
│           ├── marketing.md
│           ├── sales.md
│           └── meta.yaml              # feature/status/released_version
├── bootstrap.sh              # 설치·업데이트 스크립트
├── CHANGELOG.md
└── VERSION
```
