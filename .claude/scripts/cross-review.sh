#!/bin/bash
# .claude/scripts/cross-review.sh — 다른 모델로 교차 리뷰 (Claude 작업은 Codex 가, Codex 작업은 Claude 가)
#
# 사용: bash .claude/scripts/cross-review.sh [--base <branch>] [--reviewer codex|claude]
#   /pr 이 보안 리뷰와 병렬로 호출한다. 터미널에서 직접 돌려도 된다.
#   base 생략 시 .claude/hooks/lib.sh 의 base_branch (없으면 dev → main 순으로 존재하는 것)
#   끄기: .claude/stacks.json 의 "harness": {"crossReview": false}  (/pr 이 확인 — 이 스크립트는 그대로 실행)
#
# ⚠️ diff 와 주변 소스가 리뷰어 서비스(OpenAI Codex 또는 Anthropic Claude)로 전송된다. 조직 정책상
#    외부 전송이 안 되는 저장소라면 crossReview 를 끈다.
#
# 종료 코드
#   0  리뷰 완료 — 리포트를 stdout 과 <git-dir>/cross-review.md 에 남긴다 (마지막 줄 VERDICT: PASS|REVIEW|BLOCK)
#   3  반대 플랫폼의 usage limit 소진이 확인됨 — 이 경우만 자체 리뷰 대체 허용
#   1  그 밖의 오류 (CLI 미설치·로그인·네트워크·시간 초과·불완전한 응답) — 원인을 해결하고 재실행

BASE=""
REVIEWER=""
while [ $# -gt 0 ]; do
  case "$1" in
    --base|--reviewer)
      [ $# -ge 2 ] && [ -n "$2" ] || { echo "$1 에 값이 필요함" >&2; exit 1; }
      [ "$1" = --base ] && BASE="$2" || REVIEWER="$2"
      shift 2 ;;
    -h|--help) sed -n '2,18p' "$0"; exit 0 ;;
    *) echo "알 수 없는 인자: $1" >&2; exit 1 ;;
  esac
done

ROOT=$(git rev-parse --show-toplevel) || exit 1
cd "$ROOT" || exit 1
SCRIPTS="$ROOT/.claude/scripts"
GIT_DIR=$(git rev-parse --git-dir)
OUT="$GIT_DIR/cross-review.md"
ERROR_LOG="$GIT_DIR/cross-review-error.log"
# 실패한 재실행이 이전 PASS 리포트를 남기지 않게 한다.
rm -f "$OUT" "$ERROR_LOG"

# 선택 의존: 공통 헬퍼(lib.sh)·소요 시간 기록(timing.sh) — 없으면 대체 구현
# shellcheck disable=SC1091
[ -f .claude/hooks/lib.sh ] && source .claude/hooks/lib.sh >/dev/null 2>&1
# shellcheck disable=SC1091
[ -f .claude/hooks/timing.sh ] && source .claude/hooks/timing.sh >/dev/null 2>&1
type timing_log >/dev/null 2>&1 || timing_log() { :; }
if [ -z "$BASE" ]; then
  type base_branch >/dev/null 2>&1 && BASE=$(base_branch 2>/dev/null)
  if [ -z "$BASE" ]; then
    if git show-ref --verify --quiet refs/heads/dev || git show-ref --verify --quiet refs/remotes/origin/dev; then BASE=dev; else BASE=main; fi
  fi
fi

T0=$(date +%s)
git fetch origin "$BASE" --quiet 2>/dev/null || true
git rev-parse --verify --quiet "origin/$BASE" >/dev/null || { echo "origin/$BASE 를 찾을 수 없음" >&2; exit 1; }

CHANGED=$(git diff --name-only "origin/$BASE"...HEAD) || exit 1
[ -z "$CHANGED" ] && { echo "origin/$BASE 대비 변경 없음 — 리뷰 생략"; echo "VERDICT: PASS"; exit 0; }

# 리뷰어 = 지금 작업 중인 도구의 반대편. 판별 불가(터미널)면 설치된 쪽, 둘 다 있으면 codex
if [ -z "$REVIEWER" ]; then
  if [ -n "$CLAUDECODE" ]; then REVIEWER=codex
  elif [ -n "$CODEX_THREAD_ID" ] || [ -n "$CODEX_SANDBOX" ]; then REVIEWER=claude
  elif command -v codex >/dev/null 2>&1; then REVIEWER=codex
  else REVIEWER=claude
  fi
fi

# 고위험 변경이면 더 깊게 본다 — 인증·권한, 마이그레이션, 결제, 보안 설정, 하네스 훅
if printf '%s\n' "$CHANGED" | grep -qiE '(db/)?migration|(^|/)auth[/._-]|/auth[A-Z]|security[/A-Z._-]|permission|payment|billing|^\.claude/(githooks|hooks)/'; then
  DEPTH=high
else
  DEPTH=medium
fi
# 모델 라우터(harness.modelRouter=apply)가 켜져 있으면 난이도 판단으로 한 번 더 올린다 (낮추지는 않는다)
ROUTER=${MODEL_ROUTER:-}
if [ -z "$ROUTER" ] && type harness_opt >/dev/null 2>&1; then ROUTER=$(harness_opt modelRouter off 2>/dev/null); fi
if [ "$DEPTH" = medium ] && [ "$ROUTER" = apply ] && [ -f "$SCRIPTS/model-tier.py" ]; then
  TIER=$(python3 -c 'import json, sys; print(json.dumps({"role": "cross-reviewer", "task": "PR 변경분 코드 리뷰", "detail": sys.argv[1]}))' \
           "$(git diff --stat "origin/$BASE"...HEAD | tail -40; git diff "origin/$BASE"...HEAD | head -c 5000)" \
         | python3 "$SCRIPTS/model-tier.py" 2>/dev/null \
         | python3 -c 'import json, sys; print(json.load(sys.stdin).get("tier") or "")' 2>/dev/null)
  [ "$TIER" = high ] && DEPTH=high
fi

REVIEW_HEAD=$(git rev-parse --short HEAD)
TMP=$(mktemp -d) || exit 1
RAW="$TMP/stdout.log"; LOG="$TMP/review.md"; ERR="$TMP/progress.log"
: >"$RAW"; : >"$ERR"
trap 'RC=$?; timing_log "cross-review:$REVIEWER" "$T0" "$RC"; rm -rf "$TMP"' EXIT

PROMPT="이 브랜치의 origin/$BASE 대비 변경분(git diff origin/$BASE...HEAD)을 리뷰하라. 저장소 규칙은 AGENTS.md 를 따른다.
- 범위는 코드 리뷰다. 시크릿 파일·자격증명·실제 사용자 데이터는 읽거나 인용하지 마라.
- 실제 결함만 보고한다: 버그·회귀·보안·데이터 손실·규칙 위반. 칭찬·요약·스타일 취향은 쓰지 않는다.
- 항목마다 심각도(Critical/High/Medium/Low), 파일:줄, 무엇이 왜 틀렸는지, 어떻게 터지는지 한두 줄.
- 확신이 없는 지적은 '확인 필요'로 표시한다. 파일을 고치지 마라 — 읽기만 한다.
- 한국어로 쓰고, 마지막 줄은 정확히 'VERDICT: PASS' / 'VERDICT: REVIEW' / 'VERDICT: BLOCK' 중 하나 (Critical 있으면 BLOCK, High 있으면 REVIEW)."

# 긴 리뷰가 멈춰도 /pr 이 끝없이 기다리지 않게
TIMEOUT_BIN=$(command -v timeout || command -v gtimeout || true)
run() { if [ -n "$TIMEOUT_BIN" ]; then "$TIMEOUT_BIN" 900 "$@"; else "$@"; fi; }

echo "─── 교차 리뷰: $REVIEWER (깊이 $DEPTH · base origin/$BASE · 파일 $(printf '%s\n' "$CHANGED" | wc -l | tr -d ' ')개)" >&2
case "$REVIEWER" in
  codex)
    command -v codex >/dev/null || { echo "codex CLI 미설치 — 설치(npm i -g @openai/codex)·로그인 후 재실행하거나 --reviewer claude" >&2; exit 1; }
    # review 서브명령의 고정 출력 형식은 VERDICT 지시를 무시한다. 스키마로 실제 판정을 받는다.
    cat >"$TMP/schema.json" <<'JSON'
{"type":"object","properties":{"review":{"type":"string"},"verdict":{"type":"string","enum":["PASS","REVIEW","BLOCK"]}},"required":["review","verdict"],"additionalProperties":false}
JSON
    run codex exec --sandbox read-only -c model_reasoning_effort="$DEPTH" \
      --output-schema "$TMP/schema.json" --output-last-message "$RAW" \
      "$PROMPT
최종 응답은 지정된 JSON 스키마를 따른다. review에는 검토 결과 본문, verdict에는 실제 판정 PASS/REVIEW/BLOCK을 넣는다." \
      >"$TMP/session.log" 2>"$ERR"
    STATUS=$?
    ;;
  claude)
    command -v claude >/dev/null || { echo "claude CLI 미설치 — Claude Code 설치·로그인 후 재실행하거나 --reviewer codex" >&2; exit 1; }
    [ "$DEPTH" = high ] && MODEL=opus || MODEL=sonnet
    # 셸을 주지 않는다 — 접두 허용으로는 쓰기를 막을 수 없다. diff 는 미리 파일로
    DIFF_FILE="$TMP/branch.diff"
    git diff "origin/$BASE"...HEAD >"$DIFF_FILE" || exit 1
    run env -u CLAUDECODE claude -p "$PROMPT
변경분 diff 는 $DIFF_FILE 에 있다. 주변 코드는 Read·Grep·Glob 으로 본다." --model "$MODEL" \
      --tools "Read,Grep,Glob" --allowedTools "Read,Grep,Glob" --output-format json \
      --add-dir "$(dirname "$DIFF_FILE")" >"$RAW" 2>"$ERR"
    STATUS=$?
    ;;
  *) echo "알 수 없는 리뷰어: $REVIEWER (codex|claude)" >&2; exit 1 ;;
esac

# 정상 리뷰 본문과 CLI 오류를 분리한다. 불완전한 응답에 VERDICT를 만들어 붙이지 않는다.
python3 "$SCRIPTS/cross-review-result.py" "$REVIEWER" "$STATUS" "$RAW" "$ERR" >"$LOG"
RESULT=$?
if [ "$RESULT" -ne 0 ]; then
  (umask 077; { printf 'reviewer=%s process_exit=%s result=%s\n' "$REVIEWER" "$STATUS" "$RESULT"; cat "$RAW" "$ERR"; } >"$ERROR_LOG")
  echo "교차 리뷰 미완료: $ERROR_LOG (exit 3만 usage limit 자체 리뷰 대체 허용)" >&2
  exit "$RESULT"
fi

{ echo "<!-- cross-review: $REVIEWER · depth $DEPTH · $REVIEW_HEAD -->"; cat "$LOG"; } >"$OUT"
cat "$LOG"
