---
name: new
description: 리소스/파일/작업공간 생성 — 이름과 스택으로 자동 감지. 서브명령(api/component/screen/module/workflow/worktree)은 override용.
argument-hint: "<Name> (자동 감지) 또는 <sub> <Name> [옵션] (명시 지정)"
---

대상 종류를 **자동 감지**하여 생성 작업을 수행합니다. 감지가 애매하면 사용자에게 확인 후 진행.

**인수:** $ARGUMENTS

---

## 서브명령 결정 (역할 prefix → 자동 감지 → override 순서)

### Step 0 — 모노레포 service prefix 체크

`.claude/stacks.json` 이 존재하고 `mode: "monorepo"` 이면, 첫 토큰이 service 식별자면 **그 service 디렉토리로 cd 해서 실행**합니다.

**Service 식별자 문법:**

| 첫 토큰 | 의미 |
|---------|------|
| `backend` / `frontend` / `mobile` (role) | 해당 role 의 service 경로 — 동일 role 이 1개면 바로 선택, 2개 이상이면 interactive 프롬프트 |
| `backend:auth` / `backend:ml` (role:name) | role + name 명시 선택 |
| `auth` / `ml` (name only) | `name` 이 프로젝트 전체에서 유일하면 허용 (단축) |

**Service 해석 로직:**

```bash
TOKEN="$1"

# 1. role:name 형식 먼저 매칭
if [[ "$TOKEN" == *:* ]]; then
  ROLE="${TOKEN%%:*}"
  NAME="${TOKEN##*:}"
  MATCH=$(jq -r ".stacks[] | select(.role==\"$ROLE\" and (.name // \"\")==\"$NAME\")" .claude/stacks.json)
fi

# 2. role 단독 매칭 (동일 role 이 1개면 자동 선택)
if [ -z "$MATCH" ] && [[ "$TOKEN" =~ ^(backend|frontend|mobile)$ ]]; then
  COUNT=$(jq "[.stacks[] | select(.role==\"$TOKEN\")] | length" .claude/stacks.json)
  if [ "$COUNT" = "1" ]; then
    MATCH=$(jq ".stacks[] | select(.role==\"$TOKEN\")" .claude/stacks.json)
  elif [ "$COUNT" -gt 1 ]; then
    # Interactive 프롬프트
    NAMES=$(jq -r ".stacks[] | select(.role==\"$TOKEN\") | .name" .claude/stacks.json | paste -sd" / " -)
    echo "⚠️  $TOKEN 이 여러 개입니다. 어느 것? ($NAMES)"
    # 사용자 선택 받은 후 name 매칭으로 진행
  fi
fi

# 3. name 단독 매칭 (유일할 때만)
if [ -z "$MATCH" ]; then
  COUNT=$(jq "[.stacks[] | select((.name // \"\")==\"$TOKEN\")] | length" .claude/stacks.json)
  if [ "$COUNT" = "1" ]; then
    MATCH=$(jq ".stacks[] | select((.name // \"\")==\"$TOKEN\")" .claude/stacks.json)
  fi
fi

STACK_PATH=$(echo "$MATCH" | jq -r '.path')
cd "$STACK_PATH"
```

prefix 를 소비하고 나머지 인자로 Step 1 부터 진행 (예: `/new backend:auth api User` → `api User` 재평가).

**prefix 없이 호출되고 모노레포이면**:
- service 가 **1개면** 자동 선택
- **2개 이상**이면 사용자에게 확인:
  > "어느 service 에서 실행할까요? (backend:auth / backend:ml / frontend)"

단일 스택 모드(`.claude/stacks.json` 없음)에서는 Step 0 을 건너뜁니다.

### Step 1 — 명시 서브명령 우선 체크

첫 토큰이 아래 목록에 있으면 그 서브명령을 그대로 사용 (override):

| 명시 토큰 | 서브 |
|----------|------|
| `api` | REST API 스캐폴딩 |
| `component` | Next.js React 컴포넌트 |
| `screen` | Flutter 화면 |
| `module` | 멀티 모듈 서브모듈 |
| `workflow` | GitHub Actions |
| `worktree` | git worktree |
| `dockerfile` | Dockerfile + docker-compose + .dockerignore |

### Step 2 — 인수 패턴 기반 자동 감지

명시 토큰이 아니면 아래 순서로 패턴 매칭:

| 패턴 | 감지 서브 | 예시 |
|------|---------|------|
| 첫 토큰이 `feature-`·`fix-`·`hotfix-`·`refactor-`·`chore-`·`docs-`·`test-`·`perf-` 중 하나로 시작 | **worktree** | `/new feature-login` |
| 첫 토큰이 `ci`·`release`·`publish`·`scheduled` 중 하나 | **workflow** | `/new publish kotlin` |
| 위 둘 다 아니면 | → Step 3 (스택 기반) | |

### Step 3 — 스택 기반 기본값

프로젝트 루트 파일로 스택을 감지해 기본 서브를 결정:

| 감지 파일 | 기본 서브 | 이름 해석 |
|-----------|----------|----------|
| `go.mod` 또는 `build.gradle.kts` / `pom.xml` | **api** | PascalCase → 리소스명 |
| `pyproject.toml` (`fastapi` 의존성) | **api** | PascalCase → 리소스명 |
| `package.json` (`next` 의존성) | **component** | PascalCase → 컴포넌트명 |
| `pubspec.yaml` | **screen** | PascalCase → 화면명 |

### Step 4 — 멀티 모듈 모호성 해소

프로젝트가 멀티 모듈(`settings.gradle.kts include(` / `go.work` / `pyproject.toml` + `[tool.uv.workspace]` / `turbo.json`)이고, 이름이 **소문자 단일 단어**(예: `notification`, `payment`)이면 사용자에게 확인:

> "`<name>` 을 멀티 모듈 서브모듈로 생성할까요? 아니면 API 리소스로 생성할까요? (module / api)"

### Step 5 — 감지 결과 확인 (첫 토큰이 명시 서브가 아닐 때만)

자동 감지된 결과를 사용자에게 한 줄로 보여주고 곧바로 진행:

```
→ Go 프로젝트 감지 · /new api User 로 해석합니다.
```

사용자가 다른 것을 원하면 명시 서브명령으로 다시 호출하도록 안내.

---

## 사용 예시

```
# 단일 스택 — 자동 감지 (권장)
/new User                     # Kotlin/Go → api / Next.js → component / Flutter → screen
/new UserCard --feature       # Next.js → component (--feature 플래그)
/new feature-login            # worktree (type prefix 인식)
/new fix-signup               # worktree
/new publish kotlin           # workflow (publish 키워드 인식)
/new ci nextjs                # workflow

# 단일 스택 — 명시 지정 (override)
/new api User                 # 자동 감지가 틀릴 때 강제 지정
/new module notification      # 멀티 모듈에서 소문자 이름을 모듈로 강제
/new workflow ci              # workflow 명시
/new dockerfile               # 현재 스택에 맞춰 Dockerfile + compose 생성

# 모노레포 — 역할 prefix 로 대상 스택 명시
/new backend api User            # backend 경로에서 api 스캐폴딩
/new frontend component Button   # frontend 경로에서 컴포넌트
/new mobile screen Login         # mobile 경로에서 Flutter 화면
/new backend module notification # backend 멀티 모듈 서브모듈 추가
/new backend User                # 역할 명시 후 자동 감지 (backend → api)

# 모노레포 공용 (역할 불필요)
/new feature-login               # worktree — 루트에서 실행
/new workflow ci                 # workflow — 루트에서 실행
```

---

## `api` — REST API 스캐폴딩

> 💡 DB 스키마부터면 `/plan db <도메인>` 먼저 → Migration 생성 후 이 커맨드.

**리소스명**: 두 번째 토큰 (없으면 사용자에게 물어보세요)

### 스택 자동 감지

| 감지 파일 | 스택 | Generator agent | 상세 패턴 |
|-----------|------|----------------|----------|
| `go.mod` | Go Gin | `go-generator` | `.agents/skills/go-patterns/SKILL.md` |
| `settings.gradle.kts` / `build.gradle.kts` / `pom.xml` | Spring Boot | `kotlin-generator` | `.agents/skills/kotlin-patterns/SKILL.md` |
| `pyproject.toml` (`fastapi`) | Python FastAPI | `python-generator` | `.agents/skills/python-patterns/SKILL.md` |
| 위 파일 없음 | — | 사용자에게 스택 선택 요청 | — |

**워크플로**: stack-generator agent 호출 → agent 가 patterns.md 읽고 stack 별 파일 생성. 각 generator agent 의 본문에 핵심 규칙 명시되어 있음 (constructor injection, transactional boundary, async/await 등).

### 스택별 핵심 생성 파일

| 스택 | 핵심 7~9 파일 | 필수 어노테이션 / 패턴 |
|------|--------------|---------------------|
| **Go Gin** | `internal/{domain,repository,usecase,handler}/{resource}*.go` + `db/query/{resource}.sql` (sqlc) + `migrations/{N}_create_{resources}_table.{up,down}.sql` + 3 테스트 | swag godoc (`@Summary` `@Tags` `@Router` `@Success` `@Failure`) · `domain/` 외부 import 금지 · sqlc 강제 (raw SQL 금지) |
| **Spring Boot** | Entity (`domain/`) + Repository QueryDSL 3세트 (`infrastructure/`) + 3 DTOs (`presentation/dto/`) + Service (`application/`) + Controller (`presentation/`) + 2 테스트 | `@Entity` + `@CreationTimestamp` · QueryDSL `*Repository` + `*RepositoryCustom` + `*RepositoryImpl` 3세트 · SpringDoc `@Tag`/`@Operation`/`@Schema` 필수 · 멀티 모듈은 `:domain`/`:infra`/`:api` 분리 |
| **Python FastAPI** | Model (`models/`) + Schemas (`schemas/`) + Repository (`repositories/`) + Service (`services/`) + Router (`routers/`) + DI deps (`core/deps.py`) + Alembic + 3 테스트 | SQLAlchemy 2.0 (`Mapped[T]` + `mapped_column`) · Pydantic v2 (`@field_validator`, `ConfigDict`) · 모든 함수 `async def` · `services/` 에 `HTTPException` import 금지 (커스텀 예외 → router 변환) · `alembic revision --autogenerate` 후 수동 검토 |

**모노레포/멀티 감지**:
- Go: `go.work` → 멀티 서비스, 어느 서비스 물어봄. 공유는 `pkg/shared/`
- Kotlin: `settings.gradle.kts` 의 `include(` → 멀티 모듈
- Python: `[tool.uv.workspace]` → 멀티, 어느 service. 공유는 `packages/shared/`

**생성 후 안내**:
- Go: `mockery --name={Resource}Repository --dir=internal/domain --output=mocks` · `sqlc generate` · `swag init -g cmd/main.go -o docs`
- Spring: 기존 `GlobalExceptionHandler` 패턴 따라 예외 던지기 안내
- Python: `uv run alembic revision --autogenerate -m "..."` → 검토 → `upgrade head` · `uv run ruff check . && uv run mypy .`

> **상세 코드 패턴** (Entity 작성법, Service transactional, Router decorators 등) 은 모두 stack-generator agent 본문 + `.agents/skills/{stack}-patterns/SKILL.md` 에 정의. 이 커맨드는 agent 디스패치만.

---

## `component` — Next.js 컴포넌트

**인수 파싱**: `<Name> [--page | --feature | --ui]` (기본 `--feature`)
- `--page`: `app/` 페이지 컴포넌트
- `--feature`: `components/features/` 피처 컴포넌트 (기본)
- `--ui`: `components/ui/` 재사용 UI 컴포넌트

**파일 구조**:

```
# --ui
components/ui/{component-name}/
├── {component-name}.tsx
├── {component-name}.test.tsx
└── index.ts

# --feature
components/features/{feature}/
├── {component-name}.tsx
├── use-{component-name}.ts     # 필요시
└── {component-name}.test.tsx

# --page
app/{route}/
├── page.tsx                    # Server Component
├── loading.tsx
└── error.tsx
```

**생성 규칙**: Props 타입 명시 / Named export (default 금지) / Server Component 기본, 인터랙티비티 시에만 `"use client"` / Tailwind / 시맨틱 HTML + aria / 로딩·에러 상태.

**선택 규칙**: API 연동 → TanStack Query / 폼 → React Hook Form + Zod / 전역 상태 → Zustand.

생성 후 파일 목록과 사용법 예시를 보여주세요.

---

## `screen` — Flutter 화면

**인수**: `<ScreenName>` (없으면 사용자에게 물어보세요)

현재 프로젝트 구조(Riverpod vs Bloc)를 파악한 후 생성.

**Feature 구조 (Clean Architecture)**:

```
lib/features/{feature_name}/
├── data/
│   ├── datasources/{feature_name}_remote_data_source.dart
│   └── repositories/{feature_name}_repository_impl.dart
├── domain/
│   ├── entities/{entity_name}.dart           # freezed
│   ├── repositories/{feature_name}_repository.dart
│   └── usecases/get_{feature_name}.dart
└── presentation/
    ├── screens/{screen_name}_screen.dart
    ├── widgets/
    └── providers/{screen_name}_provider.dart
```

**파일 규칙**:
- **Screen**: `ConsumerStatefulWidget`/`ConsumerWidget`, `Scaffold`, 로딩/에러/빈 상태 처리
- **Provider (Riverpod)**: `@riverpod`, `AsyncNotifier`/`Notifier`, `Either<Failure, T>`
- **Entity**: `@freezed`, `fromJson`/`toJson` (`json_serializable`)
- **GoRouter 등록**: 현재 `app_router.dart`에 새 라우트 등록, path constant 별도 정의

**포함 판단**: API 연동→Dio RemoteDataSource / 로컬 저장→Hive·SharedPreferences / 폼→`TextEditingController`+validation / 목록→`ListView.builder` pagination.

**주의사항**: `const` 생성자 최대 활용, `dispose()`에서 Controller 정리, `.g.dart`/`.freezed.dart`는 직접 생성 금지 (`build_runner` 안내), 생성 후 `flutter pub run build_runner build` 안내.

---

## `module` — 멀티 모듈 서브모듈 추가

**인수**: `<moduleName>` (없으면 사용자에게 물어보세요)

### 타입 자동 감지 + 등록 위치

| 감지 조건 | 타입 | 디렉토리 패턴 | 매니페스트 등록 |
|----------|------|--------------|---------------|
| `settings.gradle.kts` + `include(` | Kotlin 멀티 모듈 | `{moduleName}/{build.gradle.kts, src/main/kotlin/, src/main/resources/, src/test/kotlin/}` | `settings.gradle.kts` 의 `include(...)` |
| `turbo.json` | Next.js Turborepo | `apps/` (독립 배포) 또는 `packages/` (공유) — 사용자에게 물어봄 | 루트 `package.json` workspaces (이미 `apps/*` `packages/*` 등록됐으면 자동) |
| `go.work` | Go Workspace | `services/{moduleName}/{go.mod, cmd/main.go, internal/{domain,usecase,repository,handler,middleware}/, migrations/, db/{query,sqlc}/, mocks/, testutil/}` | `go.work` 의 `use ./services/{moduleName}` + `go work sync` |
| `pyproject.toml` + `[tool.uv.workspace]` | Python uv Workspace | `services/` (FastAPI 서비스) 또는 `packages/` (공유 라이브러리) — 사용자에게 물어봄 | 루트 `pyproject.toml` 의 `[tool.uv.workspace].members` + (packages 일 때) `[tool.uv.sources]` + `uv sync` |

### Kotlin 핵심 규칙
- `build.gradle.kts` 의존성: 순수 로직 → `:domain`, 외부 연동 → `:domain` + 외부 lib, API → `:domain` + `:infra`
- 패키지 (`com.{company}.{project}`) 는 기존 모듈 참고
- 사용 시: `implementation(project(":{moduleName}"))` + `./gradlew :{moduleName}:build`

### Next.js Turborepo 핵심
- **apps/** 구조: `apps/{moduleName}/{package.json, tsconfig.json, src/{app,components,hooks,lib,stores,types}/}`
- **packages/** 구조: `packages/{moduleName}/{package.json, tsconfig.json, src/index.ts}`
- `package.json` 표준: `name: "@project/{moduleName}"`, `exports: { ".": "./src/index.ts" }`, `scripts: { lint, test, build }`, `devDependencies: { "@project/config": "*" }`
- 사용 시: 다른 모듈의 `dependencies` 에 `"@project/{moduleName}": "*"` + `npm install` · 빌드 `turbo run build --filter=@project/{moduleName}`

### Go Workspace 핵심
- `go.mod`: `module github.com/{org}/{project}/services/{moduleName}` + `require github.com/{org}/{project}/pkg/shared v0.0.0`
- `cmd/main.go`: log + DI 조립 골격
- 공유 도메인은 `pkg/shared/`, lint 는 각 서비스 디렉토리 (`golangci-lint run ./...`, workspace root 미지원)

### Python uv Workspace 핵심
- **services/** 구조: `app/{main.py, core/, db/, models/, schemas/, repositories/, services/, routers/, exceptions.py}` + `alembic/` + `tests/`
- **packages/** 구조: `src/{moduleName}/__init__.py` + `pyproject.toml` 에 `[build-system] requires = ["hatchling"]` + `[tool.hatch.build.targets.wheel].packages`
- 사용 시: 다른 멤버의 `dependencies` 에 `"{moduleName}"` 추가 → `uv sync` · 실행 `uv run --directory services/{moduleName} ...`

---

## `workflow` — GitHub Actions

**인수**: `[ci | release | publish | scheduled] [스택명]` (예: `ci nextjs`, `publish kotlin`)

### Step 1 — 컨텍스트 파악
- `AGENTS.md`, `package.json` / `build.gradle.kts` / `go.mod` / `pubspec.yaml` → 스택 특정
- `.github/workflows/` 기존 파일 → 중복·충돌 방지

### Step 2 — 패턴 참고
- `.agents/skills/github-actions-patterns/SKILL.md` 읽기
- 스택 + 목적에 맞는 템플릿 선택

### Step 3 — 생성

| 목적 | 파일명 |
|------|--------|
| CI (빌드·테스트·린트) | `.github/workflows/ci.yml` |
| 릴리스·버전 태깅 | `.github/workflows/release.yml` |
| Docker 이미지 배포 (GHCR) | `.github/workflows/publish.yml` |
| 정기 실행 | `.github/workflows/scheduled.yml` |

**publish 추가 동작**: `Dockerfile` 없으면 스택별 멀티스테이지 Dockerfile 먼저 생성 (Kotlin: JDK builder→JRE runtime / Go: golang builder→alpine 정적 바이너리 / Next.js: deps→builder→runner, `next.config.js`에 `output: 'standalone'` 안내). Flutter는 Docker 배포 미지원 — 안내 후 종료.

### Step 4 — 완료 출력
1. 필요한 **GitHub Secrets** 목록
2. 필요한 **GitHub Environments** 목록 (있으면)
3. 외부 설정 안내 (npm token, OIDC role 등)

**주의사항**: `secrets.*` 하드코딩 금지 / `uses:` action 버전 고정 (`@v4` 이상) / 스택별 캐시 설정 필수 / 릴리스는 `push: tags: ['v*.*.*']` 트리거.

---

## `dockerfile` — Dockerfile + docker-compose 생성

**인수**: `[--compose | --no-compose]` (기본: `--compose`)

### Step 1 — 스택 감지

루트(또는 역할 prefix 로 cd 한 경로)의 마커로 스택을 결정:

| 감지 파일 | 스택 | 베이스 이미지 |
|-----------|------|----------------|
| `pyproject.toml` (`fastapi` 의존성) | Python FastAPI | `python:3.12-slim` builder → `python:3.12-slim` runtime (non-root) |
| `build.gradle.kts` / `pom.xml` | Kotlin Spring Boot | `eclipse-temurin:21-jdk` builder → `eclipse-temurin:21-jre-alpine` runtime |
| `go.mod` | Go Gin | `golang:1.22-alpine` builder → `gcr.io/distroless/static-debian12` runtime |
| `package.json` (`next` 의존성) | Next.js | `node:20-alpine` deps → builder → runner. `next.config.js` 에 `output: 'standalone'` 필요 |
| `pubspec.yaml` | Flutter | **미지원** — 안내 후 종료 (CI 빌드용으로만 사용) |

### Step 2 — 패턴 참고

`.agents/skills/docker-patterns/SKILL.md` 읽기 — 스택별 멀티스테이지 템플릿, .dockerignore, HEALTHCHECK, non-root user 설정 포함.

### Step 3 — 생성 파일

| 파일 | 목적 |
|------|------|
| `Dockerfile` | 멀티스테이지 빌드, non-root user, HEALTHCHECK |
| `.dockerignore` | `.git`, `node_modules`, `.venv`, `target`, `build`, `.env*`, `tests/` 등 |
| `docker-compose.yml` (옵션) | 로컬 개발용 — app + Postgres + Redis |

`--no-compose` 시 `docker-compose.yml` 생성 생략.

### Step 4 — 기존 파일 처리

- `Dockerfile` 이미 있으면 덮어쓰기 전 사용자 확인
- `.dockerignore` 이미 있으면 병합 제안
- `docker-compose.yml` 이미 있으면 섹션 추가 제안

### Step 5 — 완료 출력

```
✅ Dockerfile + docker-compose.yml 생성 완료

빌드: docker build -t {project}:local .
실행: docker compose up
이미지 크기: {estimated size}
```

**주의사항**:
- **시크릿 노출 금지**: `ENV API_KEY=...` 절대 금지. `docker run --env-file`, `docker secret`, 또는 런타임 주입
- **non-root user 필수**: `RUN useradd -m app && USER app` 마지막에
- **HEALTHCHECK 필수**: 스택별 엔드포인트 (FastAPI `/health`, Spring `/actuator/health` 등)
- **Multi-arch 빌드**: 프로덕션 배포 시 `docker buildx build --platform linux/amd64,linux/arm64`
- Next.js 는 반드시 `output: 'standalone'` — 안 하면 이미지가 500MB+
- Go 는 distroless 권장 — 공격면 최소화

---

## `worktree` — git worktree 생성

**인수**: `<타입-이름>` (예: `feature-login`, `fix-signup`)

> PR 생성은 별도 커맨드 `/pr` 을 사용하세요.

> ⚠️ **브랜치 네이밍 제약**
> Git은 `dev`와 `dev/feature-*` 를 동시에 유지할 수 없습니다 (refs 충돌).
> 피처 브랜치는 `dev/` 대신 `feature/`, `fix/` 등 독립 prefix 사용.
> - 통합 브랜치: `dev`
> - 피처 브랜치: `feature/{name}`, `fix/{name}`, `hotfix/{name}` 등

### 베이스 브랜치 규칙 (필수)

> 🔒 **이 규칙은 모든 프로젝트·모든 호출에 예외 없이 적용됩니다.**
> 새 브랜치는 **항상 `origin` 의 최신 상태에서** 분기합니다. 로컬 브랜치 상태(stale 여부)는 무시.

```
원격 dev 존재  → base = origin/dev   (fetch 후 거기서 분기)
원격 dev 없음  → base = origin/main  (fetch 후 거기서 분기)
```

`/pr` 의 PR base 규칙과 완벽히 일관 — 시작(분기)과 끝(PR target)이 같은 기준.

### Step 1 — .worktrees/ 안전 확인

```bash
git check-ignore -q .worktrees 2>/dev/null
```

등록 안 되어 있으면:
```bash
echo ".worktrees/" >> .gitignore
git add .gitignore
git commit -m "chore: .worktrees/ gitignore 추가"
```

### Step 2 — 베이스 ref 결정 (origin 최신 기준)

```bash
# 1. origin 최신화 — 오프라인 실패해도 진행
git fetch origin --quiet 2>/dev/null || true

# 2. 원격 dev 존재 여부로 base ref 결정
if git ls-remote --heads origin dev 2>/dev/null | grep -q refs/heads/dev; then
  BASE_REF="origin/dev"
  BASE_LABEL="dev"
elif git show-ref --verify --quiet refs/remotes/origin/dev; then
  # fetch 전에 캐시된 remote-tracking 으로 폴백
  BASE_REF="origin/dev"
  BASE_LABEL="dev"
else
  BASE_REF="origin/main"
  BASE_LABEL="main"
fi

echo "base ref: $BASE_REF (로컬 브랜치 상태 무시, origin 최신 기준)"
```

> **로컬 `dev`/`main` 을 checkout·pull 하지 않습니다.** worktree 는 remote ref 에서 직접 분기하므로 로컬이 stale 해도 영향 없음.

### Step 3 — 브랜치명 결정

형식: `{타입}-{이름}` (kebab-case, 이름 1~2단어)

| 타입 | 의미 | 예시 |
|------|------|------|
| `feature` | 새 기능 | `feature-login` |
| `fix` | 버그 수정 | `fix-signup` |
| `hotfix` | 긴급 프로덕션 수정 | `hotfix-payment` |
| `refactor` | 리팩토링 | `refactor-auth` |
| `chore` | 설정·의존성·잡무 | `chore-deps` |
| `docs` | 문서 | `docs-api` |
| `test` | 테스트 추가/수정 | `test-user` |
| `perf` | 성능 개선 | `perf-query` |

타입 없이 이름만 (예: `login`) → `feature-login`으로 자동 처리.

### Step 4 — Worktree 생성

```bash
git worktree add .worktrees/{type}-{name} -b {type}/{name} "$BASE_REF"
```

`$BASE_REF` 는 Step 2 에서 결정된 `origin/dev` 또는 `origin/main`. worktree 의 HEAD 가 origin 의 최신 커밋을 가리킨 채로 새 브랜치가 생성됩니다.

### Step 5 — 스택별 의존성 설치

```bash
cd .worktrees/{type}-{name}
[ -f go.mod ] && go mod download
[ -f package.json ] && npm ci
[ -f gradlew ] && ./gradlew dependencies --no-daemon -q
[ -f pubspec.yaml ] && flutter pub get
[ -f pyproject.toml ] && command -v uv &>/dev/null && uv sync
```

### Step 6 — 작업 안내

```
Worktree 준비 완료

브랜치:  {type}/{name}
경로:    .worktrees/{type}-{name}/
베이스:  $BASE_REF (origin 최신 기준)

병렬 작업:
  cd .worktrees/{type}-{name}   # 다른 터미널
  claude --dir .worktrees/{type}-{name}

작업 완료 후:
  /pr                  → PR 생성 (base: $BASE_LABEL 자동 감지)
  /merge               → 머지 후 정리 (태그 + worktree 제거)
```

### Worktree 현황

```bash
git worktree list
```
