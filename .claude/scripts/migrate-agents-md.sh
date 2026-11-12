#!/bin/bash
# .claude/scripts/migrate-agents-md.sh — v1(CLAUDE.md) → v2(AGENTS.md) 지침 파일 이전
#
# v2 부터 지침 파일은 AGENTS.md 하나다 (Claude Code ≥ 2.1.277 · Codex 공통).
# 같은 디렉토리나 상위에 CLAUDE.md 가 하나라도 있으면 Claude Code 기본 설정은 AGENTS.md 를 무시하므로
# 루트·역할별(backend/ 등) CLAUDE.md 를 모두 AGENTS.md 로 옮긴다.
#
#   bash .claude/scripts/migrate-agents-md.sh           # dry-run — 무엇을 옮길지 출력
#   bash .claude/scripts/migrate-agents-md.sh --apply   # 실제 이동 (git 추적 파일은 git mv)
#
# 같은 디렉토리에 AGENTS.md 가 이미 있으면 그 CLAUDE.md 는 건너뛰고 수동 병합을 안내한다.

APPLY=false
[ "$1" = "--apply" ] && APPLY=true
ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
cd "$ROOT" || exit 1

FOUND=0; CONFLICT=0
while IFS= read -r f; do
  dir=$(dirname "$f")
  FOUND=$((FOUND + 1))
  if [ -f "$dir/AGENTS.md" ]; then
    echo "⚠️  $f — $dir/AGENTS.md 가 이미 있음. 내용을 AGENTS.md 로 병합한 뒤 CLAUDE.md 를 지우세요."
    CONFLICT=$((CONFLICT + 1))
    continue
  fi
  if [ "$APPLY" = true ]; then
    if git ls-files --error-unmatch "$f" &>/dev/null; then git mv "$f" "$dir/AGENTS.md"
    else mv "$f" "$dir/AGENTS.md"; fi
    echo "✅ $f → $dir/AGENTS.md"
  else
    echo "→ $f → $dir/AGENTS.md"
  fi
done < <(find . -name CLAUDE.md -not -path '*/node_modules/*' -not -path './.git/*' -not -path './.claude/*' -not -path './.worktrees/*' -not -path './.claude/worktrees/*' 2>/dev/null | sed 's|^\./||' | sort)

[ -f .claude/CLAUDE.md ] && echo "⚠️  .claude/CLAUDE.md 도 AGENTS.md 를 가립니다 — 내용을 루트 AGENTS.md 로 옮기고 지우세요."
[ -f CLAUDE.local.md ] && echo "⚠️  CLAUDE.local.md 도 AGENTS.md 를 가립니다 — 개인 규칙은 ~/.claude 또는 AGENTS.md 로 옮기세요."

if [ "$FOUND" -eq 0 ]; then
  echo "ℹ️  CLAUDE.md 없음 — 이전할 것이 없습니다."
elif [ "$APPLY" = false ]; then
  echo ""
  echo "ℹ️  dry-run — 실제로 옮기려면 --apply"
fi
[ "$CONFLICT" -gt 0 ] && exit 2
exit 0
