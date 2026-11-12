#!/bin/bash
# .claude/hooks/post-edit-lint.sh
# PostToolUse(Edit|Write|MultiEdit) hook — 파일 확장자 기반 즉시 lint
#
# 스택 경로: .claude/stacks.json 의 stacks[] 중 파일이 속한 스택 (없으면 루트 — v1 단일 스택 폴백)
# 스택 도구 없으면 조용히 skip. 출력은 tail -20 으로 제한. Codex 는 codex-adapter.sh 가 파일마다 같은 JSON 으로 부른다.

INPUT=$(cat 2>/dev/null || echo '{}')
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

FILE=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('tool_input', {}).get('file_path', ''))
except Exception:
    print('')
" 2>/dev/null || echo '')

[ -z "$FILE" ] && exit 0

# 생성 파일은 skip
case "$FILE" in
  *.g.dart|*.freezed.dart|*.pb.go|*generated*|*/node_modules/*|*/.venv/*) exit 0 ;;
esac

# 루트 기준 상대 경로 → 스택 경로 결정
cd "$ROOT" 2>/dev/null || exit 0
case "$FILE" in "$ROOT"/*) FILE="${FILE#$ROOT/}" ;; esac
STACK_PATH=$(stack_for_file "$FILE" | cut -f2)
[ -z "$STACK_PATH" ] && STACK_PATH="."
REL=${FILE#$STACK_PATH/}

case "$FILE" in
  */package.json|*/package-lock.json|*/pnpm-lock.yaml|*/yarn.lock|*/go.mod|*/go.sum|*/pyproject.toml|*/uv.lock|*/poetry.lock|*/requirements.txt|*/Cargo.toml|*/Cargo.lock|*/pubspec.yaml|*/pubspec.lock|*/Gemfile|*/Gemfile.lock|*/pom.xml|*/build.gradle|*/build.gradle.kts)
    echo "[Harness] 의존성 파일 변경 감지: $REL"
    case "$FILE" in
      */package.json|*/package-lock.json|*/pnpm-lock.yaml|*/yarn.lock)
        echo "  → 보안 검토: npm audit  ·  pnpm audit  ·  yarn audit" ;;
      */go.mod|*/go.sum)
        echo "  → 보안 검토: govulncheck ./...  ·  go list -m -u all" ;;
      */pyproject.toml|*/uv.lock|*/poetry.lock|*/requirements.txt)
        echo "  → 보안 검토: uv pip audit  ·  pip-audit  ·  safety check" ;;
      */Cargo.toml|*/Cargo.lock)
        echo "  → 보안 검토: cargo audit" ;;
      */pubspec.yaml|*/pubspec.lock)
        echo "  → 보안 검토: dart pub outdated  ·  flutter pub outdated --mode=null-safety" ;;
      */Gemfile|*/Gemfile.lock)
        echo "  → 보안 검토: bundler-audit check  ·  bundle outdated" ;;
      */pom.xml|*/build.gradle|*/build.gradle.kts)
        echo "  → 보안 검토: ./gradlew dependencyCheckAnalyze  ·  mvn org.owasp:dependency-check-maven:check" ;;
    esac
    echo "  → 또는 'security-reviewer' agent 호출 (CVE + 라이선스 + 의존성 취약점)"
    ;;
  *AGENTS.md|*AGENTS.*.md|*CLAUDE.md|*CLAUDE.*.md)
    if [ -f "$FILE" ]; then
      LINES=$(wc -l < "$FILE" | tr -d ' ')
      if [ "$LINES" -gt 300 ]; then
        echo "[Harness] ⚠️ $FILE: $LINES 줄 (>300)"
        echo "  → 상세 내용을 .agents/skills/{topic}/SKILL.md 또는 docs/{topic}.md 로 이관하고"
        echo "    지침 파일에는 \`상세: .agents/skills/{topic}/SKILL.md\` 인덱스 한 줄만 남기세요."
      fi
    fi
    ;;
  *.py)
    if [ -f "$STACK_PATH/pyproject.toml" ] && command -v uv &>/dev/null; then
      echo "[Harness] ruff $REL"
      (cd "$STACK_PATH" && uv run ruff check "$REL" 2>&1 | tail -20)
    fi
    ;;
  *.go)
    if [ -f "$STACK_PATH/go.mod" ] && command -v gofmt &>/dev/null; then
      echo "[Harness] gofmt $REL"
      (cd "$STACK_PATH" && gofmt -l "$REL" 2>&1)
    fi
    ;;
  *.kt)
    if [ -f "$STACK_PATH/gradlew" ]; then
      echo "[Harness] ktlint ($STACK_PATH)"
      (cd "$STACK_PATH" && ./gradlew ktlintCheck --daemon -q 2>&1 | tail -20)
    fi
    ;;
  *.ts|*.tsx)
    if [ -f "$STACK_PATH/package.json" ]; then
      echo "[Harness] eslint $REL"
      (cd "$STACK_PATH" && npx eslint "$REL" --max-warnings 0 2>&1 | tail -20)
    fi
    ;;
  *.dart)
    if command -v dart &>/dev/null; then
      echo "[Harness] dart analyze $REL"
      (cd "$STACK_PATH" && dart analyze "$REL" 2>&1 | tail -20)
    fi
    ;;
esac

exit 0
