#!/bin/bash
# .claude/hooks/dev-smoke.sh
# 로컬 런타임 스모크 — push/배포 전에 "서비스가 실제로 뜨는가" 를 로컬에서 확인 (수동 실행 도구, 훅 등록 안 함).
#
# 빌드 게이트(build-gate.sh)는 "컴파일/번들이 되는가"만 본다. 이 스크립트는 다음 계층 — 바뀐 스택을 실제로
# 기동해 헬스체크까지 한다. DB 마이그레이션 충돌·런타임 env 누락·컨텍스트 로드 실패처럼 "빌드는 되는데 안 뜨는" 실패를 잡는다.
#
# 설정 (.claude/stacks.json — 없으면 조용히 아무것도 안 한다):
#   stacks[].smoke = {"cmd": "./gradlew bootRun", "health": "http://localhost:8080/actuator/health", "timeout": 180}
#   인프라(DB·Redis 등)가 필요하면 .claude/infra/smoke-compose.yml — 기동 전에 docker compose up -d --wait 로 올린다.
#   smoke 설정이 없는 스택은 건너뛴다.
#
# 서브커맨드:
#   smoke  (기본) 대상 스택을 기동 → 헬스체크 → 정리. 통과 0 / 실패 1
#   up            대상 스택을 기동해 그대로 띄워둔다(브라우저로 직접 확인). URL 출력
#   down          up 으로 띄운 프로세스 + 스모크 인프라 정리
# 대상: 서브커맨드 뒤에 스택 name·role·path. 생략 시 base 대비 바뀐 스택(smoke 설정 있는 것만).
#   bash .claude/hooks/dev-smoke.sh smoke
#   bash .claude/hooks/dev-smoke.sh up backend
#   bash .claude/hooks/dev-smoke.sh down

set -o pipefail
SUB="${1:-smoke}"; shift 2>/dev/null || true
WANT="$*"

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
have_stacks || exit 0
cd "$ROOT" || exit 0
command -v jq &>/dev/null || { echo "[Smoke] jq 필요 — 건너뜀"; exit 0; }

COMPOSE="$ROOT/.claude/infra/smoke-compose.yml"
PROJECT="coding-agent-smoke"
STATE_DIR="$(git_common_dir 2>/dev/null || echo "${TMPDIR:-/tmp}")/coding-agent-smoke"
PROCS="$STATE_DIR/procs"     # label|pid|log|health
mkdir -p "$STATE_DIR" 2>/dev/null || exit 0

line() { echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"; }

compose() { docker compose -f "$COMPOSE" -p "$PROJECT" "$@"; }

infra_up() {
  [ -f "$COMPOSE" ] || return 0
  command -v docker &>/dev/null || { echo "[Smoke] docker 없음 — 인프라 필요 스택은 실패할 수 있음"; return 0; }
  echo "[Smoke] 인프라 기동 (smoke-compose.yml)"
  compose up -d --wait 2>&1 | tail -10
}

infra_down() {
  [ -f "$COMPOSE" ] && command -v docker &>/dev/null && compose down -v 2>&1 | tail -5
}

stop_procs() {
  [ -f "$PROCS" ] || return 0
  while IFS='|' read -r label pid _ _; do
    [ -n "$pid" ] || continue
    kill -- "-$pid" 2>/dev/null || kill "$pid" 2>/dev/null
    echo "[Smoke] 정리: $label (pid $pid)"
  done <"$PROCS"
  rm -f "$PROCS"
}

if [ "$SUB" = down ]; then
  stop_procs; infra_down; exit 0
fi
case "$SUB" in smoke|up) ;; *) echo "usage: dev-smoke.sh smoke|up|down [대상...]" >&2; exit 1 ;; esac

# 대상: "label<TAB>path<TAB>cmd<TAB>health<TAB>timeout"
ALL=$(jq -r '(.stacks // [])[] | select(.smoke.cmd)
  | [(.name // .role // .path), ((.path // ".") | sub("/+$"; "")), .smoke.cmd, (.smoke.health // ""), ((.smoke.timeout // 120) | tostring)] | @tsv' \
  "$STACKS_FILE" 2>/dev/null)
[ -z "$ALL" ] && exit 0   # smoke 설정 없음

if [ -n "$WANT" ]; then
  TARGETS=$(printf '%s\n' "$ALL" | awk -F'\t' -v want=" $WANT " 'index(want, " " $1 " ") || index(want, " " $2 " ")')
else
  CHANGED_PATHS=" $(changed_files | coverage_gate changed-stacks 2>/dev/null | cut -f2 | tr '\n' ' ') "
  TARGETS=$(printf '%s\n' "$ALL" | awk -F'\t' -v ch="$CHANGED_PATHS" 'index(ch, " " $2 " ")')
fi
[ -z "$TARGETS" ] && { echo "[Smoke] 대상 스택 없음 (smoke 설정이 있는 바뀐 스택 없음)"; exit 0; }

wait_health() { # wait_health URL TIMEOUT PID
  local url="$1" to="$2" pid="$3" i=0
  [ -z "$url" ] && { sleep 5; kill -0 "$pid" 2>/dev/null; return; }
  command -v curl &>/dev/null || { echo "[Smoke] curl 없음 — 헬스체크 생략"; return 0; }
  while [ "$i" -lt "$to" ]; do
    curl -fsS -o /dev/null --max-time 3 "$url" 2>/dev/null && return 0
    kill -0 "$pid" 2>/dev/null || return 1
    sleep 2; i=$((i + 2))
  done
  return 1
}

line; echo " [Smoke] 런타임 스모크 ($SUB)"; line
stop_procs >/dev/null 2>&1
infra_up
FAILED=0
set -m   # 백그라운드 작업마다 별도 프로세스 그룹 — 정리할 때 자식까지 한 번에 끈다
while IFS=$'\t' read -r LABEL P CMD HEALTH TO; do
  [ -z "$LABEL" ] && continue
  LOG="$STATE_DIR/${LABEL//\//_}.log"
  echo "[Smoke] [$LABEL] 기동: (cd $P && $CMD)"
  (cd "$P" && exec bash -c "$CMD") >"$LOG" 2>&1 &
  PID=$!
  echo "$LABEL|$PID|$LOG|$HEALTH" >>"$PROCS"
  if wait_health "$HEALTH" "$TO" "$PID"; then
    echo "[Smoke] ✅ [$LABEL] 기동 확인 ${HEALTH:+($HEALTH)}"
  else
    echo "[Smoke] ❌ [$LABEL] ${TO}초 안에 뜨지 않음 — 로그 마지막 20줄:"
    tail -20 "$LOG" | sed 's/^/    /'
    FAILED=1
  fi
done <<< "$TARGETS"
set +m

if [ "$SUB" = smoke ]; then
  stop_procs >/dev/null; infra_down >/dev/null
  [ "$FAILED" -eq 0 ] && echo "[Smoke] ✅ 통과" || echo "[Smoke] ❌ 실패"
  exit "$FAILED"
fi
echo "[Smoke] 띄워 둠 — 확인 후 정리: bash .claude/hooks/dev-smoke.sh down"
cut -d'|' -f1,4 "$PROCS" | sed 's/|/ → /; s/^/  /'
exit "$FAILED"
