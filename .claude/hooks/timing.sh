#!/bin/bash
# .claude/hooks/timing.sh — 개발 루프 단계별 소요 시간 기록 (source 해서 쓴다)
#
#   source .claude/hooks/timing.sh
#   T0=$(date +%s); ...; timing_log pre-push:backend "$T0" $?
#
# <git-common-dir>/coding-agent-timing.jsonl 에 한 줄씩 쌓인다 — 모든 worktree 공용, git 이 추적하지 않음.
# 어디가 느린지 숫자로 보기:
#   jq -s 'group_by(.step) | map({step: .[0].step, n: length, avg_sec: (map(.sec) | add / length | floor)})' \
#     "$(git rev-parse --path-format=absolute --git-common-dir)/coding-agent-timing.jsonl"
# jq 가 없으면 조용히 기록하지 않는다.

timing_log() {
  local step="$1" start="$2" code="${3:-0}" dir
  command -v jq &>/dev/null || return 0
  dir="$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null)" || return 0
  [ -n "$dir" ] || return 0
  jq -nc --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --arg step "$step" --argjson sec $(( $(date +%s) - start )) \
    --argjson exit "$code" --arg branch "$(git branch --show-current 2>/dev/null)" \
    '{ts: $ts, step: $step, sec: $sec, exit: $exit, branch: $branch}' >>"$dir/coding-agent-timing.jsonl" 2>/dev/null || true
}
