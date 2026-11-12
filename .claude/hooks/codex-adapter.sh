#!/bin/bash
# .claude/hooks/codex-adapter.sh — Codex 훅(.codex/hooks.json) 진입점
#
# Codex 훅은 Claude 훅과 형식이 거의 같다(이벤트 이름·stdin JSON·exit 2 차단). 다른 점은 파일 편집이
# Edit/Write 가 아니라 apply_patch 하나이고, 대상 경로가 tool_input.file_path 가 아니라 패치 본문
# ("*** Update File: <경로>" 줄)에 있다는 것뿐이다. 이 스크립트가 그 차이만 메우고 판정은
# 기존 Claude 훅(.claude/hooks/*.sh)에 그대로 맡긴다 — 규칙은 한 벌.
#
# 사용 (.codex/hooks.json):
#   codex-adapter.sh pre-edit       PreToolUse(apply_patch)  → worktree-guard.sh 를 파일마다
#   codex-adapter.sh post-edit      PostToolUse(apply_patch) → post-edit-lint.sh 를 파일마다
#   codex-adapter.sh session-start  SessionStart             → session-start.sh + memory/MEMORY.md
# .claude/stacks.json 이 없거나 대상 훅이 없으면 조용히 통과(exit 0).

MODE="$1"
INPUT=$(cat 2>/dev/null || echo '{}')
# 패치 경로는 세션 작업 디렉토리 기준 — 그 자리에서 판정한다
CWD=$(printf '%s' "$INPUT" | python3 -c 'import json, sys; print(json.load(sys.stdin).get("cwd") or "")' 2>/dev/null)
[ -n "$CWD" ] && [ -d "$CWD" ] && cd "$CWD"
ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
HOOKS="$ROOT/.claude/hooks"
[ -f "$ROOT/.claude/stacks.json" ] || exit 0
command -v python3 &>/dev/null || exit 0

# apply_patch 본문에서 편집 대상 경로를 한 줄에 하나씩 (Add·Update·Delete·Move to)
patch_files() {
  printf '%s' "$INPUT" | python3 -c '
import json, re, sys
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)
ti = d.get("tool_input") or {}
body = ti.get("command") or ti.get("input") or ti.get("patch") or ""
if isinstance(body, list):
    body = "\n".join(map(str, body))
for m in re.finditer(r"^\*\*\* (?:Add File|Update File|Delete File|Move to): (.+?)\s*$", body, re.M):
    print(m.group(1))
' 2>/dev/null
}

# 기존 훅이 읽는 Claude 형식으로 바꿔 넘긴다
as_claude_input() {
  python3 -c 'import json, sys; print(json.dumps({"tool_input": {"file_path": sys.argv[1]}}))' "$1"
}

case "$MODE" in
  pre-edit)
    RC=0
    while IFS= read -r F; do
      [ -z "$F" ] && continue
      [ -f "$HOOKS/worktree-guard.sh" ] || break
      as_claude_input "$F" | bash "$HOOKS/worktree-guard.sh" || RC=$?
      [ $RC -eq 2 ] && exit 2
    done < <(patch_files)
    exit 0
    ;;
  post-edit)
    # Codex 는 PostToolUse 의 일반 stdout 을 버린다 — lint 결과는 additionalContext 로 돌려줘야 모델이 본다
    LINT=$(while IFS= read -r F; do
      [ -z "$F" ] && continue
      [ -f "$HOOKS/post-edit-lint.sh" ] || break
      as_claude_input "$F" | bash "$HOOKS/post-edit-lint.sh" 2>&1
    done < <(patch_files))
    [ -n "$LINT" ] && printf '%s' "$LINT" | python3 -c '
import json, sys
print(json.dumps({"hookSpecificOutput": {"hookEventName": "PostToolUse", "additionalContext": sys.stdin.read()}}, ensure_ascii=False))'
    exit 0
    ;;
  session-start)
    # Codex 는 stdout 이 '[' 나 '{' 로 시작하면 JSON 으로 읽는다 — "[Context] …" 가 그대로 나가면
    # "invalid session start JSON output" 으로 실패하고 컨텍스트가 통째로 버려진다. 항상 JSON 으로 감싼다
    CTX=$(
      # session-start.sh 는 루트 상대경로(.claude/stacks.json 등)를 본다 — 하위 디렉토리에서 시작해도 루트에서
      [ -f "$HOOKS/session-start.sh" ] && (cd "$ROOT" && bash "$HOOKS/session-start.sh" </dev/null 2>&1 | tail -40)
      # 프로젝트 메모리 = 저장소 memory/ (worktree 면 허브 기준, Claude 와 공용). Claude 는 자동 로드하지만 Codex 는 여기서 넣어 준다.
      COMMON=$(cd "$(git rev-parse --git-common-dir 2>/dev/null)" 2>/dev/null && pwd)
      MEM="$ROOT/memory"
      [ -n "$COMMON" ] && [ -f "$(dirname "$COMMON")/memory/MEMORY.md" ] && MEM="$(dirname "$COMMON")/memory"
      if [ -f "$MEM/MEMORY.md" ]; then
        echo "[Memory] 프로젝트 메모리 = $MEM — 관련 항목은 파일을 직접 읽어라. 새 기억은 같은 형식(파일 하나 + 인덱스 한 줄)으로 남긴다 (.agents/skills/memory/SKILL.md)."
        head -150 "$MEM/MEMORY.md"
      fi
    )
    printf '%s' "$CTX" | python3 -c '
import json, sys
print(json.dumps({"hookSpecificOutput": {"hookEventName": "SessionStart", "additionalContext": sys.stdin.read()}}, ensure_ascii=False))'
    exit 0
    ;;
  *)
    echo "[codex-adapter] 알 수 없는 모드: $MODE" >&2
    exit 0
    ;;
esac
