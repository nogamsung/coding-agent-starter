#!/bin/bash
# .claude/hooks/worktree-guard.sh
# PreToolUse(Edit|Write|MultiEdit) hook — 메인 체크아웃을 "허브 전용" 으로 강제 (Claude·Codex 공통)
#
# 동시에 여러 에이전트 세션을 띄워도 git 작업트리/인덱스가 꼬이지 않도록,
# 실제 소스 편집은 격리된 worktree(.worktrees/* 또는 임의 linked worktree) 안에서만 하게 한다.
#
# 규칙:
#   - linked worktree 안에서의 편집 → 항상 허용
#   - 메인 체크아웃에서의 편집:
#       · 메타파일(.claude/(githooks 포함) .codex/ .agents/ docs/ memory/ 루트 *.md VERSION .gitignore .gitattributes) → 허용
#       · 그 외 소스 파일 → exit 2 차단
#
# 끄기: .claude/stacks.json 의 "harness": {"worktreeGuard": false}. stacks.json 이 없으면 관여하지 않는다.
# .claude/githooks/pre-commit 도 이 스크립트를 파일마다 불러 같은 규칙으로 허브 커밋을 막는다:
#   printf '{"tool_input":{"file_path":"<절대경로>"}}' | (cd "$ROOT" && bash .claude/hooks/worktree-guard.sh)
# (Claude Code hook spec: exit 2 = block)

INPUT=$(cat 2>/dev/null || echo '{}')

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
have_stacks || exit 0
harness_on worktreeGuard true || exit 0
git rev-parse --git-dir &>/dev/null || exit 0

# 메인 작업트리 루트 = 공유 .git 의 부모 (linked worktree 에서 불려도 같다)
COMMON_DIR=$(git_common_dir) || exit 0
[ -n "$COMMON_DIR" ] || exit 0
MAIN_ROOT=$(dirname "$COMMON_DIR")

DECISION=$(MAIN_ROOT="$MAIN_ROOT" python3 - "$INPUT" <<'PY' 2>/dev/null || echo "ALLOW"
import sys, json, os

main_root = os.path.realpath(os.environ.get("MAIN_ROOT", ""))
try:
    d = json.loads(sys.argv[1]) if len(sys.argv) > 1 else {}
except Exception:
    print("ALLOW"); sys.exit(0)

fp = (d.get("tool_input", {}) or {}).get("file_path", "")
if not fp or not main_root:
    print("ALLOW"); sys.exit(0)

fp_abs = os.path.normpath(fp if os.path.isabs(fp) else os.path.join(os.getcwd(), fp))
# 아직 없는 파일도 있으니 존재하는 상위까지만 realpath (macOS /var → /private/var 대응)
head, tail = fp_abs, []
while head and not os.path.exists(head) and head != os.path.dirname(head):
    head, t = os.path.dirname(head), os.path.basename(head)
    tail.insert(0, t)
fp_abs = os.path.join(os.path.realpath(head), *tail) if tail else os.path.realpath(head)

if not (fp_abs == main_root or fp_abs.startswith(main_root + os.sep)):
    print("ALLOW"); sys.exit(0)  # 메인 작업트리 밖(다른 repo·linked worktree 경로)

rel = os.path.relpath(fp_abs, main_root)
first = rel.split(os.sep)[0]
if first == ".worktrees":
    print("ALLOW"); sys.exit(0)

EXEMPT_DIRS = {".claude", ".codex", ".agents", "docs", "memory"}  # .claude/githooks 는 .claude 에 포함
EXEMPT_FILES = {".gitignore", ".gitattributes", "VERSION"}
if first in EXEMPT_DIRS:
    print("ALLOW"); sys.exit(0)
if os.sep not in rel and (rel.endswith(".md") or rel in EXEMPT_FILES):
    print("ALLOW"); sys.exit(0)

print("BLOCK\t" + rel)
PY
)

if [ "${DECISION%%$'\t'*}" = "BLOCK" ]; then
  REL="${DECISION#BLOCK$'\t'}"
  BRANCH=$(git branch --show-current 2>/dev/null || echo "?")
  BASE=$(base_branch)
  {
    echo "[WorktreeGuard] 차단: 메인 체크아웃(브랜치 $BRANCH)에서 소스 편집 시도 — $REL"
    echo "  메인 체크아웃은 '허브' 전용입니다. 실제 작업은 격리된 worktree 안에서만 하세요."
    echo ""
    echo "  → 새 작업이면:   /start <기능명>            (worktree + 브랜치 자동 생성)"
    echo "  → 수동 생성:     git worktree add .worktrees/<type-name> -b <type>/<name> origin/$BASE"
    echo "                   그 후 .worktrees/<type-name> 안의 경로로 다시 편집하세요."
    echo "  → 끄기:          .claude/stacks.json 에 \"harness\": {\"worktreeGuard\": false}"
    echo ""
    echo "  메타파일(.claude/ .codex/ .agents/ docs/ memory/ 루트 *.md VERSION .gitignore)은 메인에서 편집 가능합니다."
  } >&2
  exit 2
fi

exit 0
