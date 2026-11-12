---
name: python-patterns
description: Python FastAPI 코드·테스트 패턴 — SQLAlchemy·Pydantic·Repository·Service·Router·pytest. Python 코드를 만들거나 고칠 때 참고.
---

# Python FastAPI Code Patterns

## Generation Patterns

### SQLAlchemy Model (ORM)
```python
# app/models/order.py
from __future__ import annotations

from datetime import datetime
from enum import StrEnum

from sqlalchemy import DateTime, ForeignKey, String, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base


class OrderStatus(StrEnum):
    PENDING = "PENDING"
    CONFIRMED = "CONFIRMED"
    CANCELLED = "CANCELLED"


class Order(Base):
    __tablename__ = "orders"

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), index=True)
    status: Mapped[str] = mapped_column(
        String(20), nullable=False, server_default=OrderStatus.PENDING.value
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )

    user: Mapped["User"] = relationship(back_populates="orders")
```

### Declarative Base
```python
# app/db/base.py
from sqlalchemy.orm import DeclarativeBase


class Base(DeclarativeBase):
    pass
```

### Pydantic v2 Schemas
```python
# app/schemas/order.py
from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field


class OrderBase(BaseModel):
    model_config = ConfigDict(from_attributes=True, str_strip_whitespace=True)


class OrderCreate(OrderBase):
    product_id: int = Field(..., ge=1, description="상품 ID", examples=[10])
    quantity: int = Field(..., ge=1, le=999, description="수량", examples=[2])


class OrderUpdate(OrderBase):
    status: str | None = Field(None, description="상태", examples=["CONFIRMED"])


class OrderResponse(OrderBase):
    id: int = Field(..., examples=[1])
    user_id: int = Field(..., examples=[100])
    status: str = Field(..., examples=["PENDING"])
    created_at: datetime


class ErrorResponse(BaseModel):
    detail: str = Field(..., examples=["order not found"])
```

### Custom Exceptions
```python
# app/exceptions.py
class DomainError(Exception):
    """Base domain error."""


class NotFoundError(DomainError):
    def __init__(self, resource: str, identifier: int | str) -> None:
        self.resource = resource
        self.identifier = identifier
        super().__init__(f"{resource} not found: {identifier}")


class UnauthorizedError(DomainError):
    pass


class BadRequestError(DomainError):
    pass
```

### Repository (Data Access Layer)
```python
# app/repositories/order.py
from __future__ import annotations

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.order import Order


class OrderRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def find_by_id(self, order_id: int) -> Order | None:
        stmt = select(Order).where(Order.id == order_id)
        result = await self._session.execute(stmt)
        return result.scalar_one_or_none()

    async def list_by_user(
        self, user_id: int, *, limit: int = 20, offset: int = 0
    ) -> list[Order]:
        stmt = (
            select(Order)
            .where(Order.user_id == user_id)
            .order_by(Order.created_at.desc())
            .limit(limit)
            .offset(offset)
        )
        result = await self._session.execute(stmt)
        return list(result.scalars().all())

    async def search(
        self,
        *,
        user_id: int | None = None,
        status: str | None = None,
        limit: int = 20,
        offset: int = 0,
    ) -> list[Order]:
        stmt = select(Order)
        if user_id is not None:
            stmt = stmt.where(Order.user_id == user_id)
        if status is not None:
            stmt = stmt.where(Order.status == status)
        stmt = stmt.order_by(Order.created_at.desc()).limit(limit).offset(offset)
        result = await self._session.execute(stmt)
        return list(result.scalars().all())

    async def create(self, order: Order) -> Order:
        self._session.add(order)
        await self._session.flush()
        await self._session.refresh(order)
        return order

    async def update(self, order: Order) -> Order:
        await self._session.flush()
        await self._session.refresh(order)
        return order

    async def delete(self, order: Order) -> None:
        await self._session.delete(order)
        await self._session.flush()
```

### Service (Business Logic)
```python
# app/services/order.py
from __future__ import annotations

from app.exceptions import NotFoundError
from app.models.order import Order, OrderStatus
from app.repositories.order import OrderRepository
from app.schemas.order import OrderCreate, OrderUpdate


class OrderService:
    def __init__(self, repository: OrderRepository) -> None:
        self._repo = repository

    async def get(self, order_id: int) -> Order:
        order = await self._repo.find_by_id(order_id)
        if order is None:
            raise NotFoundError("order", order_id)
        return order

    async def create(self, user_id: int, data: OrderCreate) -> Order:
        order = Order(
            user_id=user_id,
            status=OrderStatus.PENDING.value,
        )
        return await self._repo.create(order)

    async def cancel(self, order_id: int) -> Order:
        order = await self.get(order_id)
        order.status = OrderStatus.CANCELLED.value
        return await self._repo.update(order)
```

### Dependencies (DI)
```python
# app/core/deps.py
from collections.abc import AsyncGenerator
from typing import Annotated

from fastapi import Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import async_session_maker
from app.repositories.order import OrderRepository
from app.services.order import OrderService


async def get_db_session() -> AsyncGenerator[AsyncSession, None]:
    async with async_session_maker() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise


DbSession = Annotated[AsyncSession, Depends(get_db_session)]


def get_order_repository(session: DbSession) -> OrderRepository:
    return OrderRepository(session)


def get_order_service(
    repo: Annotated[OrderRepository, Depends(get_order_repository)],
) -> OrderService:
    return OrderService(repo)


OrderServiceDep = Annotated[OrderService, Depends(get_order_service)]
```

### DB Session (engine/sessionmaker)
```python
# app/db/session.py
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine

from app.core.config import settings

engine = create_async_engine(
    settings.database_url,
    pool_pre_ping=True,
    pool_size=10,
    max_overflow=20,
    echo=settings.sql_echo,
)

async_session_maker = async_sessionmaker(
    engine,
    expire_on_commit=False,
)
```

### Config (Pydantic Settings)
```python
# app/core/config.py
from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
    )

    app_name: str = Field(default="my-api")
    debug: bool = Field(default=False)
    database_url: str = Field(...)
    sql_echo: bool = Field(default=False)
    jwt_secret: str = Field(...)
    jwt_algorithm: str = Field(default="HS256")


settings = Settings()  # type: ignore[call-arg]
```

### Router (FastAPI endpoints)
```python
# app/routers/orders.py
from fastapi import APIRouter, Path, Query, status
from fastapi.responses import Response

from app.core.deps import OrderServiceDep
from app.exceptions import NotFoundError
from app.schemas.order import ErrorResponse, OrderCreate, OrderResponse

router = APIRouter(prefix="/api/v1/orders", tags=["orders"])


@router.get(
    "/{order_id}",
    response_model=OrderResponse,
    summary="주문 단건 조회",
    responses={404: {"model": ErrorResponse}},
)
async def get_order(
    service: OrderServiceDep,
    order_id: int = Path(..., ge=1, description="주문 ID"),
) -> OrderResponse:
    try:
        order = await service.get(order_id)
    except NotFoundError as exc:
        raise _not_found(exc) from exc
    return OrderResponse.model_validate(order)


@router.post(
    "",
    response_model=OrderResponse,
    status_code=status.HTTP_201_CREATED,
    summary="주문 생성",
    responses={400: {"model": ErrorResponse}},
)
async def create_order(
    data: OrderCreate,
    service: OrderServiceDep,
    # 실제로는 auth dependency 에서 user_id 주입
    user_id: int = Query(..., ge=1, description="테스트용 — 실제는 auth 의존성"),
) -> OrderResponse:
    order = await service.create(user_id, data)
    return OrderResponse.model_validate(order)


@router.post(
    "/{order_id}/cancel",
    response_model=OrderResponse,
    summary="주문 취소",
    responses={404: {"model": ErrorResponse}},
)
async def cancel_order(
    service: OrderServiceDep,
    order_id: int = Path(..., ge=1),
) -> OrderResponse:
    try:
        order = await service.cancel(order_id)
    except NotFoundError as exc:
        raise _not_found(exc) from exc
    return OrderResponse.model_validate(order)


def _not_found(exc: NotFoundError) -> "HTTPException":
    from fastapi import HTTPException  # deferred import — avoid circular

    return HTTPException(
        status_code=status.HTTP_404_NOT_FOUND,
        detail=str(exc),
    )
```

### Exception Handlers (main.py)
```python
# app/main.py
from fastapi import FastAPI, Request, status
from fastapi.responses import JSONResponse

from app.core.config import settings
from app.exceptions import BadRequestError, NotFoundError, UnauthorizedError
from app.routers import orders

app = FastAPI(
    title=settings.app_name,
    version="1.0.0",
    debug=settings.debug,
)

app.include_router(orders.router)


@app.exception_handler(NotFoundError)
async def not_found_handler(_: Request, exc: NotFoundError) -> JSONResponse:
    return JSONResponse(
        status_code=status.HTTP_404_NOT_FOUND,
        content={"detail": str(exc)},
    )


@app.exception_handler(UnauthorizedError)
async def unauthorized_handler(_: Request, exc: UnauthorizedError) -> JSONResponse:
    return JSONResponse(
        status_code=status.HTTP_401_UNAUTHORIZED,
        content={"detail": str(exc)},
    )


@app.exception_handler(BadRequestError)
async def bad_request_handler(_: Request, exc: BadRequestError) -> JSONResponse:
    return JSONResponse(
        status_code=status.HTTP_400_BAD_REQUEST,
        content={"detail": str(exc)},
    )
```

### Alembic Migration
```python
# alembic/versions/0001_create_orders_table.py
"""create orders table

Revision ID: 0001
Revises:
Create Date: 2026-04-19 12:00:00
"""
from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "0001"
down_revision: str | None = None
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "orders",
        sa.Column("id", sa.BigInteger(), autoincrement=True, nullable=False),
        sa.Column("user_id", sa.BigInteger(), nullable=False),
        sa.Column("status", sa.String(length=20), nullable=False, server_default="PENDING"),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("idx_orders_user_id", "orders", ["user_id"])


def downgrade() -> None:
    op.drop_index("idx_orders_user_id", table_name="orders")
    op.drop_table("orders")
```

### pyproject.toml (uv 프로젝트)
```toml
[project]
name = "my-api"
version = "0.1.0"
requires-python = ">=3.11"
dependencies = [
    "fastapi>=0.115",
    "uvicorn[standard]>=0.32",
    "sqlalchemy[asyncio]>=2.0",
    "alembic>=1.13",
    "asyncpg>=0.29",
    "pydantic>=2.9",
    "pydantic-settings>=2.6",
    "python-jose[cryptography]>=3.3",
    "passlib[bcrypt]>=1.7",
]

[dependency-groups]
dev = [
    "pytest>=8.3",
    "pytest-asyncio>=0.24",
    "httpx>=0.28",
    "aiosqlite>=0.20",
    "ruff>=0.7",
    "mypy>=1.13",
    "types-python-jose",
]

[tool.ruff]
line-length = 100
target-version = "py311"

[tool.ruff.lint]
select = ["E", "F", "I", "N", "UP", "B", "A", "C4", "SIM", "TCH", "ERA", "PL"]
ignore = ["PLR0913"]

[tool.mypy]
python_version = "3.11"
strict = true
plugins = ["pydantic.mypy"]

[tool.pytest.ini_options]
asyncio_mode = "auto"
testpaths = ["tests"]
```

---

## Modification Patterns

### 필드 추가
```python
# 1. Model 에 필드 추가
class Order(Base):
    # ...
    description: Mapped[str | None] = mapped_column(String(500))  # ADDED

# 2. Alembic migration (새 revision)
# alembic revision --autogenerate -m "add_description_to_orders"

# 3. Schema 업데이트
class OrderResponse(OrderBase):
    # ...
    description: str | None = Field(None)  # ADDED

class OrderUpdate(OrderBase):
    description: str | None = Field(None)  # ADDED
```

### 새 엔드포인트 추가
```python
# Router 에 메서드 추가
@router.get("/{order_id}/history", response_model=list[OrderEventResponse])
async def get_order_history(
    service: OrderServiceDep,
    order_id: int = Path(..., ge=1),
) -> list[OrderEventResponse]:
    events = await service.get_history(order_id)
    return [OrderEventResponse.model_validate(e) for e in events]

# Service 메서드 추가 (router → service → repository 순)
async def get_history(self, order_id: int) -> list[OrderEvent]:
    await self.get(order_id)  # 존재 확인
    return await self._event_repo.list_by_order(order_id)
```

---

## Test Patterns

### conftest.py
```python
# tests/conftest.py
from collections.abc import AsyncGenerator
from typing import Any

import pytest
from httpx import ASGITransport, AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine

from app.db.base import Base
from app.main import app


@pytest.fixture
async def engine():
    engine = create_async_engine("sqlite+aiosqlite:///:memory:", echo=False)
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    yield engine
    await engine.dispose()


@pytest.fixture
async def session(engine) -> AsyncGenerator[AsyncSession, None]:
    maker = async_sessionmaker(engine, expire_on_commit=False)
    async with maker() as s:
        yield s


@pytest.fixture
async def client() -> AsyncGenerator[AsyncClient, None]:
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as c:
        yield c
    app.dependency_overrides.clear()
```

### Fixture (Factory)
```python
# tests/fixtures/order.py
from datetime import datetime, timezone

from app.models.order import Order, OrderStatus


def make_order(**overrides) -> Order:
    defaults = {
        "id": 1,
        "user_id": 1,
        "status": OrderStatus.PENDING.value,
        "created_at": datetime.now(timezone.utc),
        "updated_at": datetime.now(timezone.utc),
    }
    defaults.update(overrides)
    return Order(**defaults)
```

### Service Unit Test (AsyncMock)
```python
# tests/services/test_order_service.py
from unittest.mock import AsyncMock

import pytest

from app.exceptions import NotFoundError
from app.repositories.order import OrderRepository
from app.services.order import OrderService
from tests.fixtures.order import make_order


class TestOrderServiceGet:
    async def test_주문이_존재하면_반환한다(self) -> None:
        order = make_order(id=1)
        repo = AsyncMock(spec=OrderRepository)
        repo.find_by_id.return_value = order

        service = OrderService(repo)
        result = await service.get(1)

        assert result.id == 1
        repo.find_by_id.assert_awaited_once_with(1)

    async def test_주문이_없으면_NotFoundError를_던진다(self) -> None:
        repo = AsyncMock(spec=OrderRepository)
        repo.find_by_id.return_value = None

        service = OrderService(repo)
        with pytest.raises(NotFoundError) as exc_info:
            await service.get(999)

        assert exc_info.value.resource == "order"
        repo.find_by_id.assert_awaited_once_with(999)
```

### Router Test (httpx AsyncClient + dependency_overrides)
```python
# tests/routers/test_order_router.py
from unittest.mock import AsyncMock

import pytest
from httpx import AsyncClient

from app.core.deps import get_order_service
from app.exceptions import NotFoundError
from app.main import app
from app.services.order import OrderService
from tests.fixtures.order import make_order


class TestGetOrder:
    async def test_유효한_ID로_주문을_조회한다(self, client: AsyncClient) -> None:
        service = AsyncMock(spec=OrderService)
        service.get.return_value = make_order(id=1)
        app.dependency_overrides[get_order_service] = lambda: service

        response = await client.get("/api/v1/orders/1")

        assert response.status_code == 200
        assert response.json()["id"] == 1

    async def test_존재하지_않는_주문은_404(self, client: AsyncClient) -> None:
        service = AsyncMock(spec=OrderService)
        service.get.side_effect = NotFoundError("order", 999)
        app.dependency_overrides[get_order_service] = lambda: service

        response = await client.get("/api/v1/orders/999")

        assert response.status_code == 404
        assert "not found" in response.json()["detail"]

    async def test_유효하지_않은_ID는_422(self, client: AsyncClient) -> None:
        response = await client.get("/api/v1/orders/0")  # ge=1 위반

        assert response.status_code == 422
```

### Repository Integration Test
```python
# tests/repositories/test_order_repository.py
import pytest

from app.models.order import Order, OrderStatus
from app.repositories.order import OrderRepository


@pytest.mark.integration
class TestOrderRepository:
    async def test_create_and_find_by_id(self, session) -> None:
        repo = OrderRepository(session)
        order = Order(user_id=1, status=OrderStatus.PENDING.value)

        created = await repo.create(order)

        found = await repo.find_by_id(created.id)
        assert found is not None
        assert found.user_id == 1
```

### Test Anti-patterns
- `assert True` / `assert 1 == 1` 같은 placeholder 금지
- 예외 메시지 문자열 비교 금지 — `.resource`, `.identifier` 등 속성 검증
- mock 없이 실제 DB 에 연결하는 단위 테스트 금지 — `@pytest.mark.integration` 으로 분리
- `async def` 테스트에 `@pytest.mark.asyncio` 빠뜨리기 (또는 `asyncio_mode = "auto"` 설정)

---

## Multi-Service Patterns (uv Workspace)

### pyproject.toml (workspace root)
```toml
[project]
name = "my-app"
version = "0.1.0"
requires-python = ">=3.11"

[tool.uv.workspace]
members = ["services/api", "services/worker", "packages/shared"]

[tool.uv.sources]
shared = { workspace = true }

[dependency-groups]
dev = ["pytest>=8.3", "ruff>=0.7", "mypy>=1.13"]
```

### services/api/pyproject.toml
```toml
[project]
name = "api"
version = "0.1.0"
requires-python = ">=3.11"
dependencies = [
    "shared",
    "fastapi>=0.115",
    "sqlalchemy[asyncio]>=2.0",
    "uvicorn[standard]>=0.32",
]
```

### packages/shared/pyproject.toml
```toml
[project]
name = "shared"
version = "0.1.0"
requires-python = ">=3.11"
dependencies = ["pydantic>=2.9"]

[build-system]
requires = ["hatchling"]
build-backend = "hatchling.build"

[tool.hatch.build.targets.wheel]
packages = ["src/shared"]
```

### 공유 도메인 (packages/shared/src/shared/)
```python
# packages/shared/src/shared/types.py
from typing import NewType

UserId = NewType("UserId", int)
OrderId = NewType("OrderId", int)


# packages/shared/src/shared/events.py
from pydantic import BaseModel


class DomainEvent(BaseModel):
    event_type: str
    occurred_at: str
```

### 서비스에서 공유 패키지 사용
```python
# services/api/app/models/order.py
from shared.types import OrderId, UserId  # 워크스페이스 임포트


class Order(Base):
    id: Mapped[OrderId] = mapped_column(primary_key=True)
    user_id: Mapped[UserId] = mapped_column(index=True)
```

### 의존 규칙
| 모듈 | 의존 가능 | 의존 불가 |
|------|----------|----------|
| `packages/shared` | (없음 — 순수 타입·이벤트) | services/* |
| `services/api` | `shared` | `services/worker` |
| `services/worker` | `shared` | `services/api` |

### Workspace 명령
```bash
# 워크스페이스 루트에서
uv sync                                    # 모든 멤버 동기화
uv run --directory services/api pytest     # 특정 멤버 테스트
uv run --directory services/api uvicorn app.main:app --reload

# ruff / mypy — 루트에서 한 번에
uv run ruff check .
uv run mypy services packages
```
