# coding-agent-starter

코딩 에이전트 하네스(skill · agent · hook · settings) 배포용 스타터 — **Claude Code · Codex 둘 다, 또는 하나만** 써도 동작한다.
**이 저장소 자체는 라이브러리** — 각 파일이 그대로 사용자 프로젝트에 복사됩니다 (`bootstrap.sh --platform claude|codex|both`).

> 지침 파일은 `AGENTS.md` 하나다 (Claude Code ≥ 2.1.277 · Codex 공통). **`CLAUDE.md` 를 만들지 마라** — 같은 디렉토리나 상위에 있으면 Claude Code 가 AGENTS.md 를 무시한다.

## 핵심 원칙

### 1. 배포 소스의 모든 문자는 곧 사용자 세션 토큰
`.claude/templates/AGENTS.*.md`, `.claude/templates/settings.*.json` 은 사용자 프로젝트에 **매 세션 로드**. 한 줄 줄이면 100명 × 매 세션 절감.
- 상세 코드 예시는 `.agents/skills/{stack}-patterns/SKILL.md` 로 이관 (on-demand 로드)
- AGENTS.md 템플릿은 **규칙만**, 예시 금지
- settings.json 의 `allow` 리스트에 `ls/find/grep/cat` 등 내장 도구 중복 금지

### 1-1. AGENTS.md ≤ 300줄 (절대 초과 금지)
**모든 AGENTS.md** (이 저장소 / `templates/AGENTS.*.md` / 사용자 프로젝트 루트·역할별) 은 300줄을 넘기지 못합니다.
- 초과 시 **즉시** 상세 내용을 `.agents/skills/*/SKILL.md` 또는 `docs/*.md` 로 이관
- AGENTS.md 에는 **규칙 + 인덱스만** — 코드 예시·스니펫·긴 표는 skill/docs 파일로
- 인덱싱 형식: ``상세: `.agents/skills/{name}/SKILL.md`` 한 줄로 참조 (필요할 때만 로드)
- 이유: AGENTS.md 는 매 세션 로드 — 초과 시 모든 사용자에게 매 세션 토큰 낭비

### 2. 토큰 회계
| 위치 | 로드 시점 | 최적화 우선순위 |
|------|---------|---------------|
| `templates/AGENTS.*.md` | 사용자 매 세션 | ★★★ |
| `.claude/agents/*.md` (description) | 매 세션 (Agent schema · Codex agents) | ★★ |
| `.agents/skills/*/SKILL.md` (frontmatter description) | 매 세션 (skill list) | ★★ |
| skill · agent body | on-invoke | ★ |

부작용 큰 skill (`init`·`rule`·`release`·`upgrade`·`starter`·`merge`·`handoff`) 은 `disable-model-invocation: true`.

### 3. 훅은 사용자 프로젝트에서 실행됨 — 방어적으로
`.claude/hooks/*.sh` 는 사용자 환경에서 Claude·Codex 양쪽이 부른다:
- `.claude/stacks.json` 없으면 즉시 `exit 0` — 에러로 세션 방해 금지 (공통 헬퍼 `.claude/hooks/lib.sh`)
- 명령 없으면 조용히 skip (`command -v X &>/dev/null` 체크)
- 실패해도 session blocking 최소화 (`tail -N` 으로 출력 제한)
- 옵션은 `stacks.json` 의 `harness` 블록 (`harness_opt KEY DEFAULT`) — 새 옵션은 기본값을 안전한 쪽으로

### 4. 규칙은 한 벌, 플랫폼별 배선만 따로
- skill 원본 `.agents/skills/` · `.claude/skills` 는 그 심볼릭 링크 (Claude 용)
- subagent 원본 `.claude/agents/*.md` → `.codex/agents/*.toml` 은 **생성물** (`python3 .claude/scripts/gen-codex-agents.py`). toml 을 손으로 고치지 않는다 — pre-commit·CI 가 `--check`
- 훅 스크립트 한 벌 `.claude/hooks/` — Claude 는 `settings.*.json`, Codex 는 `.codex/hooks.json` (+ `codex-adapter.sh`) 가 부른다
- 강제가 필요한 게이트는 git 훅(`.claude/githooks/`)에도 — 에이전트·터미널 무관하게 돈다

## 디렉토리 구조

```
.agents/skills/<name>/SKILL.md   # skill 원본 (워크플로 skill + 패턴 skill)
.claude/
├── agents/              # subagent 정의 원본 (스택별 generator/modifier/tester + 공통)
├── skills -> ../.agents/skills
├── hooks/               # 공용 훅 (lib.sh · safety-guard · worktree-guard · pre-push · stop-tests · ...)
├── githooks/            # pre-commit · pre-push (core.hooksPath)
├── scripts/             # init-cleanup · gen-codex-agents · coverage-gate · cross-review · ... (+ tests/)
├── templates/           # AGENTS.{stack}.md + settings.{stack}.json + cicd/ + gitleaks.toml + optional-skills.json
└── settings.json        # 스타터 자체 세션용
.codex/                  # Codex 배포본: config.toml · hooks.json · rules/ · agents/(생성물)
bootstrap.sh             # 설치·업데이트 (--platform · --version · --no-preserve · STARTER_SRC=로컬 검증)
VERSION                  # 스타터 버전
memory/MEMORY.md         # 스타터 개발 second brain
docs/assets/             # README 애니메이션 SVG — `python3 docs/assets/gen-diagrams.py` 로 재생성 (SVG 직접 수정 금지 · 배포 안 됨)
```

## 변경 시 체크포인트

### 템플릿 (`templates/AGENTS.*.md`, `templates/settings.*.json`)
- 각 `AGENTS.{stack}.md` 는 ≤120줄 (CI) — 넘으면 skills 로 이관
- `settings.{stack}.json` `allow` 에 내장 도구와 중복되는 Bash 금지 · `claude-md-management` 플러그인 금지 (CLAUDE.md 생성)
- `enabledPlugins` 는 스택별 최소 필수만
- 훅을 추가·삭제하면 `.codex/hooks.json` 과 `install-matrix.yml` 의 hooks contract 도 같이

### Skill (`.agents/skills/<name>/SKILL.md`)
- frontmatter `name` = 디렉토리명, `description` 한 줄 (YAML 유효 — `argument-hint` 는 따옴표)
- 새 skill 은 `init-cleanup.sh` 의 keep 목록(`WORKFLOW_SKILLS` 또는 스택별)에 등록 — orphan check

### Agent (`.claude/agents/*.md`)
- description 한 줄·트리거 키워드 중심 · `model:` 은 티어 별칭 (`sonnet`/`opus`/`haiku`) · `effort:` 필수
- 바꾼 뒤 `python3 .claude/scripts/gen-codex-agents.py` 로 `.codex/agents/` 재생성

### Hook / Script
- 반드시 `.claude/stacks.json` 존재 여부 먼저 체크 → 없으면 `exit 0`
- 외부 명령 실행 전 `command -v` 가드 · 출력은 `tail -N`
- 테스트: `python3 -m unittest discover -s .claude/scripts/tests` + `bash .claude/scripts/tests/test_hooks.sh`

## 버전 관리
- `VERSION` 파일이 단일 진실 (`.claude-plugin/plugin.json` version 동기화)
- `main` 에 VERSION 변경 커밋 push → GitHub Actions 가 자동 태그·릴리스 (`.github/workflows/auto-tag.yml`)
- `CHANGELOG.md` 에 변경사항 먼저 기록 → VERSION 업데이트 → commit
- 사용자 프로젝트용 dev→main + ghcr Docker 사이클 템플릿: `.claude/templates/cicd/README.md`

## 기여 가이드
1. 변경은 `feature/`, `fix/`, `chore/` 브랜치에서
2. 스택 하나 추가 시 세트: `.claude/agents/{stack}-{generator,modifier,tester}.md` + `.agents/skills/{stack}-patterns/SKILL.md` + `templates/AGENTS.{stack}.md` + `templates/settings.{stack}.json` + `init-cleanup.sh` keep 목록 + Codex agents 재생성
3. PR 전 설치 시나리오 검증: 빈 디렉토리에서 `STARTER_SRC=<이 저장소> bash <이 저장소>/bootstrap.sh --platform {claude,codex,both}`
4. 새 훅 추가 시 `.claude/stacks.json` 없는 빈 프로젝트에서 실행해 조용한 실패 확인

## 스타터 자체 개발용 skill
이 저장소에서는 스택이 없으므로 `/new`, `/plan` 이 실제 코드 생성을 하지 않습니다. 사용 가능:
- `/commit`, `/pr`, `/merge` — 일반 Git 워크플로
- `/memory` — 스타터 개발 second brain
- `/review` — 문서/템플릿 리뷰 · `/harness` — 하네스 검증

## Memory
`memory/MEMORY.md` 세션 시작 시 자동 로드. 스타터 아키텍처 변경·사용자 피드백 기반 결정·플러그인 정책 변경 → 기록.
