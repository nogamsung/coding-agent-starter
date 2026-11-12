#!/bin/bash
# .claude/hooks/stop-tests.sh — Stop 훅: 턴이 끝나면 바뀐 스택의 빠른 검증만 돌린다
#
#   - base(origin/dev 또는 main) 대비 바뀐 파일이 속한 스택만 (.claude/stacks.json 의 stacks[])
#   - 지난번 통과 뒤로 그 스택들의 소스가 그대로면 건너뛴다 (지문 = diff + 추적 안 된 파일 내용)
#   - worktreeGuard 가 켜져 있으면 허브(메인 체크아웃)에서는 돌지 않는다 — 소스 편집은 worktree 에서만
#   - 같은 worktree 에서 gradle 빌드가 이미 돌고 있으면 kotlin 은 건너뛴다 (결과 XML·데몬 메모리 충돌)
# 커버리지 판정은 하지 않는다 — push 게이트(pre-push.sh)와 CI 의 몫.
# 결과는 보여 주기만 하고 턴을 막지 않는다(항상 exit 0).
# 끄기: "harness": {"stopTests": false}

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
have_stacks || exit 0
harness_on stopTests true || exit 0
cd "$ROOT" || exit 0
git rev-parse --git-dir &>/dev/null || exit 0
if harness_on worktreeGuard true && is_hub; then exit 0; fi
command -v python3 &>/dev/null || exit 0

source "$(dirname "${BASH_SOURCE[0]}")/timing.sh"
T0=$(date +%s)

TARGETS=$(changed_files | coverage_gate changed-stacks 2>/dev/null)
[ -z "$TARGETS" ] && exit 0

PATHS=$(printf '%s\n' "$TARGETS" | cut -f2 | sort -u)
BASE=$(base_ref)
STAMP="$(git rev-parse --path-format=absolute --git-dir)/coding-agent-stop-tests.last"
FINGERPRINT=$( {
    printf '%s\n' "$TARGETS"
    # shellcheck disable=SC2086
    if [ -n "$BASE" ]; then git diff "$BASE" -- $PATHS; else git diff HEAD -- $PATHS; fi
    git ls-files --others --exclude-standard -- $PATHS | while IFS= read -r f; do
      [ -f "$f" ] && { echo "$f"; cat "$f"; }
    done; } 2>/dev/null | { shasum 2>/dev/null || sha1sum; } | cut -d' ' -f1 )
if [ -n "$FINGERPRINT" ] && [ "$(cat "$STAMP" 2>/dev/null)" = "$FINGERPRINT" ]; then
  echo "[Harness] stack tests — 지난 통과 뒤 변경 없음, 건너뜀"
  exit 0
fi

run() { # run <tail N> <명령...> — 출력 제한 + 원래 종료 코드 유지
  local n="$1"; shift
  "$@" 2>&1 | tail -"$n"; return "${PIPESTATUS[0]}"
}

check_stack() { # check_stack TYPE PATH
  local t="$1" p="$2"
  [ -d "$p" ] || return 0
  echo "  -> [$p] ($t)"
  (
    cd "$p" || exit 0
    case "$t" in
      kotlin|kotlin-multi)
        [ -f ./gradlew ] || exit 0
        if pgrep -f '[o]rg.gradle.wrapper.GradleWrapperMain' >/dev/null 2>&1; then
          echo "     다른 gradle 빌드가 돌고 있음 — 건너뜀 (다음 턴에 다시)"; exit 1
        fi
        if [ "$t" = kotlin-multi ]; then run 30 ./gradlew test jacocoTestReport --daemon -q
        else run 30 ./gradlew test --daemon -q; fi ;;
      go|go-multi)
        command -v go &>/dev/null || exit 0
        { [ -f go.mod ] || [ -f go.work ]; } || exit 0
        run 20 go vet ./... && run 30 go test ./... ;;
      python|python-multi)
        [ -f pyproject.toml ] && command -v uv &>/dev/null || exit 0
        R=0
        run 15 uv run ruff check . || R=1
        if [ "$t" = python-multi ] && [ -d services ]; then
          run 15 uv run mypy services packages --no-error-summary || R=1
        else
          run 15 uv run mypy . --no-error-summary || R=1
        fi
        if [ -d tests ] || ls test_*.py */test_*.py &>/dev/null; then run 20 uv run pytest -q || R=1; fi
        exit $R ;;
      nextjs|nextjs-multi)
        [ -f package.json ] || exit 0
        if [ -f turbo.json ] && command -v npx &>/dev/null; then
          run 30 npx turbo run build test
        else
          run 20 npx tsc --noEmit && run 20 npx jest --passWithNoTests
        fi ;;
      flutter|flutter-multi)
        [ -f pubspec.yaml ] && command -v flutter &>/dev/null || exit 0
        run 30 flutter test ;;
      infra)
        command -v terraform &>/dev/null && ls ./*.tf &>/dev/null || exit 0
        run 10 terraform fmt -check -recursive ;;
      *) exit 0 ;;
    esac
  )
}

echo "[Harness] stack tests (바뀐 스택만)"
FAILED=0
while IFS=$'\t' read -r T P; do
  [ -z "$T" ] && continue
  check_stack "$T" "$P" || FAILED=1
done <<< "$TARGETS"

timing_log stop-tests "$T0" "$FAILED"
if [ "$FAILED" -eq 0 ]; then
  [ -n "$FINGERPRINT" ] && echo "$FINGERPRINT" >"$STAMP" 2>/dev/null
  echo "[Harness] ✅ 바뀐 스택 검증 통과"
else
  echo "[Harness] ❌ 실패한 스택이 있다 — 위 출력 확인"
fi
exit 0
