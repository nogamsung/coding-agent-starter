# [프로젝트명] — Python FastAPI

## Stack
FastAPI · SQLAlchemy 2.0 (async) · Alembic · Pydantic v2 · pytest+httpx · ruff · mypy (strict) · **uv**

## Agents & Commands
| 목적 | Agent / Command |
|------|----------------|
| 새 파일 생성 | `python-generator` |
| 기존 코드 수정 | `python-modifier` |
| 테스트 작성 | `python-tester` |
| 코드 리뷰 | `code-reviewer` · `/review` |
| API 설계 | `/plan api <Resource>` |
| DB 설계 | `/plan db <도메인>` |
| REST API 스캐폴딩 | `/new <Resource>` |
| 커밋/PR/머지 | `/commit` · `/pr` · `/merge` |
| 신규 기능 시작 | `/start <기능>` (worktree + PRD + 자동 구현) |
| 설계만 / 추가 PRD | `/plan <기능>` |
| Second Brain | `/memory [add\|search]` |

## Git 전략
| 브랜치 | 역할 |
|--------|------|
| `main` | 프로덕션 — PR+CI 통과 필수 |
| `dev` | 통합/스테이징 — PR+CI 통과 필수 |
| `{feature\|fix\|hotfix\|refactor\|chore}/{name}` | 작업 브랜치 |

Worktree 위치 `.worktrees/{type}-{name}/`, 각 worktree 독립 `.venv`. `main` 직접 push 금지.

## 디렉토리 구조
```
app/
├── main.py           # FastAPI 앱 + 예외 핸들러 + 라우터 등록
├── core/             # config, deps, security
├── db/               # Base, async engine, sessionmaker
├── models/           # SQLAlchemy ORM — Mapped[...] + mapped_column
├── schemas/          # Pydantic v2 Request/Response
├── repositories/     # AsyncSession 기반
├── services/         # 비즈니스 로직
├── routers/          # APIRouter
└── exceptions.py     # 도메인 커스텀 예외
alembic/versions/     # Alembic revisions
tests/{services,routers,repositories,integration,fixtures}/
```

**레이어 의존:** `routers` → `services` → `repositories` → `models`. `schemas` 는 routers/services 양쪽에서 사용.

## MUST
- **DI**: FastAPI `Depends` 로만 주입 — 모듈 전역 인스턴스 금지
- **async 일관성**: Service·Repository·Router 전부 `async def`, sync 혼용 금지
- **예외**: Service 는 커스텀 예외 (`NotFoundError` 등) 전파 → Router 또는 `@app.exception_handler` 에서 `HTTPException` 변환
- **Schema ≠ Model**: 응답은 `SchemaResponse.model_validate(...)` — ORM 모델 직접 반환 금지
- **타입 힌트**: 모든 public 함수 (mypy strict)
- **ORM**: `Mapped[...] = mapped_column(...)` — `Column(...)` 단독 금지
- **Pydantic v2**: `@field_validator` + `model_config = ConfigDict(...)` — v1 스타일 금지
- **Router 메타**: `response_model`, `responses`, `summary` 필수. dict 반환 금지
- **Trans 경계**: `session.commit()` 은 `Depends(get_db_session)` 에서만

## NEVER
- `models/` 에 비즈니스 로직
- `services/` 에서 `HTTPException` / `fastapi.*` import
- 기존 Alembic revision 파일 수정 (항상 새 revision)
- raw SQL 문자열 하드코딩 (`text()` + 파라미터 바인딩)
- `print()` 디버깅 (`logging` 사용)
- 패스워드·토큰·PII 로그 출력
- 테스트 없이 Service 메서드 추가
- `# type: ignore` 이유 주석 없이 사용
- `@pytest.mark.asyncio` 없이 async 테스트 (또는 `asyncio_mode = "auto"` 누락)

## 명령어
```bash
uv sync / uv add / uv remove
uv run ruff check . && uv run ruff format --check .
uv run mypy .
uv run pytest --cov=app
uv run alembic revision --autogenerate -m "..."
uv run alembic upgrade head
```

**상세 패턴**: `.agents/skills/python-patterns/SKILL.md` 참고 (agent 가 자동 로드).

**커버리지 게이트**: git push 전 라인 커버리지 ≥80% (`.claude/hooks/pre-push.sh`).

## 학습된 규칙
<!-- /rule 로 여기에 추가됩니다 -->

## Memory
세션 시작 시 `memory/MEMORY.md` 자동 로드. `/plan`, `/rule`, 버그 해결, 라이브러리 도입, 아키텍처 변경 → 자동 기록. `MEMORY.md` = 왜(히스토리), `AGENTS.md` = 어떻게(규칙).

> **AGENTS.md ≤ 300줄 캡** — 초과 시 상세는 `.agents/skills/` 또는 `docs/` 로 이관, 본문은 인덱스 한 줄로.
