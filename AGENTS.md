# claude-code-starter

Claude Code 하네스(agent · skill · command · hook · settings) 배포용 스타터.
**이 저장소 자체는 라이브러리** — 각 파일이 그대로 사용자 프로젝트 `.claude/` 에 복사됩니다.

## 핵심 원칙

### 1. 배포 소스의 모든 문자는 곧 사용자 세션 토큰
`.claude/templates/CLAUDE.*.md`, `.claude/settings.*.json` 은 사용자 프로젝트에 **매 세션 로드**. 한 줄 줄이면 100명 × 매 세션 절감.
- 상세 코드 예시는 `.claude/skills/{stack}-patterns.md` 로 이관 (on-demand 로드)
- CLAUDE.md 템플릿은 **규칙만**, 예시 금지
- settings.json 의 `allow` 리스트에 `ls/find/grep/cat` 등 내장 도구 중복 금지

### 1-1. CLAUDE.md ≤ 300줄 (절대 초과 금지)
**모든 CLAUDE.md** (이 저장소 / `templates/CLAUDE.*.md` / 사용자 프로젝트 루트·역할별 / 모노레포 sub-CLAUDE.md) 은 300줄을 넘기지 못합니다.
- 초과 시 **즉시** 상세 내용을 `.claude/skills/*.md` 또는 `docs/*.md` 로 이관
- CLAUDE.md 에는 **규칙 + 인덱스만** — 코드 예시·스니펫·긴 표는 skill/docs 파일로
- 인덱싱 형식: ``상세: `.claude/skills/{name}.md`` 한 줄로 참조 (claude code 가 필요시에만 로드)
- `/init`, `/rule`, 사용자가 CLAUDE.md 를 직접 편집할 때마다 줄 수 검사
- 이유: CLAUDE.md 는 매 세션 로드 — 초과 시 모든 사용자에게 매 세션 토큰 낭비

### 2. 토큰 회계
| 위치 | 로드 시점 | 최적화 우선순위 |
|------|---------|---------------|
| `templates/CLAUDE.*.md` | 사용자 매 세션 | ★★★ |
| `agents/*.md` (description) | 사용자 매 세션 (Agent schema) | ★★ |
| `commands/*.md` (description) | 사용자 매 세션 (skill list) | ★★ |
| `skills/*.md` | on-invoke | ★ |
| agent/command/skill body | on-invoke | ★ |

### 3. 훅은 사용자 프로젝트에서 실행됨 — 방어적으로
`hooks/*.sh` 는 사용자 환경에서 돌기 때문에:
- stacks.json 없으면 즉시 `exit 0` — 에러로 세션 방해 금지
- 명령 없으면 조용히 skip (`command -v X &>/dev/null` 체크)
- 실패해도 session blocking 최소화 (`tail -N` 으로 출력 제한)

## 디렉토리 구조

```
.claude/
├── agents/              # subagent 정의 (스택별 generator/modifier/tester + 공통)
├── commands/            # /init, /new, /plan, /review, /commit, /pr, /merge, ...
├── skills/              # 코드 패턴 상세 (on-invoke 로드)
├── templates/           # CLAUDE.{stack}.md + settings.{stack}.json 배포용 원본
├── hooks/               # pre-push.sh, safety-guard.sh, post-edit-lint.sh, ...
├── settings.json        # 스타터 자체 세션용 (배포 대상 아님)
└── settings.local.json  # 개인 설정 (gitignore)
bootstrap.sh             # 새 프로젝트에서 curl 설치 스크립트
VERSION                  # 스타터 버전
memory/MEMORY.md         # 스타터 개발 second brain
```

## 변경 시 체크포인트

### 템플릿 (`templates/CLAUDE.*.md`, `templates/settings.*.json`)
- 각 `CLAUDE.{stack}.md` 는 ≤150줄 목표 — 넘으면 skills 로 이관
- `settings.{stack}.json` `allow` 에 내장 도구와 중복되는 Bash 금지 (`ls`, `find`, `grep`, `cat`)
- `enabledPlugins` 는 스택별 최소 필수만 (평균 5~8개)

### Agent description (`agents/*.md` frontmatter)
- 매 세션 `Agent` tool schema 에 description 로드 — 한 줄·트리거 키워드 중심
- 긴 설명은 body 로 (description 이 아니라)

### Command description (`commands/*.md` frontmatter)
- 매 세션 skill 리스트에 description 로드 — 간결하게
- body 는 실행 시에만 로드되므로 용량 제약 덜함

### Hook 스크립트 (`hooks/*.sh`)
- 반드시 `.claude/stacks.json` 존재 여부 먼저 체크 → 없으면 `exit 0`
- 외부 명령 실행 전 `command -v` 가드
- 출력은 `tail -N` 으로 제한 (세션 컨텍스트 보호)

## 버전 관리
- `VERSION` 파일이 단일 진실
- `main` 에 VERSION 변경 커밋 push → GitHub Actions 가 자동 태그·릴리스 (`.github/workflows/auto-tag.yml`)
- `CHANGELOG.md` 에 변경사항 먼저 기록 → VERSION 업데이트 → commit
- 사용자 프로젝트용 dev→main + ghcr Docker 사이클 템플릿: `.claude/templates/cicd/README.md`

## 기여 가이드
1. 변경은 `feature/`, `fix/`, `chore/` 브랜치에서
2. 스택 하나 추가 시 세트: `agents/{stack}-{generator,modifier,tester}.md` + `skills/{stack}-patterns.md` + `templates/CLAUDE.{stack}.md` + `templates/settings.{stack}.json` + commands 업데이트
3. PR 전 `bootstrap.sh` 직접 실행해 설치 시나리오 검증
4. 새 훅 추가 시 `.claude/stacks.json` 없는 빈 프로젝트에서 실행해 조용한 실패 확인

## 스타터 자체 개발용 커맨드
이 저장소에서는 스택이 없으므로 `/new`, `/plan` 이 실제 코드 생성을 하지 않습니다. 사용 가능:
- `/commit`, `/pr`, `/merge` — 일반 Git 워크플로
- `/memory` — 스타터 개발 second brain
- `/review` — 문서/템플릿 리뷰

## Memory
`memory/MEMORY.md` 세션 시작 시 자동 로드. 스타터 아키텍처 변경·사용자 피드백 기반 결정·플러그인 정책 변경 → 기록.
