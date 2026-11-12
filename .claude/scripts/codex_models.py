""".claude/scripts/codex_models.py — Claude model 별칭 ↔ Codex 모델 계열, 계열의 최신 모델 찾기

Codex 는 별칭이 없다 — `terra` 같은 이름은 `model_not_found` 로 거절되고 `gpt-6.1-terra` 처럼 정확한
슬러그만 받는다(2026-10-27 실측, codex 0.164.0). 그래서 설정 원본(.claude/agents/*.md)에는 Claude 별칭만 두고,
Codex 쪽 슬러그는 이 모듈이 계정 모델 카탈로그 캐시($CODEX_HOME/models_cache.json — Codex 가 /models 응답을
저장해 둔 것)에서 같은 계열의 가장 높은 버전을 골라 준다. 캐시가 없으면 호출한 쪽이 넘긴 현재 값이나 FALLBACK.
gen-codex-agents.py(생성 시점)와 agent-router.py(spawn 훅)가 같이 쓴다.
"""
import json
import os
import pathlib
import re

# Claude 별칭 → Codex 계열. 위에서 아래로 같은 사다리.
FAMILIES = {"fable": "astra", "opus": "sol", "sonnet": "terra", "haiku": "luna"}
# 캐시도 현재 값도 없을 때만. 모델이 은퇴하면 여기만 고친다.
FALLBACK = {"astra": "gpt-6-astra", "sol": "gpt-6.1-sol", "terra": "gpt-6.1-terra", "luna": "gpt-6-luna"}
SLUG = re.compile(r"^gpt-(\d+(?:\.\d+)*)-([a-z]+)$")


def catalog():
    """계정에서 고를 수 있는 모델 슬러그 목록(visibility=list). 캐시가 없으면 빈 목록."""
    home = pathlib.Path(os.environ.get("CODEX_HOME") or pathlib.Path.home() / ".codex")
    try:
        data = json.loads((home / "models_cache.json").read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return []
    found = []

    def walk(node):
        if isinstance(node, dict):
            if isinstance(node.get("slug"), str) and node.get("visibility", "list") == "list":
                found.append(node["slug"])
            for value in node.values():
                walk(value)
        elif isinstance(node, list):
            for value in node:
                walk(value)

    walk(data)
    return found


def family_of(slug):
    match = SLUG.match(slug or "")
    return match.group(2) if match else None


def newest(family, slugs=None, current=None):
    """계열의 최신 슬러그. 환경변수 CODEX_MODEL_<FAMILY> > 카탈로그 최신 > 같은 계열의 current > FALLBACK."""
    override = os.environ.get(f"CODEX_MODEL_{family.upper()}")
    if override:
        return override
    versions = []
    for slug in catalog() if slugs is None else slugs:
        match = SLUG.match(slug)
        if match and match.group(2) == family:
            versions.append((tuple(int(p) for p in match.group(1).split(".")), slug))
    if versions:
        return max(versions)[1]
    if current and family_of(current) == family:
        return current
    return FALLBACK.get(family)
