# [프로젝트명] — Python uv Workspace

## Stack
Python 3.11+ · FastAPI · SQLAlchemy 2.0 · Alembic (서비스별) · Pydantic v2 · pytest+httpx · ruff · mypy (strict) · **uv workspace**

## Agents & Commands
`python-generator` / `python-modifier` / `python-tester` / `code-reviewer`. `/new module <svc>` 로 서비스 추가. 공통 커맨드는 단일 모듈과 동일.

## 워크스페이스 레이아웃
```
pyproject.toml           # 루트 — [tool.uv.workspace] members
services/{api,worker}/
  pyproject.toml
  app/                   # AGENTS.python.md 구조와 동일
  alembic/ · tests/
packages/shared/
  pyproject.toml         # 순수 라이브러리 (FastAPI·SQLAlchemy import 금지)
  src/shared/
```

## 의존 규칙
| 모듈 | 의존 가능 | 의존 불가 |
|------|----------|----------|
| `packages/shared` | (없음 — 순수) | `services/*` |
| `services/api` | `shared` | `services/worker` |
| `services/worker` | `shared` | `services/api` |

서비스 간 직접 import 금지 — HTTP / 메시지 큐 / 이벤트 버스로만 통신.

## 루트 pyproject.toml 핵심
```toml
[tool.uv.workspace]
members = ["services/api", "services/worker", "packages/shared"]

[tool.uv.sources]
shared = { workspace = true }
```

## 공통 규칙
**레이어별 세부 규칙은 `AGENTS.python.md` 와 동일** — MUST/NEVER 섹션 그대로 적용. 서비스별 `AGENTS.md` 가 있으면 그걸 우선.

## Alembic (서비스별 분리 권장)
```bash
cd services/api
uv run alembic revision --autogenerate -m "..."
uv run alembic upgrade head
```
기존 revision 파일 수정 금지 — 항상 새 revision.

## 명령어
```bash
# 루트
uv sync
uv run ruff check . && uv run ruff format --check .
uv run mypy services packages
uv run pytest services packages

# 서비스 단위
uv run --directory services/api uvicorn app.main:app --reload
uv run --directory services/api pytest
uv add --project services/api fastapi
```

**상세 패턴**: `.agents/skills/python-patterns/SKILL.md`.

**커버리지 게이트**: git push 전 각 서비스 라인 커버리지 ≥80% (`.claude/hooks/pre-push.sh`).

## 학습된 규칙
<!-- /rule 로 여기에 추가됩니다 -->

## Memory
세션 시작 시 `memory/MEMORY.md` 자동 로드.

> **AGENTS.md ≤ 300줄 캡** — 초과 시 상세는 `.agents/skills/` 또는 `docs/` 로 이관, 본문은 인덱스 한 줄로.
