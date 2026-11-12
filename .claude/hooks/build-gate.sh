#!/bin/bash
# .claude/hooks/build-gate.sh
# 빌드 게이트 — push 전 "컴파일/번들이 되는가" 를 로컬에서 CI build 단계와 같게 재현.
#
# 왜: 커버리지 게이트는 테스트 통과율만 본다. jest·flutter test 는 next build 의 타입·lint 실패나
#     flutter analyze 오류를 못 잡아서, "빌드가 되는지"가 CI 에 올라가서야 드러난다.
#     ⚠️ "서비스가 실제로 뜨는가"(DB 마이그레이션·런타임 env·컨텍스트 로드)는 dev-smoke.sh 의 몫.
#
# 스택별 (stacks.json 의 stacks[] 중 base 대비 바뀐 스택만, --all 이면 전부):
#   kotlin*  → ./gradlew assemble testClasses
#   go*      → go build ./... && go vet ./...
#   python*  → uv run ruff check . (+ mypy 설정 있으면 mypy)
#   nextjs*  → <패키지 매니저> run build   (turbo.json 있으면 turbo run build)
#   flutter* → flutter analyze
#   infra    → terraform fmt -check (+ .terraform 있으면 terraform validate)
#
# 사용:
#   bash .claude/hooks/build-gate.sh          # 변경분만
#   bash .claude/hooks/build-gate.sh --all    # 전 스택
#   (pre-push.sh 가 커버리지보다 먼저 호출. 끄기: "harness": {"buildGate": false})
# 반환: 0 = 통과(또는 해당 없음), 1 = 빌드 깨짐

set -o pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
have_stacks || exit 0
harness_on buildGate true || exit 0
cd "$ROOT" || exit 0
source "$(dirname "${BASH_SOURCE[0]}")/timing.sh"

if [ "$1" = "--all" ]; then
  TARGETS=$(stacks_list | cut -f1,2)
else
  TARGETS=$(changed_files | coverage_gate changed-stacks 2>/dev/null)
fi
[ -z "$TARGETS" ] && { echo "[Build] 빌드할 스택 없음 — 건너뜀"; exit 0; }

run() { local n="$1"; shift; "$@" 2>&1 | tail -"$n"; return "${PIPESTATUS[0]}"; }

pm() { # 패키지 매니저 추론
  if [ -f pnpm-lock.yaml ] && command -v pnpm &>/dev/null; then echo pnpm
  elif [ -f yarn.lock ] && command -v yarn &>/dev/null; then echo yarn
  else echo npm; fi
}

build_stack() { # build_stack TYPE PATH
  local t="$1" p="$2"
  [ -d "$p" ] || return 0
  (
    cd "$p" || exit 0
    case "$t" in
      kotlin|kotlin-multi)
        [ -f ./gradlew ] || exit 0
        echo "[Build] [$p] ./gradlew assemble testClasses"
        run 30 ./gradlew assemble testClasses --daemon -q ;;
      go|go-multi)
        command -v go &>/dev/null || { echo "[Build] [$p] go 없음 — 건너뜀"; exit 0; }
        echo "[Build] [$p] go build + vet"
        run 20 go build ./... && run 20 go vet ./... ;;
      python|python-multi)
        [ -f pyproject.toml ] && command -v uv &>/dev/null || { echo "[Build] [$p] uv 없음 — 건너뜀"; exit 0; }
        echo "[Build] [$p] ruff$(grep -q 'tool.mypy' pyproject.toml 2>/dev/null && echo ' + mypy')"
        run 20 uv run ruff check . || exit 1
        if grep -q 'tool.mypy' pyproject.toml 2>/dev/null; then run 20 uv run mypy . --no-error-summary; fi ;;
      nextjs|nextjs-multi)
        [ -f package.json ] || exit 0
        if [ -f turbo.json ]; then
          echo "[Build] [$p] turbo run build"
          run 30 npx turbo run build
        elif grep -q '"build"' package.json; then
          echo "[Build] [$p] $(pm) run build"
          run 30 "$(pm)" run build
        fi ;;
      flutter|flutter-multi)
        command -v flutter &>/dev/null || { echo "[Build] [$p] flutter 없음 — 건너뜀"; exit 0; }
        echo "[Build] [$p] flutter analyze"
        run 30 flutter analyze ;;
      infra)
        command -v terraform &>/dev/null || exit 0
        echo "[Build] [$p] terraform fmt$([ -d .terraform ] && echo ' + validate')"
        run 10 terraform fmt -check -recursive || exit 1
        if [ -d .terraform ]; then run 20 terraform validate; fi ;;
      *) exit 0 ;;
    esac
  )
}

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " [Build] 빌드 게이트 — CI build 단계 로컬 재현"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
FAILED=0
while IFS=$'\t' read -r T P; do
  [ -z "$T" ] && continue
  T0=$(date +%s)
  build_stack "$T" "$P"; R=$?
  timing_log "build:$P" "$T0" "$R"
  [ "$R" -eq 0 ] || { echo "[Build] ❌ [$P] 빌드 실패"; FAILED=1; }
done <<< "$TARGETS"

[ "$FAILED" -eq 0 ] && echo "[Build] ✅ 빌드 통과" || echo "[Build] ❌ 빌드 깨짐 — push 전에 고치세요"
exit "$FAILED"
