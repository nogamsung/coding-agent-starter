#!/bin/bash
# .claude/scripts/tests/test_hooks.sh — 훅 스모크 테스트 (CI·로컬 공통)
#   bash .claude/scripts/tests/test_hooks.sh
# 빈 프로젝트에서 조용히 통과하는지, worktree-guard·safety-guard 판정이 맞는지 본다.

set -u
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
PASS=0; FAIL=0
ok()   { PASS=$((PASS + 1)); }
bad()  { FAIL=$((FAIL + 1)); echo "❌ $*"; }
expect() { # expect <기대 exit> <설명> <명령...>
  local want="$1" desc="$2"; shift 2
  "$@" >"${TMPDIR:-/tmp}/.hooktest.out" 2>&1; local got=$?
  [ "$got" = "$want" ] && ok || { bad "$desc (want $want, got $got)"; sed 's/^/     /' "${TMPDIR:-/tmp}/.hooktest.out" | tail -5; }
}
json_cmd()  { python3 -c 'import json,sys; print(json.dumps({"tool_input":{"command":sys.argv[1]}}))' "$1" 2>/dev/null; }
json_file() { python3 -c 'import json,sys; print(json.dumps({"tool_input":{"file_path":sys.argv[1]}}))' "$1" 2>/dev/null; }

install() { mkdir -p "$1/.claude"; cp -R "$SRC/.claude/hooks" "$SRC/.claude/scripts" "$1/.claude/"; }

# ── 1) 빈 프로젝트(stacks.json 없음, git 아님) — 모두 exit 0, 출력 없음(session-start 제외)
E=$(mktemp -d); install "$E"; cd "$E" || exit 1
for h in worktree-guard post-edit-lint stop-tests memory-sync build-gate dev-smoke usage-counter; do
  OUT=$(json_file "$E/src/a.py" | bash ".claude/hooks/$h.sh" 2>&1); R=$?
  [ "$R" = 0 ] && [ -z "$OUT" ] && ok || bad "empty project: $h exit=$R out=$OUT"
done
OUT=$(json_cmd "git push origin x" | bash .claude/hooks/pre-push.sh 2>&1); [ $? = 0 ] && [ -z "$OUT" ] && ok || bad "empty: pre-push out=$OUT"
OUT=$(json_cmd ls | bash .claude/hooks/safety-guard.sh 2>&1); [ $? = 0 ] && [ -z "$OUT" ] && ok || bad "empty: safety-guard ls out=$OUT"
expect 2 "empty: safety-guard rm -rf / still blocked" bash -c "$(declare -f json_cmd); json_cmd 'rm -rf /' | bash .claude/hooks/safety-guard.sh"
echo '{}' | bash .claude/hooks/session-start.sh >/dev/null 2>&1 && ok || bad "empty: session-start"

# ── 2) git repo + stacks.json
R=$(mktemp -d); install "$R"; cd "$R" || exit 1
git init -q -b main . && git config user.email t@t && git config user.name t
echo '{"mode":"single","stacks":[{"role":"app","type":"go","path":"."}]}' >.claude/stacks.json
echo x >README.md; git add -A; git commit -qm init

g() { json_file "$1" | bash .claude/hooks/worktree-guard.sh; }
expect 2 "hub source edit blocked" g "$R/main.go"
expect 0 "hub meta edit allowed (.claude)" g "$R/.claude/x.json"
expect 0 "hub root md allowed" g "$R/NOTES.md"
expect 0 "hub docs allowed" g "$R/docs/a.go"
git worktree add -q .worktrees/feature-x -b feature/x 2>/dev/null
expect 0 "worktree edit allowed" bash -c "cd '$R/.worktrees/feature-x' && $(declare -f json_file); json_file '$R/.worktrees/feature-x/main.go' | bash .claude/hooks/worktree-guard.sh"
echo '{"mode":"single","harness":{"worktreeGuard":false},"stacks":[{"type":"go","path":"."}]}' >.claude/stacks.json
expect 0 "worktreeGuard=false allows" g "$R/main.go"
echo '{"mode":"single","stacks":[{"role":"app","type":"go","path":"."}]}' >.claude/stacks.json

s() { json_cmd "$1" | bash .claude/hooks/safety-guard.sh; }
expect 2 "force push on main blocked" s "git push --force origin main"
expect 2 "delete main blocked" s "git branch -D main"
expect 2 "remote delete dev blocked" s "git push origin --delete dev"
expect 2 "rm -rf / blocked" s "rm -rf /"
OUT=$(s "git branch -D feature/x"); [ $? = 0 ] && [[ "$OUT" == *'"allow"'* ]] && ok || bad "work branch delete should allow: $OUT"
OUT=$(s "git status"); [ $? = 0 ] && [ -z "$OUT" ] && ok || bad "git status should pass silently: $OUT"

# lib.sh
OUT=$(bash -c "source .claude/hooks/lib.sh; harness_opt coverage 90; base_branch; stack_for_file '$R/x/y.go'")
[ "$OUT" = $'90\nmain\ngo\t.' ] && ok || bad "lib.sh: $OUT"

# memory-sync off → 즉시 종료
OUT=$(bash .claude/hooks/memory-sync.sh commit 2>&1); [ -z "$OUT" ] && ok || bad "memory-sync off: $OUT"

# pre-push: git push 아닌 명령은 통과, core.hooksPath 설정 시 에이전트 모드는 no-op
expect 0 "pre-push non-push" bash -c "$(declare -f json_cmd); json_cmd 'git status' | bash .claude/hooks/pre-push.sh"
mkdir -p .claude/githooks && printf '#!/bin/bash\n' >.claude/githooks/pre-push && git config core.hooksPath .claude/githooks
OUT=$(json_cmd "git push" | bash .claude/hooks/pre-push.sh 2>&1); [ $? = 0 ] && [ -z "$OUT" ] && ok || bad "pre-push hooksPath no-op: $OUT"

echo "hooks: $PASS passed, $FAIL failed"
[ "$FAIL" = 0 ]
