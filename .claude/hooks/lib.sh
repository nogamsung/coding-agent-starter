#!/bin/bash
# .claude/hooks/lib.sh — 훅 공용 헬퍼 (Claude·Codex 공통). 직접 실행하지 않고 source 한다.
#
#   source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
#
# 제공:
#   ROOT                  git 최상위(worktree 루트) — git 밖이면 pwd
#   STACKS_FILE           $ROOT/.claude/stacks.json
#   have_stacks           stacks.json 있으면 0
#   harness_opt KEY DEF   stacks.json 의 .harness.KEY (없으면 DEF). 불리언은 true/false 로 출력
#   harness_on KEY DEF    harness_opt 값이 true/on/1/yes 면 0
#   base_branch           .harness.baseBranch → origin/dev 있으면 dev → main
#   base_ref              merge-base(origin/<base>, HEAD) — 실패하면 빈 문자열
#   git_common_dir        공유 .git 절대경로 (worktree 공용 상태 파일 위치)
#   is_hub                메인 체크아웃(허브)이면 0 — linked worktree 면 1
#   stacks_list           "type<TAB>path<TAB>name" 한 줄씩 (stacks[] — 없으면 .type/.path 단일 항목)
#   stack_for_file FILE   FILE(루트 상대·절대)이 속한 스택 "type<TAB>path" — 가장 긴 path 우선
#   changed_files [REF]   REF(기본 base_ref) 대비 바뀐 파일 + 추적 안 된 파일 (루트 상대)
#   hook_field EXPR       $INPUT(JSON) 에서 점 경로 값 (예: tool_input.command). 실패 시 빈 문자열
#   run_timeout S CMD...  GNU timeout 있으면 S 초 제한 (macOS 기본엔 없어 그냥 실행)
#
# stacks.json .harness 키 (기본값):
#   worktreeGuard=true stopTests=true buildGate=true coverage=90 memorySync="off"(off|link|commit)
#   memorySyncPush=false modelRouter="off" crossReview=true baseBranch=(자동)
#   gitHooks=false(true 면 session-start 가 core.hooksPath 자동 설정) telemetry=false

ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
STACKS_FILE="$ROOT/.claude/stacks.json"

have_stacks() { [ -f "$STACKS_FILE" ]; }

_json_query() { # _json_query <python 표현식 인자> — jq 없을 때 폴백용
  python3 - "$STACKS_FILE" "$@" 2>/dev/null <<'PY'
import json, sys
try:
    d = json.load(open(sys.argv[1]))
except Exception:
    sys.exit(0)
mode = sys.argv[2]
if mode == "opt":
    v = (d.get("harness") or {}).get(sys.argv[3])
    if v is None:
        sys.exit(0)
    print(str(v).lower() if isinstance(v, bool) else v)
elif mode == "stacks":
    stacks = d.get("stacks") or []
    if not stacks and d.get("type"):
        stacks = [{"type": d["type"], "path": d.get("path", ".")}]
    for s in stacks:
        print("\t".join([s.get("type", ""), (s.get("path") or ".").rstrip("/") or ".", s.get("name") or s.get("role") or ""]))
PY
}

harness_opt() {
  local key="$1" def="$2" v=""
  if have_stacks; then
    if command -v jq &>/dev/null; then
      v=$(jq -r --arg k "$key" 'if (.harness | type) == "object" and (.harness | has($k)) and .harness[$k] != null then .harness[$k] | tostring else empty end' "$STACKS_FILE" 2>/dev/null)
    elif command -v python3 &>/dev/null; then
      v=$(_json_query opt "$key")
    fi
  fi
  [ -n "$v" ] && echo "$v" || echo "$def"
}

harness_on() {
  case "$(harness_opt "$1" "$2" | tr '[:upper:]' '[:lower:]')" in
    true|on|1|yes) return 0 ;;
  esac
  return 1
}

base_branch() {
  local b
  b=$(harness_opt baseBranch "")
  if [ -n "$b" ]; then echo "$b"; return; fi
  if git -C "$ROOT" rev-parse --verify -q origin/dev >/dev/null 2>&1; then echo dev; else echo main; fi
}

base_ref() {
  local b; b=$(base_branch)
  git -C "$ROOT" merge-base "origin/$b" HEAD 2>/dev/null \
    || git -C "$ROOT" merge-base "$b" HEAD 2>/dev/null \
    || echo ""
}

git_common_dir() {
  git -C "$ROOT" rev-parse --path-format=absolute --git-common-dir 2>/dev/null
}

is_hub() {
  local gd cd
  gd=$(git -C "$ROOT" rev-parse --path-format=absolute --git-dir 2>/dev/null) || return 1
  cd=$(git_common_dir) || return 1
  [ "$gd" = "$cd" ]
}

stacks_list() {
  have_stacks || return 0
  if command -v jq &>/dev/null; then
    jq -r '(if ((.stacks // []) | length) > 0 then .stacks
            elif .type then [{type: .type, path: (.path // ".")}] else [] end)[]
           | [(.type // ""), ((.path // ".") | sub("/+$"; "") | if . == "" then "." else . end), (.name // .role // "")] | @tsv' \
      "$STACKS_FILE" 2>/dev/null
  elif command -v python3 &>/dev/null; then
    _json_query stacks
  fi
}

stack_for_file() {
  local f="$1" best_t="" best_p="" root_t="" t p _
  case "$f" in "$ROOT"/*) f="${f#$ROOT/}" ;; esac
  while IFS=$'\t' read -r t p _; do
    [ -z "$t" ] && continue
    if [ "$p" = "." ]; then
      root_t="$t"
    elif [[ "$f" == "$p/"* ]] && [ "${#p}" -gt "${#best_p}" ]; then
      best_t="$t"; best_p="$p"
    fi
  done < <(stacks_list)
  if [ -n "$best_t" ]; then printf '%s\t%s\n' "$best_t" "$best_p"
  elif [ -n "$root_t" ]; then printf '%s\t.\n' "$root_t"; fi
}

changed_files() {
  local ref="${1:-$(base_ref)}"
  {
    if [ -n "$ref" ]; then git -C "$ROOT" diff --name-only "$ref" 2>/dev/null
    else git -C "$ROOT" diff --name-only HEAD 2>/dev/null; fi
    git -C "$ROOT" ls-files --others --exclude-standard 2>/dev/null
  } | sort -u | grep -v '^$'
}

hook_field() {
  printf '%s' "${INPUT:-}" | python3 -c '
import json, sys
try:
    d = json.load(sys.stdin)
    for k in sys.argv[1].split("."):
        d = d.get(k, "") if isinstance(d, dict) else ""
    print(d if isinstance(d, str) else (json.dumps(d) if d not in ("", None) else ""))
except Exception:
    print("")
' "$1" 2>/dev/null
}

detect_stack_type() { # detect_stack_type DIR — stacks.json 없는 v1 단일 스택 프로젝트용 마커 추론
  local d="${1:-.}"
  if [ -f "$d/gradlew" ] || [ -f "$d/build.gradle.kts" ]; then echo kotlin
  elif [ -f "$d/go.work" ]; then echo go-multi
  elif [ -f "$d/go.mod" ]; then echo go
  elif [ -f "$d/pyproject.toml" ]; then echo python
  elif [ -f "$d/package.json" ] && grep -q '"next"' "$d/package.json" 2>/dev/null; then
    [ -f "$d/turbo.json" ] && echo nextjs-multi || echo nextjs
  elif [ -f "$d/pubspec.yaml" ]; then echo flutter
  elif ls "$d"/*.tf &>/dev/null; then echo infra
  fi
}

coverage_gate() { # coverage_gate <args...> — .claude/scripts/coverage-gate.py 실행
  python3 "$ROOT/.claude/scripts/coverage-gate.py" --repo "$ROOT" "$@"
}

run_timeout() {
  local s="$1"; shift
  if command -v timeout &>/dev/null; then timeout "$s" "$@"; else "$@"; fi
}
