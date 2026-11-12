<div align="center">

# Coding Agent Starter

**새 프로젝트에 Claude Code 하네스를 10초 만에 구성하는 설정 모음**

[**🇰🇷 한국어**](README.md) · [**🇬🇧 English**](README.en.md)

<br/>

[![Claude](https://img.shields.io/badge/Claude-Code-FF6B35?logo=anthropic&logoColor=white)](https://claude.ai/code)
[![Version](https://img.shields.io/badge/version-1.41.0-blue)](CHANGELOG.md)
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

Claude Code를 프로젝트에서 바로 활용할 수 있도록 **커맨드, 에이전트, 템플릿**을 미리 세팅한 스타터입니다.

- `/init` 한 번으로 스택에 맞는 하네스 구성 (스택 자동 감지)
- 스택별 전문 subagent로 생성·수정·테스트 역할 분리
- **디스패처 커맨드** — `/new`, `/plan`, `/review` 세 개로 모든 생성·계획·리뷰 작업 통합
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

**지원 스택:** Kotlin Spring Boot · Next.js · Flutter · Go Gin · Python FastAPI

> **v1.6.0 Breaking Change** — 커맨드 16개 → 11개로 재편. [마이그레이션 가이드](#v160-마이그레이션) 참고.

---

## 빠른 시작

### 1. `.claude` 폴더 설치 (신규 프로젝트 / 기존 프로젝트 공통)

**방법 A — 부트스트랩 스크립트 (권장)**

```bash
curl -fsSL https://raw.githubusercontent.com/nogamsung/coding-agent-starter/main/bootstrap.sh | bash
```

- `.claude/` 폴더가 **없으면** install 모드 — 새로 설치
- `.claude/` 폴더가 **있으면** update 모드 — **사용자 custom 자산은 기본 보존** (v1.19.0+)

**옵션 (curl | bash 에 인자 전달):**

```bash
# 특정 버전으로 핀
curl -fsSL ...bootstrap.sh | bash -s -- --version v1.18.0

# custom 자산까지 모두 갈아엎기 (이전 동작)
curl -fsSL ...bootstrap.sh | bash -s -- --no-preserve
```

**보존 디렉토리 규약** — update 시 다음은 자동 보존:
```
.claude/agents/custom/      .claude/commands/custom/
.claude/hooks/custom/       .claude/skills/custom/
.claude/settings.local.json
```
> ⚠️ 사용자가 직접 만든 agent/command/hook 은 **반드시** `custom/` 하위에 두세요. 루트 직속에 두면 update 시 사라집니다. `memory/` 폴더는 어떤 경우에도 영향 없습니다.

**방법 B — 수동 복사**

```bash
git clone --depth=1 https://github.com/nogamsung/coding-agent-starter.git
rm -rf /path/to/your-project/.claude
cp -r coding-agent-starter/.claude /path/to/your-project/
rm -rf coding-agent-starter
```

**방법 C — Plugin marketplace** (실험적, v1.28.0+)

```
/plugin marketplace add nogamsung/coding-agent-starter
/plugin install coding-agent-starter@coding-agent-starter
```

> ⚠️ **한계**: plugin 경로는 `commands` · `agents` · `skills` 만 install 합니다. `hooks` · `templates` · `settings.json` · `memory/` 는 plugin 시스템이 다루지 않으므로 **bootstrap.sh 가 여전히 권장 entry point** 입니다. plugin 경로는 일부 자산만 가벼이 사용하고 싶을 때.

**방법 D — Claude Code 안에서 업데이트·롤백** (이미 설치된 프로젝트)

```
/starter check                      # 현재·최신·이전 버전 표시
/starter update                     # 전체 갱신 (custom 자산 보존)
/starter update --version v1.18.0   # 특정 태그로 핀
/starter rollback                   # 직전 버전으로 되돌리기

/upgrade                            # 카테고리별 변경 통계 표시 (dry-run)
/upgrade apply skills,hooks         # 일부 카테고리만 선택 갱신
/upgrade --version v1.18.0          # 특정 버전 기준 비교

/release patch                      # VERSION + CHANGELOG bump + commit + /pr 자동
/release minor --dry-run            # 미리보기
```

> `/starter` 는 all-or-nothing 갱신, `/upgrade` 는 `agents`/`commands`/`skills`/`templates`/`hooks`/`settings` 카테고리 단위 부분 갱신. 둘 다 `custom/` + `settings.local.json` 보존. `/release` 는 maintainer 가 본인 프로젝트(또는 스타터 자체) 의 새 버전 릴리스 시 사용.

### 2. Claude Code에서 스택 초기화

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
2. 선택 스택과 무관한 agent/template/skill 제거 (커맨드는 전부 유지 — 디스패처가 분기)
3. `AGENTS.md` 설치 — 아키텍처 규칙, 컨벤션
4. `.claude/settings.json` 설치 — 스택별 허용 명령어 + 자동 lint/test 훅
5. `memory/MEMORY.md` 초기화 — 프로젝트 정보 인터뷰 후 기록
6. `dev` 브랜치 생성 + `.worktrees/` gitignore 등록

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
여러 터미널 / Claude Code 인스턴스에서 **병렬 작업** 가능.

> ⚠️ **Git 브랜치 네이밍 제약**: `dev`와 `dev/feature-*` 는 refs 구조상 공존 불가. 피처 브랜치는 `dev/` 대신 `feature/`, `fix/` 등 독립 prefix를 사용합니다.

---

## 커맨드 (14개)

> v1.18.0 — `/planner` 가 `/plan` 으로 흡수되고, 새 단일 진입점 `/start` 가 추가되었습니다.

### 디스패처 (서브명령)

| 커맨드 | 인자 | 설명 |
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

### 단일 커맨드

| 커맨드 | 설명 |
|--------|------|
| `/init [stack]` | 스택 감지 및 하네스 구성 |
| `/test [파일]` | 테스트 코드 자동 생성 |
| `/commit [힌트]` | Conventional Commits 커밋 + `/pr` 자동 제안 (피처 브랜치) |
| `/pr` | PR 생성 + `/merge` 자동 제안 |
| `/merge [auto]` | GitHub 머지 실행 + main 최신화 + 버전 태그 + worktree 정리 |
| `/rule <설명>` | AI 실수를 AGENTS.md 규칙으로 등록 |
| `/memory [add\|search]` | Second Brain 기억 추가·검색 (전체 조회는 자동 로드) |
| `/marketing [category task\|자연어]` | 마케팅 작업 라우터 — 35개 `marketing-skills:*` 스킬을 6개 카테고리로 분기 |
| `/starter [check\|update]` | 스타터 버전 확인 / 재설치 |
| `/harness [check\|doctor\|dry-run\|size\|lint-settings]` | 하네스(settings.json, hooks, agents) 검증·dry-run·자동 수정 제안 |

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

### 공통 (전 스택)

| 플러그인 | 설명 |
|---------|------|
| `github` | GitHub 레포 · PR · 이슈 관리 |
| `context7` | 최신 공식 문서 컨텍스트 자동 주입 |
| `feature-dev` | 탐색→설계→구현→리뷰 7단계 체계적 개발 |
| `code-review` | 병렬 4-agent PR 자동 리뷰 |
| `security-guidance` | 위험 명령어 실행 전 보안 경고 |
| `hookify` | 반복 실수를 자동 방지 훅으로 등록 |
| `commit-commands` | 커밋·푸시·PR 생성 원스텝 |

### 스택별 추가

| 플러그인 | 스택 | 설명 |
|---------|------|------|
| `kotlin-lsp` | Kotlin | 타입 오류 · 심볼 참조 실시간 지원 |
| `typescript-lsp` | Next.js | TypeScript 코드 인텔리전스 |
| `frontend-design` | Next.js | UI 패턴 · 접근성 가이드 |
| `playwright` | Next.js | E2E 브라우저 테스트 자동화 |

---

## 자동 훅

`/init` 후 설치되는 `settings.json`에는 스택별 자동 검사 훅이 포함됩니다.

| 이벤트 | Kotlin | Next.js | Flutter | Go | Python |
|--------|--------|---------|---------|-----|--------|
| 파일 저장 후 | `ktlint` | `eslint` | `dart analyze` | `go vet` | `ruff check` |
| 작업 완료 전 | `gradlew test` | `tsc` + `jest` | `flutter test` | `go test ./...` | `ruff` + `mypy` |
| **git push 전** | **Jacoco ≥ 90%** | **Jest ≥ 90%** | **Flutter ≥ 90%** | **Go ≥ 90%** | **pytest-cov ≥ 90%** |

---

## v1.6.0 마이그레이션

v1.6.0은 커맨드 16개를 10개로 통합했습니다. 기존 커맨드 이름은 **더 이상 작동하지 않습니다**. `/starter update` 로 재설치하거나 `bootstrap.sh` 를 다시 실행하세요.

### 구 → 신 매핑

| 이전 커맨드 (v1.5.x) | 새 커맨드 (v1.6.0) |
|----------------------|---------------------|
| `/new-api <Resource>` | `/new api <Resource>` |
| `/new-component <Name>` | `/new component <Name>` |
| `/new-screen <Name>` | `/new screen <Name>` |
| `/new-module <Name>` | `/new module <Name>` |
| `/new-workflow <Purpose>` | `/new workflow <Purpose>` |
| `/new-feature <type-name>` | `/new worktree <type-name>` |
| `/new-feature pr` | `/pr` + `/merge` (PR 생성과 머지 정리가 분리됨) |
| `/design-api <Resource>` | `/plan api <Resource>` |
| `/design-db <도메인>` | `/plan db <도메인>` |
| `/review-api [대상]` | `/review api [대상]` |
| `/improve <설명>` | `/rule <설명>` |

### 유지되는 커맨드

`/init`, `/plan`, `/test`, `/commit`, `/memory`, `/review [파일\|staged\|diff]` 는 이름 변경 없음.

### 신규 커맨드

- `/starter [check\|update]` — 스타터 버전 확인·재설치
- `/pr` — 현재 브랜치에서 PR 생성 + `/merge` 자동 제안 (구 `/new-feature pr` 분리)
- `/merge [auto]` — GitHub 머지 실행 + main 최신화 + 태그 + worktree 정리 (구 `/pr cleanup` 에서 승격)

---

## 디렉토리 구조

```
coding-agent-starter/
├── .github/
│   └── assets/               # README 이미지 (init 시 삭제)
├── .claude/
│   ├── agents/               # 전문 subagent 정의
│   │   ├── code-reviewer.md
│   │   ├── ui-designer.md
│   │   ├── api-designer.md
│   │   ├── planner.md        # 기획자 (PRD + 역할 프롬프트)
│   │   ├── gtm-planner.md    # GTM 전담 (marketing.md + sales.md + 스냅샷)
│   │   ├── security-reviewer.md # OWASP + 시크릿 + CVE 리뷰 (/pr 자동 호출)
│   │   ├── github-actions-designer.md
│   │   ├── kotlin-{generator,modifier,tester}.md
│   │   ├── nextjs-{generator,modifier,tester}.md
│   │   ├── flutter-{generator,modifier,tester}.md
│   │   ├── go-{generator,modifier,tester}.md
│   │   └── python-{generator,modifier,tester}.md
│   ├── commands/             # 슬래시 커맨드 (14개)
│   │   ├── init.md           # 스택 초기화 + 모노레포 자동 감지
│   │   ├── start.md          # 신규 기능 단일 진입점 (worktree + PRD + 자동 구현)
│   │   ├── new.md            # 디스패처: api/component/screen/module/workflow/worktree (+ 역할 prefix)
│   │   ├── plan.md           # 디스패처: 기획(PRD+프롬프트) / --light / api / db (+ 역할 prefix)
│   │   ├── review.md         # 범용 + api 모드
│   │   ├── test.md           # 테스트 생성
│   │   ├── commit.md         # Conventional Commits + /pr 자동 제안
│   │   ├── pr.md             # PR 생성 + /merge 자동 제안
│   │   ├── merge.md          # GitHub 머지 + 태그 + worktree 정리
│   │   ├── rule.md           # 규칙 등록 (구 improve)
│   │   ├── memory.md         # Second Brain (add/search)
│   │   ├── marketing.md      # marketing-skills 플러그인 라우터 (6 카테고리 · 자연어)
│   │   ├── harness.md        # 하네스 검증·dry-run·자동 수정 제안
│   │   └── starter.md        # 스타터 설치·업데이트
│   ├── skills/               # 코드 패턴 참조 (agents가 읽음)
│   │   ├── kotlin-patterns.md
│   │   ├── go-patterns.md
│   │   ├── python-patterns.md
│   │   ├── nextjs-patterns.md
│   │   ├── flutter-patterns.md
│   │   ├── api-design-patterns.md
│   │   ├── db-patterns.md
│   │   ├── github-actions-patterns.md
│   │   ├── ui-design-impl.md
│   │   ├── security-patterns.md    # OWASP Top 10 + 스택별 pitfall
│   │   ├── docker-patterns.md      # 스택별 멀티스테이지 Dockerfile + compose
│   │   └── cache-patterns.md       # Redis 패턴 (cache/rate-limit/lock/session)
│   ├── templates/            # 스택별 설치 템플릿
│   │   ├── AGENTS.{kotlin,go,python,nextjs,flutter}.md
│   │   ├── AGENTS.{kotlin,go,python,nextjs}-multi.md
│   │   ├── AGENTS.monorepo.md      # 루트 인덱스 (모노레포 모드)
│   │   ├── settings.{kotlin,go,python,nextjs,flutter}.json
│   │   ├── settings.{kotlin,go,python,nextjs}-multi.json
│   │   ├── settings.monorepo.json  # 병합 settings (경로 가드 hooks)
│   │   ├── prd.md                  # PRD 템플릿 (/start, /plan 용)
│   │   ├── role-prompt.md          # 역할별 구현 프롬프트 템플릿
│   │   ├── marketing-plan.md       # 마케팅 전략 템플릿 (/plan --marketing|--gtm)
│   │   ├── sales-plan.md           # 세일즈 전략 템플릿 (/plan --sales|--gtm)
│   │   ├── gtm-history.md          # docs/gtm/history.md 초기 템플릿
│   │   └── memory.md
│   ├── .starter-version      # 설치된 스타터 버전 (팀 공유)
│   └── hooks/
│       ├── session-start.sh     # 세션 시작 — git/stack 요약 주입
│       ├── safety-guard.sh      # PreToolUse — main 등 보호 브랜치의 위험 명령 차단
│       ├── post-edit-lint.sh    # PostToolUse — 파일 확장자 기반 즉시 lint
│       └── pre-push.sh          # 커버리지 게이트 (활성 스택 전체)
├── memory/
│   └── MEMORY.md             # 이 레포의 Second Brain
├── docs/                     # 기능 스펙 + GTM (필요 시 자동 생성)
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
└── VERSION                   # 1.11.0
```
