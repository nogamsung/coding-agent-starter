# [프로젝트명] — Monorepo

여러 스택 공존 모노레포. Claude Code 는 편집 중인 파일의 **상위 디렉토리 `AGENTS.md` 를 누적 로드** — 루트 + 해당 스택 AGENTS.md 가 모두 컨텍스트에 들어옵니다.

| 역할 | 경로 | 스택 | 세부 규칙 |
|------|------|------|-----------|
| backend | `[backend-path]` | [backend-stack] | [`[backend-path]/AGENTS.md`](./[backend-path]/AGENTS.md) |
| frontend | `[frontend-path]` | [frontend-stack] | [`[frontend-path]/AGENTS.md`](./[frontend-path]/AGENTS.md) |
| mobile | `[mobile-path]` | [mobile-stack] | [`[mobile-path]/AGENTS.md`](./[mobile-path]/AGENTS.md) |

`/init` 실행 시 감지된 스택만 남고 나머지 행은 제거됩니다.

## 단일 진실의 원천 — `.claude/stacks.json`
```json
{
  "mode": "monorepo",
  "stacks": [
    { "role": "backend",  "type": "[backend-stack]",  "path": "[backend-path]" },
    { "role": "frontend", "type": "[frontend-stack]", "path": "[frontend-path]" },
    { "role": "mobile",   "type": "[mobile-stack]",   "path": "[mobile-path]" }
  ]
}
```

`/new`, `/plan`, `/test`, `.claude/hooks/*` 는 이 파일을 읽어 스택별로 분기.

## Agents (역할별)
| 역할 | 새 파일 | 수정 | 테스트 |
|------|---------|------|--------|
| backend | `{backend}-generator` | `{backend}-modifier` | `{backend}-tester` |
| frontend | `nextjs-generator` | `nextjs-modifier` | `nextjs-tester` |
| mobile | `flutter-generator` | `flutter-modifier` | `flutter-tester` |

공통: `code-reviewer`, `api-designer`¹, `ui-designer`², `github-actions-designer` (¹backend 있을 때, ²frontend/mobile 있을 때).

## 역할 prefix — 대상 스택 지정
| 커맨드 | 예시 |
|--------|------|
| `/new backend api User` | backend 경로에서 REST API 생성 |
| `/new frontend component Button` | frontend 경로에서 컴포넌트 |
| `/new mobile screen Login` | mobile 경로에서 화면 |
| `/plan backend api User` | backend 스택 API 설계 |
| `/plan backend db order` | backend DB 설계 |

prefix 생략 시 — 스택 1개면 자동, 2개 이상이면 확인. `/test`, `/review` 는 파일 경로로 자동 판단.

## 역할 디렉토리 별칭
`/init` 탐색 순서:
- **backend**: `backend`, `api`, `server`
- **frontend**: `frontend`, `web`, `client`
- **mobile**: `mobile`, `app`

별칭 써도 prefix 는 표준 이름 (`backend`/`frontend`/`mobile`) 사용 — 실제 경로는 `stacks.json` lookup.

## 중첩 멀티모듈
각 역할 디렉토리 내부 멀티모듈 자동 감지:
- `settings.gradle.kts` 에 `include(` → `kotlin-multi`
- `go.work` → `go-multi`
- `pyproject.toml` 에 `[tool.uv.workspace]` → `python-multi`
- `turbo.json` → `nextjs-multi`

`/new module <name>` 은 해당 역할 디렉토리에서 실행.

## 기획 → 구현 워크플로
```
/start 결제 취소 기능
  → worktree(feature/payment-cancel) 자동 생성
  → docs/specs/payment-cancel.md (PRD)
  → docs/specs/payment-cancel/{backend,frontend,mobile}.md (역할별 프롬프트)
  → 1회 확인 후 generator agent 병렬 실행 (단일 스택은 무확인)

# 설계만 (worktree 없이) 원하면:
/plan 결제 취소 기능              # PRD + 프롬프트만
/plan 결제 취소 기능 --teams      # PRD 후 즉시 generator 실행
/review → 3개 역할 일괄 리뷰
/pr
```

## Git 전략
단일 레포와 동일 (`main` / `dev` / `{feature|fix|hotfix|refactor|chore}/{name}`). 각 스택 `AGENTS.md` 참고.

## 커버리지 게이트
`git push` 시 `.claude/hooks/pre-push.sh` 가 활성 스택 전부 순차 검증. 임계값 **90%**. 한 스택이라도 실패하면 push 차단.

## 주의사항
- **스택 경계 유지** — backend ↛ frontend 디렉토리 직접 참조. API 계약(`docs/api/*.yaml`)으로만 연결
- **의존성 독립** — 각 스택 독립 manifest (`build.gradle.kts`, `package.json`, `pubspec.yaml`). 루트 공유 manifest 없음
- **CI 분리** — GitHub Actions `paths-filter` 로 변경된 스택만 실행 (`/new workflow ci` 자동 반영)
- **PR 스코프** — 가능하면 PR 당 1개 스택. 걸치면 커밋 분리

각 스택 `AGENTS.md` 반드시 읽으세요.

> **AGENTS.md ≤ 300줄 캡** — 루트 인덱스와 모든 역할별 sub-AGENTS.md 포함. 초과 시 상세는 `.agents/skills/` 또는 `docs/` 로 이관.
