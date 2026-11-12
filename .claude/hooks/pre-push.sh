#!/bin/bash
# .claude/hooks/pre-push.sh
# Pre-push 빌드·커버리지 게이트 (Claude·Codex·터미널 공통)
#
# git push 시: 빌드 게이트(build-gate.sh) → 바뀐 스택 테스트(커버리지 리포트 생성) → 판정.
# 판정은 .claude/scripts/coverage-gate.py 하나 — CI 도 같은 스크립트로 다시 강제하면 --no-verify 로 넘겨도 막힌다.
#   손댄 스택은 각각 라인 커버리지 ≥ harness.coverage (기본 90, 0 이면 커버리지 판정 끔).
#   스택 목록·타입은 .claude/stacks.json 의 stacks[]. 없으면(v1 단일 스택) 루트에서 타입을 추론한다.
#
# 호출 방식:
#   git 훅:    .claude/githooks/pre-push 가 `--git-hook` 으로 호출 (기본 — 어떤 도구로 push 해도 동작).
#              stdin = git 이 주는 ref 목록. 태그·브랜치 삭제만 push 하면 건너뛴다. 우회: git push --no-verify
#   에이전트 훅: PreToolUse(Bash) — stdin JSON 의 명령이 git push 일 때만 동작, 실패 시 exit 2(차단).
#              core.hooksPath 가 git 훅 디렉토리로 설정돼 있으면 git 훅이 돌므로 여기선 아무것도 안 한다(중복 방지).
#
# 지원 스택 (각 스택 경로 기준):
#   kotlin*  → ./gradlew test jacocoTestReport          (JaCoCo XML)
#   go*      → go test -coverprofile=coverage.out ./...  (go.work 면 모듈마다)
#   python*  → uv run pytest --cov --cov-report=xml      (coverage.xml)
#   nextjs*  → jest --coverage --coverageReporters=json-summary (스택 루트 또는 apps/*·packages/* 의 jest 보유 패키지)
#   flutter* → flutter test --coverage                   (스택 루트 또는 test/ 보유 하위 패키지)
#   infra    → 커버리지 없음 (빌드 게이트만)

INPUT=$(cat 2>/dev/null || echo '{}')
HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HOOK_DIR/lib.sh"

if [ "$1" = "--git-hook" ]; then
  MODE=git
  # 줄마다 "<local ref> <local sha> <remote ref> <remote sha>" — 브랜치 커밋을 올릴 때만 게이트
  NEEDS_GATE=0; PUSH_SHAS=""
  while read -r _ LOCAL_SHA REMOTE_REF _; do
    [ -z "$LOCAL_SHA" ] && continue
    [[ "$LOCAL_SHA" =~ ^0+$ ]] && continue
    [[ "$REMOTE_REF" == refs/tags/* ]] && continue
    NEEDS_GATE=1; PUSH_SHAS="$PUSH_SHAS $LOCAL_SHA"
  done <<< "$INPUT"
  [ "$NEEDS_GATE" -eq 1 ] || exit 0
else
  MODE=agent
  INPUT_CMD=$(hook_field tool_input.command)
  [[ "$INPUT_CMD" == *"git push"* ]] || exit 0
  [[ "$INPUT_CMD" == *"--no-verify"* ]] && { echo "[Pre-push] --no-verify — 게이트 건너뜀"; exit 0; }
  # git 훅이 켜져 있으면 그쪽이 돈다
  HP=$(git -C "$ROOT" config core.hooksPath 2>/dev/null)
  if [ -n "$HP" ]; then
    case "$HP" in /*) ;; *) HP="$ROOT/$HP" ;; esac
    [ -x "$HP/pre-push" ] || [ -f "$HP/pre-push" ] && exit 0
  fi
fi

cd "$ROOT" || exit 0
fail_exit() { [ "$MODE" = git ] && exit 1 || exit 2; }

# 통과 기록 — git 은 원격에 먼저 연결한 뒤 훅을 돌려서 게이트가 길면 SSH 가 끊길 수 있다.
# 같은 커밋을 다시 push 하면 게이트를 건너뛰어 바로 올라가게 한다.
PASS_FILE="$(git rev-parse --path-format=absolute --git-dir 2>/dev/null)/coding-agent-gate-passed"
if [ "$MODE" = git ] && [ -n "$PUSH_SHAS" ]; then
  ALL=1
  for SHA in $PUSH_SHAS; do grep -qxF "$SHA" "$PASS_FILE" 2>/dev/null || ALL=0; done
  [ "$ALL" -eq 1 ] && { echo "[Pre-push] 이 커밋은 이미 게이트를 통과함 — 건너뜀"; exit 0; }
fi

command -v python3 &>/dev/null || { echo "[Pre-push] python3 없음 — 게이트 건너뜀"; exit 0; }
source "$HOOK_DIR/timing.sh"

# ── 대상 스택 ───────────────────────────────────────────────────
if have_stacks; then
  TARGETS=$(changed_files | coverage_gate changed-stacks 2>/dev/null)
  THRESHOLD=$(coverage_gate threshold 2>/dev/null || echo 90)
else
  T=$(detect_stack_type "$ROOT")
  [ -z "$T" ] && exit 0
  TARGETS=$(printf '%s\t.' "$T")
  THRESHOLD=90
fi
[ -z "$TARGETS" ] && { echo "[Pre-push] 바뀐 스택 없음 — 통과"; exit 0; }

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " [Pre-push] 빌드·커버리지 게이트 (기준: ${THRESHOLD}%)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# ① 빌드 게이트
if have_stacks; then
  T0=$(date +%s)
  bash "$HOOK_DIR/build-gate.sh"; R=$?
  timing_log pre-push:build "$T0" "$R"
  if [ "$R" -ne 0 ]; then
    echo "[Pre-push] ❌ 빌드 게이트 실패 — 푸시 차단 (긴급 시 git push --no-verify)"
    fail_exit
  fi
fi

COVERAGE_ON=1
python3 -c "import sys; sys.exit(0 if float('$THRESHOLD') > 0 else 1)" 2>/dev/null || COVERAGE_ON=0
[ "$COVERAGE_ON" -eq 0 ] && { echo "[Pre-push] 커버리지 기준 0 — 커버리지 판정 꺼짐"; exit 0; }

run() { local n="$1"; shift; "$@" 2>&1 | tail -"$n"; return "${PIPESTATUS[0]}"; }

# ② 테스트 + 커버리지 리포트 생성
test_stack() { # test_stack TYPE PATH — 0 = 테스트 통과(리포트 생성), 1 = 실패, 3 = 해당 없음
  local t="$1" p="$2"
  [ -d "$p" ] || return 3
  (
    cd "$p" || exit 3
    case "$t" in
      kotlin|kotlin-multi)
        [ -f ./gradlew ] || exit 3
        echo "[Pre-push] [$p] ./gradlew test jacocoTestReport"
        run 30 ./gradlew test jacocoTestReport --daemon -q ;;
      go|go-multi)
        command -v go &>/dev/null || exit 3
        if [ -f go.work ]; then
          R=0
          for m in $(go list -m -f '{{.Dir}}' 2>/dev/null); do
            echo "[Pre-push] [$p] go test (${m#$PWD/})"
            (cd "$m" && run 20 go test -coverprofile=coverage.out ./...) || R=1
          done
          exit $R
        fi
        [ -f go.mod ] || exit 3
        echo "[Pre-push] [$p] go test -coverprofile"
        run 30 go test -coverprofile=coverage.out ./... ;;
      python|python-multi)
        [ -f pyproject.toml ] && command -v uv &>/dev/null || { echo "[Pre-push] [$p] uv 없음 — 건너뜀"; exit 3; }
        echo "[Pre-push] [$p] uv run pytest --cov"
        run 30 uv run pytest --cov --cov-report=xml -q ;;
      nextjs|nextjs-multi)
        [ -f package.json ] || exit 3
        JEST="--coverage --coverageReporters=json-summary --passWithNoTests"
        if ls jest.config.* &>/dev/null || grep -q '"jest"' package.json; then
          echo "[Pre-push] [$p] jest --coverage"
          # shellcheck disable=SC2086
          run 30 npx jest $JEST
        else
          R=0; FOUND=0
          for d in apps/*/ packages/*/; do
            [ -f "$d/package.json" ] || continue
            ls "$d"jest.config.* &>/dev/null || continue
            FOUND=1; echo "[Pre-push] [$p/${d%/}] jest --coverage"
            # shellcheck disable=SC2086
            (cd "$d" && run 20 npx jest $JEST) || R=1
          done
          [ "$FOUND" -eq 1 ] || exit 3
          exit $R
        fi ;;
      flutter|flutter-multi)
        command -v flutter &>/dev/null || { echo "[Pre-push] [$p] flutter 없음 — 건너뜀"; exit 3; }
        if [ -f pubspec.yaml ] && [ -d test ]; then
          echo "[Pre-push] [$p] flutter test --coverage"
          run 30 flutter test --coverage
        else
          R=0; FOUND=0
          while IFS= read -r ps; do
            d=$(dirname "$ps"); [ -d "$d/test" ] || continue
            FOUND=1; echo "[Pre-push] [$p/${d#./}] flutter test --coverage"
            (cd "$d" && run 20 flutter test --coverage) || R=1
          done < <(find . -name pubspec.yaml -not -path '*/.dart_tool/*' -not -path '*/build/*' 2>/dev/null)
          [ "$FOUND" -eq 1 ] || exit 3
          exit $R
        fi ;;
      *) exit 3 ;;
    esac
  )
}

FAILED=0
while IFS=$'\t' read -r T P; do
  [ -z "$T" ] && continue
  echo "─── [$P] ($T) ───"
  T0=$(date +%s)
  test_stack "$T" "$P"; R=$?
  timing_log "pre-push:$P" "$T0" "$R"
  case "$R" in
    3) echo "[Pre-push] ℹ️  [$P] 테스트 도구·대상 없음 — 건너뜀"; continue ;;
    0) ;;
    *) echo "[Pre-push] ❌ [$P] 테스트 실패"; FAILED=1; continue ;;
  esac
  if have_stacks; then coverage_gate check --stack "$T:$P" || FAILED=1
  else coverage_gate check --stack "$T:$P" --threshold "$THRESHOLD" || FAILED=1; fi
done <<< "$TARGETS"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ "$FAILED" -eq 0 ]; then
  echo "[Pre-push] ✅ 모든 스택 통과 — 푸시 진행"
  if [ "$MODE" = git ] && [ -n "$PUSH_SHAS" ]; then
    for SHA in $PUSH_SHAS; do echo "$SHA"; done >>"$PASS_FILE" 2>/dev/null
    tail -50 "$PASS_FILE" >"$PASS_FILE.tmp" 2>/dev/null && mv "$PASS_FILE.tmp" "$PASS_FILE"
  fi
  exit 0
fi
echo "[Pre-push] ❌ 테스트 실패 또는 커버리지 미달 — 푸시 차단"
echo "  → 테스트 추가: /test <파일경로>   ·  긴급 우회: git push --no-verify"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
fail_exit
