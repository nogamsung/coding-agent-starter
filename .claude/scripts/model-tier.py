#!/usr/bin/env python3
""".claude/scripts/model-tier.py — 작업 설명을 보고 필요한 모델 등급(high·mid·low)을 TypeSafe Jev 로 판단

stdin  : {"role": "...", "task": "...", "detail": "...", "files": [...]}  (모두 선택)
stdout : {"tier": "high|mid|low|null", "difficulty": 0~3, "difficulty_conf": 0~1, "risk": 0~1, "source": "..."}

Jev 는 판단(난이도·고위험 여부)만 한다. 등급은 아래 decide() 의 규칙이 정한다 — 바꾸려면 여기를 고친다.
키(TYPESAFE_API_KEY)가 없거나 4초 안에 답이 없거나 오류면 tier=null — 호출한 쪽은 원래 모델을 쓴다.
"""
import json
import os
import sys
import urllib.request

API = os.environ.get("TYPESAFE_API_URL", "https://api.typesafe.ai/v1/systemone")  # 테스트 때만 바꾼다
TIMEOUT = 4

QUESTIONS = {
    "difficulty": {
        "type": "score",
        "instructions": "이 코딩 작업을 해내려면 얼마나 깊은 추론이 필요한가? `task` 와 `detail` 은 에이전트에게 맡길 작업 지시이고, `role` 은 그 에이전트의 역할이다.",
        "criteria": [
            "기계적 작업 — 이름·문구 바꾸기, 정해진 형식 그대로 옮기기, 파일 찾기·읽고 요약하기",
            "정해진 패턴을 따르는 일반 구현·테스트 — 기존 코드와 같은 모양으로 한 곳을 추가하거나 고친다",
            "여러 모듈·스택에 걸친 변경이나 기존 동작을 깨지 않게 맞춰야 하는 리팩토링, 꼼꼼한 코드 리뷰",
            "설계 판단이 필요하거나 원인을 모르는 버그 추적, 보안 감사, 동시성·데이터 정합성 문제",
        ],
    },
    "risk": {
        "type": "noul",
        "instructions": "이 작업이 실수하면 피해가 큰 영역을 건드리는가?",
        "criteria": {
            "true": "인증·권한·세션, DB 마이그레이션·데이터 삭제·스키마 변경, 결제·과금, 시크릿·보안 설정, 운영 배포·CI 권한 중 하나 이상을 다룬다",
            "false": "위 영역을 다루지 않는다 — 화면·문구·일반 기능·테스트·문서·조회",
        },
    },
}


def _repo_hint():
    """.claude/stacks.json 이 있으면 스택 요약 한 줄 (판단 맥락용). 없으면 빈 문자열."""
    try:
        root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
        with open(os.path.join(root, ".claude", "stacks.json"), encoding="utf-8") as f:
            data = json.load(f)
        stacks = data.get("stacks") or [{"type": data.get("type") or data.get("mode")}]
        return "스택: " + ", ".join(filter(None, (f"{s.get('role', '')}={s.get('type', '')}".strip("=") for s in stacks)))
    except Exception:
        return ""


def decide(diff: float, diff_conf: float, risk: float):
    if risk >= 0.5:
        return "high"
    if diff_conf < 0.4:
        return None  # 확신이 없으면 원래 모델을 둔다
    if diff >= 2.0:
        return "high"
    if diff <= 0.7 and risk < 0.2:
        return "low"
    return "mid"


def main() -> int:
    try:
        state = json.load(sys.stdin)
    except Exception:
        state = {}
    key = os.environ.get("TYPESAFE_API_KEY")
    if not key:
        print(json.dumps({"tier": None, "source": "no-key"}))
        return 0
    for k in ("task", "detail"):
        if isinstance(state.get(k), str):
            state[k] = state[k][:6000]
    repo = os.environ.get("MODEL_ROUTER_REPO_HINT") or _repo_hint()
    if repo:
        state["repo"] = repo
    body = json.dumps({"model": "jev-latest", "state": state, "questions": QUESTIONS}, ensure_ascii=False).encode()
    req = urllib.request.Request(API, data=body, headers={"Authorization": f"Bearer {key}", "Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=TIMEOUT) as r:
            ans = json.load(r)["answers"]
        diff = float(ans["difficulty"]["score"])
        conf = float(ans["difficulty"].get("confidence", 0))
        risk = float(ans["risk"]["noul"])
    except Exception as e:
        print(json.dumps({"tier": None, "source": f"error: {type(e).__name__}"}))
        return 0
    print(json.dumps({"tier": decide(diff, conf, risk), "difficulty": round(diff, 2),
                      "difficulty_conf": round(conf, 2), "risk": round(risk, 2), "source": "jev"}))
    return 0


if __name__ == "__main__":
    sys.exit(main())
