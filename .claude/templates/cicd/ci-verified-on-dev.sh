#!/usr/bin/env bash
# =============================================================================
# ci-verified-on-dev.sh — 릴리스 PR(dev → main)의 무거운 검증을 dev push 결과로 대신해도 되는지 판정
# -----------------------------------------------------------------------------
# 릴리스 PR 의 head 는 dev 그 자체다. dev push 마다 같은 워크플로가 그 push 가 바꾼 범위를 이미 검증했다.
# <base>..<head> 사이에서 이 워크플로 경로를 건드린 커밋 하나하나에 "그 커밋에서 성공한 push 실행"이 있으면
# 최종 코드가 이미 검증된 것이다 → 다시 돌리지 않는다.
# 하나라도 없으면(실패·취소·여러 커밋을 한 번에 push) 검증 안 됨 → 전부 돌린다(보수적). 진행 중이면 WAIT_SECONDS 만큼 기다린다.
#
# 사용: ci-verified-on-dev.sh <workflow 파일명> <base ref> <head sha> <pathspec>...
#   stdout 마지막 줄 = verified=true|false, 나머지는 판정 근거
#   GH_TOKEN·GITHUB_REPOSITORY 필요(Actions 에선 기본 제공). checkout 은 fetch-depth: 0
#
# 워크플로 예 (.github/scripts/ 에 복사한 경우):
#   - name: Release PR — already verified on dev?
#     id: release
#     if: github.event_name == 'pull_request' && github.base_ref == 'main' && github.head_ref == 'dev'
#     env: { GH_TOKEN: ${{ github.token }}, HEAD_SHA: ${{ github.event.pull_request.head.sha }}, WAIT_SECONDS: '1200' }
#     run: bash .github/scripts/ci-verified-on-dev.sh ci.yml origin/main "$HEAD_SHA" src ':!docs/**' | tee v.txt; tail -1 v.txt >> "$GITHUB_OUTPUT"
#   이후 무거운 잡에  if: steps.release.outputs.verified != 'true'
# =============================================================================
set -euo pipefail

WORKFLOW="$1"; BASE="$2"; HEAD="$3"; shift 3
[ "$#" -gt 0 ] || { echo "pathspec 이 필요하다" >&2; exit 2; }

COMMITS=$(git rev-list --no-merges "$BASE..$HEAD" -- "$@")
MERGES=$(git rev-list --merges "$BASE..$HEAD" -- "$@" | wc -l | tr -d ' ')
if [ "$MERGES" != 0 ]; then
  echo "경로를 건드린 머지 커밋 ${MERGES}개 — push 단위를 확정할 수 없다"
  echo "verified=false"; exit 0
fi
if [ -z "$COMMITS" ]; then
  echo "이 워크플로 경로를 건드린 커밋 없음"
  echo "verified=true"; exit 0
fi

# 가장 오래된 대상 커밋 날짜 하루 전부터의 push 실행만 받는다(전 기간 페이지네이션을 피한다)
OLDEST=$(git log -1 --format=%cs "$(echo "$COMMITS" | tail -1)")
SINCE=$(date -u -d "$OLDEST -1 day" +%F 2>/dev/null || date -u -j -v-1d -f %F "$OLDEST" +%F)
# WAIT_SECONDS(기본 0): 검증 안 된 커밋의 dev push 실행이 아직 대기·진행 중이면 끝날 때까지 이만큼 기다린다.
# 릴리스 PR 은 대개 마지막 dev 머지 직후에 열려 그 push CI 가 아직 돌고 있다. 기다리는 동안 러너 한 칸을 잡지만 그 대신 빌드·테스트·커버리지를 다시 돌리지 않는다.
WAIT_SECONDS="${WAIT_SECONDS:-0}"
DEADLINE=$(( $(date +%s) + WAIT_SECONDS ))

# 서버의 status 필터는 쓰지 않는다 — 상태가 바뀌는 순간(requested 등)에 빠져 대기를 일찍 끝낼 수 있다.
# 이 기간 dev push 실행을 한 번에 받아 "head_sha 상태 결론" 으로 여기서 고른다.
runs() {
  gh api --paginate \
    "repos/$GITHUB_REPOSITORY/actions/workflows/$WORKFLOW/runs?event=push&branch=dev&created=>=$SINCE&per_page=100" \
    -q '.workflow_runs[] | "\(.head_sha) \(.status) \(.conclusion)"'
}

while :; do
  RUNS=$(runs)
  OK=$(awk '$3 == "success" {print $1}' <<<"$RUNS" | sort -u)
  MISSING_SHAS=$(grep -vxF -f <(printf '%s\n' "$OK") <<<"$COMMITS" || true)
  [ -z "$MISSING_SHAS" ] && break
  PENDING=$(awk '$2 != "completed" {print $1}' <<<"$RUNS" | sort -u)
  STILL=$(grep -xF -f <(printf '%s\n' "$MISSING_SHAS") <<<"$PENDING" || true)
  if [ -z "$STILL" ] || [ "$(date +%s)" -ge "$DEADLINE" ]; then break; fi
  echo "dev push 실행 $(grep -c . <<<"$STILL")개가 아직 도는 중 — 30초 뒤 다시 본다"
  sleep 30
done

TOTAL=$(grep -c . <<<"$COMMITS")
MISSING=$(grep -c . <<<"$MISSING_SHAS" || true)
while read -r c; do
  [ -n "$c" ] && echo "검증 안 된 커밋: $(git log -1 --format='%h %s' "$c")"
done < <(head -10 <<<"$MISSING_SHAS")

echo "대상 커밋 ${TOTAL}개 중 dev push 성공 실행 없음 ${MISSING}개"
if [ "$MISSING" = 0 ]; then echo "verified=true"; else echo "verified=false"; fi
