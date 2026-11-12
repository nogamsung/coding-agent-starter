---
name: ai-patterns
description: AI/ML 코드 패턴 — LLM 호출·RAG chain·프롬프트·임베딩·PyTorch·HuggingFace (FastAPI embedded). AI 코드를 만들거나 고칠 때 참고.
---

# AI/ML Patterns (FastAPI embedded)

AI/ML 코드 작성 시 따를 **구조·프레임워크·규칙**. ai-generator / ai-modifier / ai-tester 가 참조.

## 전제

- **언어**: Python 3.11+
- **스택**: FastAPI + SQLAlchemy 2.0 async + Pydantic v2 + uv
- **AI 코드 위치**: FastAPI 서비스 **내부**에 embedded (별도 service X)
- **협업**: python-generator 와 영역 분리 (자세히 아래)

## 디렉토리 구조

```
app/
├── ml/                       # ai-generator / ai-modifier 영역
│   ├── __init__.py
│   ├── llm_client.py         # Anthropic/OpenAI SDK 통합 wrapper
│   ├── tasks/                # 비즈니스 로직 (요약, 분류, 생성 등)
│   │   └── summarize.py
│   ├── models/               # PyTorch nn.Module 정의 (훈련용)
│   │   └── my_classifier.py
│   ├── training/             # 훈련 스크립트 (프로덕션 import 금지)
│   │   ├── train_classifier.py
│   │   └── dataset.py
│   ├── inference/            # 사전 훈련 모델 추론 wrapper
│   │   └── classifier.py
│   └── evaluation/
│       └── metrics.py
├── chains/                   # LangChain LCEL 체인
│   └── qa.py
├── prompts/                  # 프롬프트 템플릿 (코드와 분리)
│   ├── summarize.py
│   └── qa.py
├── embeddings/               # pgvector 관련
│   ├── client.py             # 임베딩 모델 호출
│   ├── retriever.py          # LangChain retriever
│   └── store.py              # 저장·검색 (SQLAlchemy + pgvector)
│
│── (아래는 python-generator 영역 — ai-* 는 수정 금지)
├── models/                   # SQLAlchemy ORM
├── schemas/                  # Pydantic schema
├── repositories/
├── services/
├── routers/
└── exceptions.py

tests/
├── ml/                       # app/ml/ 테스트 (ai-tester)
├── chains/
├── prompts/
├── embeddings/
└── fixtures/
    └── ml.py                 # mock_claude 등 공용 fixture
```

## 지원 프레임워크 + 핵심 패턴

### 1. Anthropic SDK (Claude)

**설치**: `anthropic>=0.40`

**클라이언트 초기화** (`app/ml/llm_client.py`):
```python
from anthropic import AsyncAnthropic
from app.core.config import settings

_anthropic = AsyncAnthropic(api_key=settings.ANTHROPIC_API_KEY)

async def claude_chat(
    messages: list[dict],
    model: str = "claude-opus-4-7",
    max_tokens: int = 4096,
    system: str | None = None,
) -> str:
    kwargs = {"model": model, "messages": messages, "max_tokens": max_tokens}
    if system:
        kwargs["system"] = system
    response = await _anthropic.messages.create(**kwargs)
    return response.content[0].text
```

**Prompt caching** (긴 시스템 프롬프트 비용 절감):
```python
system = [
    {"type": "text", "text": SYSTEM_PROMPT, "cache_control": {"type": "ephemeral"}},
]
```

**Streaming** (UX 개선):
```python
async with _anthropic.messages.stream(model=model, messages=messages, max_tokens=...) as stream:
    async for text in stream.text_stream:
        yield text
```

**Tool use** (function calling):
```python
tools = [{"name": "get_weather", "description": "...", "input_schema": {...}}]
response = await _anthropic.messages.create(model=model, messages=..., tools=tools)
```

### 2. OpenAI SDK

**설치**: `openai>=1.50`

```python
from openai import AsyncOpenAI
_openai = AsyncOpenAI(api_key=settings.OPENAI_API_KEY)

async def gpt_chat(messages: list[dict], model: str = "gpt-4o") -> str:
    response = await _openai.chat.completions.create(
        model=model, messages=messages, temperature=0.7,
    )
    return response.choices[0].message.content
```

**Embedding**:
```python
async def embed(text: str) -> list[float]:
    response = await _openai.embeddings.create(
        model="text-embedding-3-small", input=text,
    )
    return response.data[0].embedding
```

### 3. LangChain (LCEL)

**설치**: `langchain>=0.3 langchain-anthropic langchain-openai langchain-community`

**LCEL 기본 패턴** (runnable composition):
```python
from langchain_anthropic import ChatAnthropic
from langchain_core.prompts import ChatPromptTemplate
from langchain_core.output_parsers import StrOutputParser

llm = ChatAnthropic(model="claude-opus-4-7")
prompt = ChatPromptTemplate.from_messages([
    ("system", "너는 요약 전문가야."),
    ("human", "{text}"),
])
chain = prompt | llm | StrOutputParser()

result = await chain.ainvoke({"text": "긴 원문"})
```

**RAG chain** (retriever + generator):
```python
from langchain_core.runnables import RunnablePassthrough
from app.embeddings.retriever import get_retriever

def build_rag_chain():
    retriever = get_retriever()
    rag_prompt = ChatPromptTemplate.from_template(
        "다음 문서를 참고해서 답해줘:\n{context}\n\n질문: {question}"
    )
    return (
        {"context": retriever, "question": RunnablePassthrough()}
        | rag_prompt
        | llm
        | StrOutputParser()
    )
```

### 4. PyTorch

**설치**: `torch>=2.3`

**모델 정의** (`app/ml/models/classifier.py`):
```python
import torch
import torch.nn as nn

class TextClassifier(nn.Module):
    def __init__(self, vocab_size: int, embed_dim: int = 128, num_classes: int = 2):
        super().__init__()
        self.embedding = nn.Embedding(vocab_size, embed_dim)
        self.fc = nn.Linear(embed_dim, num_classes)

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        embedded = self.embedding(x).mean(dim=1)
        return self.fc(embedded)
```

**훈련 루프** (`app/ml/training/train_classifier.py`):
```python
import torch
import mlflow
from torch.utils.data import DataLoader
from app.ml.models.classifier import TextClassifier

def train(data_path: str, output_dir: str, epochs: int = 10, batch_size: int = 32, lr: float = 1e-4):
    torch.manual_seed(42)
    device = "cuda" if torch.cuda.is_available() else "cpu"

    model = TextClassifier(vocab_size=30000).to(device)
    optimizer = torch.optim.Adam(model.parameters(), lr=lr)
    loss_fn = torch.nn.CrossEntropyLoss()

    dataset = ...  # 별도 dataset.py
    loader = DataLoader(dataset, batch_size=batch_size, shuffle=True)

    with mlflow.start_run():
        mlflow.log_params({"epochs": epochs, "batch_size": batch_size, "lr": lr})
        for epoch in range(epochs):
            total_loss = 0.0
            for batch in loader:
                x, y = batch["input_ids"].to(device), batch["labels"].to(device)
                optimizer.zero_grad()
                logits = model(x)
                loss = loss_fn(logits, y)
                loss.backward()
                optimizer.step()
                total_loss += loss.item()
            mlflow.log_metric("loss", total_loss / len(loader), step=epoch)

        mlflow.pytorch.log_model(model, "model")
        torch.save(model.state_dict(), f"{output_dir}/model.pt")

    return {"status": "ok"}
```

**추론** (`app/ml/inference/classifier.py`):
```python
import torch
from app.ml.models.classifier import TextClassifier

_model: TextClassifier | None = None

def _load_model() -> TextClassifier:
    global _model
    if _model is None:
        _model = TextClassifier(vocab_size=30000)
        _model.load_state_dict(torch.load("models/classifier.pt", map_location="cpu"))
        _model.eval()
    return _model

@torch.inference_mode()
def predict(text_ids: torch.Tensor) -> dict:
    model = _load_model()
    logits = model(text_ids)
    probs = torch.softmax(logits, dim=-1)[0]
    return {"label": int(probs.argmax()), "confidence": float(probs.max())}
```

### 5. scikit-learn (전통 ML)

**설치**: `scikit-learn>=1.5`

**훈련 + 저장**:
```python
from sklearn.ensemble import RandomForestClassifier
from sklearn.model_selection import train_test_split
import joblib
import mlflow

def train(X, y, output_path: str):
    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)
    model = RandomForestClassifier(n_estimators=100, random_state=42)
    model.fit(X_train, y_train)

    with mlflow.start_run():
        mlflow.log_metric("train_score", model.score(X_train, y_train))
        mlflow.log_metric("test_score", model.score(X_test, y_test))
        mlflow.sklearn.log_model(model, "model")

    joblib.dump(model, output_path)
```

### 6. HuggingFace Transformers

**설치**: `transformers>=4.44 accelerate datasets`

**사전 훈련 모델 추론**:
```python
from transformers import AutoTokenizer, AutoModelForSequenceClassification
import torch

_MODEL_ID = "klue/bert-base"
_tokenizer = AutoTokenizer.from_pretrained(_MODEL_ID)
_model = AutoModelForSequenceClassification.from_pretrained(_MODEL_ID, num_labels=2)
_model.eval()

@torch.inference_mode()
def classify(text: str) -> dict:
    inputs = _tokenizer(text, return_tensors="pt", truncation=True, max_length=512, padding=True)
    logits = _model(**inputs).logits
    probs = torch.softmax(logits, dim=-1)[0]
    return {"label": int(probs.argmax()), "confidence": float(probs.max())}
```

**Fine-tuning** (Trainer API):
```python
from transformers import Trainer, TrainingArguments

training_args = TrainingArguments(
    output_dir="./finetune",
    num_train_epochs=3,
    per_device_train_batch_size=16,
    learning_rate=2e-5,
    eval_strategy="epoch",
    save_strategy="epoch",
    load_best_model_at_end=True,
    report_to=["mlflow"],
)

trainer = Trainer(model=_model, args=training_args, train_dataset=..., eval_dataset=...)
trainer.train()
```

### 7. pgvector (Vector DB on Postgres)

**설치**: `pgvector>=0.3` + Postgres 확장 `CREATE EXTENSION vector`

**SQLAlchemy Model** (python-generator 가 생성):
```python
# app/models/document.py (python-generator)
from sqlalchemy.orm import Mapped, mapped_column
from pgvector.sqlalchemy import Vector

class Document(Base):
    __tablename__ = "documents"
    id: Mapped[int] = mapped_column(primary_key=True)
    text: Mapped[str] = mapped_column(Text)
    embedding: Mapped[list[float]] = mapped_column(Vector(1536))  # OpenAI embedding dim
```

**Alembic migration** (python-generator 영역):
```python
# alembic upgrade 에 인덱스 생성
op.execute("CREATE INDEX idx_documents_embedding ON documents USING hnsw (embedding vector_cosine_ops)")
```

**저장·검색** (ai-generator 가 작성, `app/embeddings/store.py`):
```python
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from app.models.document import Document
from app.embeddings.client import embed

async def store_document(db: AsyncSession, text: str) -> int:
    vec = await embed(text)
    doc = Document(text=text, embedding=vec)
    db.add(doc)
    await db.commit()
    return doc.id

async def search_similar(db: AsyncSession, query: str, k: int = 5) -> list[Document]:
    query_vec = await embed(query)
    stmt = (
        select(Document)
        .order_by(Document.embedding.cosine_distance(query_vec))
        .limit(k)
    )
    result = await db.execute(stmt)
    return list(result.scalars().all())
```

### 8. MLflow (실험 추적)

**설치**: `mlflow>=2.16`

**로컬 tracking server** (개발):
```bash
mlflow ui --host 0.0.0.0 --port 5000
# 기본: http://localhost:5000
```

**코드에서**:
```python
import mlflow

mlflow.set_tracking_uri("http://localhost:5000")  # 또는 settings.MLFLOW_URI
mlflow.set_experiment("my-classifier")

with mlflow.start_run():
    mlflow.log_params({"lr": 1e-4, "batch_size": 32})
    mlflow.log_metric("accuracy", 0.92, step=epoch)
    mlflow.log_artifact("confusion_matrix.png")
    mlflow.pytorch.log_model(model, "model")
    mlflow.set_tag("dataset_version", "v1.2")
```

**Auto-logging** (PyTorch/sklearn 지원):
```python
mlflow.pytorch.autolog()    # 훈련 루프에서 loss, model 자동 기록
mlflow.sklearn.autolog()
```

## 협업 프로토콜 (ai-* ↔ python-*)

### ai-generator → python-generator 요청 형식

```markdown
## python-generator 에게 요청

**필요한 Router:**
- `POST /api/v1/summarize`
  - Request: `SummarizeRequest { text: str, max_length: int = 200 }`
  - Response: `SummarizeResponse { summary: str }`
  - Service 는 `app.ml.tasks.summarize:summarize_text` 호출

**필요한 Schema:**
- `app/schemas/summarize.py` — SummarizeRequest, SummarizeResponse

**필요한 Service:**
- `app/services/summarize_service.py` — Router ↔ ml.tasks 연결

**신규 DB 테이블:**
- (없음 / 또는 Document 테이블, embedding Vector(1536) 컬럼)

**신규 Alembic migration:**
- (없음 / 또는 create_documents + pgvector extension)

**환경 변수 (.env.example):**
- ANTHROPIC_API_KEY=
```

### python-generator → ai-generator 요청 형식

```markdown
## ai-generator 에게 요청

**필요한 AI 기능:**
- 기능: "사용자 리뷰를 긍정/부정 분류"
- 입력: str
- 출력: { label: "positive" | "negative", confidence: float }
- 제약: latency p50 < 500ms, 무료 또는 저비용

**권장 접근:**
- HuggingFace 한국어 sentiment model (klue/bert-base-sentiment 등)
- 또는 Claude Haiku few-shot

**필요한 파일:**
- `app/ml/inference/sentiment.py` — classify(text: str) -> dict
```

## 환경 변수 (.env.example 권장 값)

```bash
# LLM SDK
ANTHROPIC_API_KEY=sk-ant-...
OPENAI_API_KEY=sk-...

# HuggingFace (private model 사용 시)
HF_TOKEN=hf_...
HF_HOME=/path/to/cache  # 컨테이너 캐시 공유

# MLflow
MLFLOW_TRACKING_URI=http://localhost:5000

# pgvector (기존 DATABASE_URL 재사용)
DATABASE_URL=postgresql+asyncpg://user:pass@localhost/db
```

## pyproject.toml 권장 dependencies 구조

```toml
[project]
dependencies = [
    "fastapi>=0.115",
    "sqlalchemy[asyncio]>=2.0",
    "pydantic>=2.8",
    # ... (python-generator 가 관리)
]

[project.optional-dependencies]
ai = [
    # LLM SDK
    "anthropic>=0.40",
    "openai>=1.50",
    # Orchestration
    "langchain>=0.3",
    "langchain-anthropic>=0.2",
    "langchain-openai>=0.2",
    # Vector DB
    "pgvector>=0.3",
    # ML training
    "torch>=2.3",
    "transformers>=4.44",
    "accelerate>=0.30",
    "datasets>=2.20",
    "scikit-learn>=1.5",
    # Experiment tracking
    "mlflow>=2.16",
]
```

설치: `uv sync --extra ai`

## gitignore 추가 권장

```gitignore
# ML 아티팩트
*.pt
*.safetensors
*.bin
*.onnx
mlruns/
models/cache/
*.ipynb_checkpoints

# HuggingFace 캐시
.cache/huggingface/
```

## 테스트 전략 요약 (ai-tester 상세는 해당 agent 참조)

- **단위 테스트 (기본)**: LLM 호출은 `AsyncMock` 으로 모킹. 비용·재현성.
- **Integration 테스트**: `@pytest.mark.integration` 로 분리. 실제 API 호출은 별도 실행.
- **평가 (evaluation)**: `@pytest.mark.integration` + parametrize. 프롬프트·모델 품질 회귀 방지.
- **GPU 테스트**: `@pytest.mark.gpu` 마커. CI 에서 `-m "not gpu"` 로 skip.

## 핵심 규칙 요약

✅ **MUST**
- 모든 LLM 호출 `async`
- 싱글톤 클라이언트 재사용 (`_anthropic = AsyncAnthropic(...)` 모듈 레벨)
- 타입 힌트 + `mypy --strict` 통과
- 프롬프트는 `app/prompts/` 별도 파일
- 환경 변수는 `settings.ANTHROPIC_API_KEY` 형태 (Pydantic Settings)
- 비용·토큰 로깅 (MLflow 또는 custom logger)

❌ **NEVER**
- `app/routers/` 에 AI 로직 (python-generator 영역)
- SQLAlchemy Model 직접 생성 (python-generator 에게)
- 프롬프트를 코드에 하드코딩 (긴 프롬프트)
- 모델 파일 `.pt`/`.safetensors` 를 git 에 커밋
- 실제 LLM API 호출하는 unit test
- `os.environ["ANTHROPIC_API_KEY"]` 직접 호출 — `settings` 경유
