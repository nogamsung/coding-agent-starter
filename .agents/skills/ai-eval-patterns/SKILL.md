---
name: ai-eval-patterns
description: LLM/RAG 응답 회귀 테스트 — golden snapshot · LLM-as-judge · 메트릭 eval · pytest 통합 · CI 정책.
---

# AI Eval & Regression Patterns

LLM 출력은 비결정적이라 단순 `assert response == expected` 가 안 통함. 회귀 검증의 4가지 layer.

## 1. Golden Snapshot

입력 → **합의된** 기대 출력 페어를 저장하고 diff 로 회귀 감지. 모델/프롬프트 변경 시 사람이 검토 후 갱신.

```
tests/
├── fixtures/
│   └── prompts/
│       ├── classify_intent_simple.json    # 입력
│       └── classify_intent_simple.golden  # 기대 출력
└── test_eval.py
```

### pytest 통합

```python
# tests/conftest.py
import json
from pathlib import Path
import pytest

GOLDEN_DIR = Path(__file__).parent / "fixtures" / "prompts"

@pytest.fixture
def golden(request):
    """golden('classify_intent_simple') -> (input_dict, expected_str)"""
    name = request.param if hasattr(request, "param") else None
    def _load(case_name):
        with open(GOLDEN_DIR / f"{case_name}.json") as f:
            inp = json.load(f)
        with open(GOLDEN_DIR / f"{case_name}.golden") as f:
            expected = f.read().strip()
        return inp, expected
    return _load
```

```python
# tests/test_eval.py
import os
from app.chains.classify import classify_intent

GOLDENS = ["classify_intent_simple", "classify_intent_ambiguous"]

@pytest.mark.parametrize("case", GOLDENS)
def test_classify_golden(case, golden):
    inp, expected = golden(case)
    actual = classify_intent(**inp).strip()

    if os.getenv("UPDATE_GOLDEN") == "1":
        # snapshot 갱신 모드
        (GOLDEN_DIR / f"{case}.golden").write_text(actual)
    else:
        assert actual == expected, f"\nexpected:\n{expected}\n\nactual:\n{actual}"
```

```bash
# 회귀 검증
pytest tests/test_eval.py

# 의도된 변경 후 snapshot 갱신
UPDATE_GOLDEN=1 pytest tests/test_eval.py
git diff tests/fixtures/prompts/  # 변경 검토 후 commit
```

**규칙**: golden 파일 변경은 **항상 PR 에 포함** + 리뷰어가 의미 검증. 자동 갱신 후 검토 없이 머지 금지.

## 2. LLM-as-Judge

기대 출력이 **정확히 한 문자열이 아닐 때** (요약, 답변 형식 자유 등) — 별도 LLM 이 rubric 으로 채점.

```python
# tests/judges.py
from anthropic import Anthropic

JUDGE_PROMPT = """다음 응답이 rubric 을 만족하는지 1-5 로 채점하고 이유를 적어라.

# Rubric
{rubric}

# Question
{question}

# Response
{response}

JSON 형식으로 답해라: {{"score": <1-5>, "reason": "..."}}
"""

def judge(question: str, response: str, rubric: str, threshold: int = 4) -> bool:
    client = Anthropic()
    out = client.messages.create(
        model="claude-haiku-4-5",  # judge 는 빠르고 싼 모델
        max_tokens=500,
        messages=[{"role": "user", "content": JUDGE_PROMPT.format(
            rubric=rubric, question=question, response=response
        )}],
    )
    import json
    result = json.loads(out.content[0].text)
    return result["score"] >= threshold, result["reason"]
```

```python
def test_summary_quality():
    article = load_article("fixtures/article_long.txt")
    summary = summarize(article)

    rubric = """
    - 핵심 사실 3개 이상 포함
    - 200자 이내
    - 원문에 없는 정보 추가 금지
    """
    passed, reason = judge(article, summary, rubric)
    assert passed, reason
```

**규칙**: judge 모델은 **타겟 모델보다 작고 싼** 것 (haiku) 으로. 같은 모델로 자기 평가 = 가짜 합격 위험.

## 3. 메트릭 기반 (보조)

| 메트릭 | 용도 | 한계 |
|--------|------|------|
| BLEU / ROUGE | 번역·요약 lexical overlap | 의미 무시, 짧은 텍스트에 노이즈 |
| Embedding cosine | 의미 유사도 | "정반대 의미"도 높게 나올 수 있음 |
| Exact match | 분류·추출 | 자유 형식 답변엔 부적합 |

**단독 사용 금지** — 항상 golden 또는 judge 와 결합.

## 4. RAG 품질 평가

검색 + 생성 분리해서 평가:

```python
def test_rag_retrieval_recall():
    """질문 → 정답 문서가 top-k 안에 있는가"""
    for case in load_rag_eval_set():
        retrieved = retriever.search(case.question, k=5)
        assert case.expected_doc_id in [d.id for d in retrieved], \
            f"missed: {case.question}"

def test_rag_answer_grounding():
    """생성 답변이 retrieved 문서에만 근거하는가"""
    for case in load_rag_eval_set():
        retrieved = retriever.search(case.question, k=3)
        answer = generator.answer(case.question, retrieved)
        passed, reason = judge(
            case.question, answer,
            rubric=f"답변은 다음 문서에만 근거: {[d.text for d in retrieved]}",
        )
        assert passed, reason
```

## 5. CI 정책

| 검증 | 빈도 | 비용 |
|------|------|------|
| Golden snapshot (mocked LLM 호출) | PR 마다 | $0 |
| Golden snapshot (real LLM) | nightly | 낮음 |
| LLM-as-judge | nightly | 중간 |
| Full RAG eval set (100+ cases) | weekly | 높음 |

PR CI 는 mocked + golden 으로 빠르게. 실제 LLM 호출은 별도 스케줄.

```yaml
# .github/workflows/ai-eval.yml
on:
  schedule: [{ cron: '0 4 * * *' }]   # 매일 04:00
  workflow_dispatch:

jobs:
  eval:
    steps:
      - run: pytest tests/test_eval.py tests/test_rag_eval.py
        env:
          ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
```

## 6. 의식적 배제

- **`assert response == expected`** — 비결정적 출력에 부적절. golden + UPDATE_GOLDEN 패턴.
- **temperature=0 으로 결정성 강제** — 일부 모델만 지원, 같은 모델도 시간 지나면 미세 변동
- **자기 평가** (target = judge) — 가짜 합격
- **단일 케이스로 합격 판단** — 최소 5~10개 fixture, 다양성 확보
- **eval set 자동 생성 by LLM** — 노이즈 + 정답 편향. 사람이 큐레이션
- **mock 없이 매 PR 실 호출** — 비용 폭증 + flaky CI

## 7. 운영 체크리스트

- [ ] `tests/fixtures/prompts/` 에 ≥10 golden 케이스
- [ ] `UPDATE_GOLDEN=1` 으로 갱신 가능
- [ ] golden 갱신은 PR 에 포함 + 리뷰
- [ ] judge LLM 은 타겟보다 작고 싼 모델
- [ ] PR CI 는 mocked, real LLM 은 nightly
- [ ] eval set 은 사람 큐레이션 (LLM 자동 생성 X)
