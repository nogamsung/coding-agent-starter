#!/bin/bash
# .claude/hooks/model-router.sh — subagent 모델·강도 라우팅 (Claude Agent|Task · Codex spawn_agent 공용)
#
# 기본 꺼짐(opt-in). 켜기: .claude/stacks.json 에 {"harness": {"modelRouter": "log" | "apply"}} + TYPESAFE_API_KEY.
#   (env MODEL_ROUTER=log|apply 가 우선) 판정·기록은 .claude/scripts/agent-router.py.
# 꺼져 있으면 python 을 띄우기 전에 즉시 종료한다. 어떤 오류든 원래 호출을 그대로 둔다(항상 exit 0).
# 사용: model-router.sh [claude|codex]
ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
STACKS="$ROOT/.claude/stacks.json"
MODE="${MODEL_ROUTER:-}"
if [ -z "$MODE" ]; then
  [ -f "$STACKS" ] || exit 0
  command -v jq &>/dev/null || exit 0
  MODE=$(jq -r '.harness.modelRouter // "off"' "$STACKS" 2>/dev/null)
fi
case "$MODE" in log|apply) ;; *) exit 0 ;; esac
[ -f "$ROOT/.claude/scripts/agent-router.py" ] || exit 0
command -v python3 &>/dev/null || exit 0
python3 "$ROOT/.claude/scripts/agent-router.py" "${1:-claude}" 2>/dev/null
exit 0
