#!/bin/bash
# .claude/hooks/memory-sync.sh — 프로젝트 메모리의 원본을 저장소 `memory/` 로 (Claude·Codex 공통, opt-in)
#
# Claude 자동 메모리(~/.claude/projects/<cwd 슬러그>/memory)는 이 컴퓨터에만 남는다. 다른 컴퓨터·worktree·에이전트가
# 같은 기억을 보게 하려고 저장소 memory/ 를 원본으로 두고, 자동 메모리 경로를 허브 memory/ 로 향하는 심볼릭 링크로 만든다.
#
# .claude/stacks.json 의 "harness": {"memorySync": "off"|"link"|"commit", "memorySyncPush": false}
#   off    (기본) 아무것도 안 한다
#   link   : SessionStart 에서 자동 메모리 경로 → <허브>/memory 링크 보장 (worktree 마다 슬러그가 달라 매번)
#   commit : link + Stop 에서 허브 memory/ 변경을 커밋 (허브가 base 브랜치일 때만). 인덱스가 길면 오래된 줄을 아카이브로.
#            memorySyncPush=true 면 memory/ 만 바뀐 커밋일 때 push 까지.
# 서브커맨드: memory-sync.sh link | commit   — 둘 다 턴을 막지 않는다(항상 exit 0).
#
# memory/ 가 git 에 들어가므로 비밀값(키·비밀번호·토큰)은 메모리에 적지 않는다 — 경로·이름까지만.

SUB=${1:-commit}
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
have_stacks || exit 0
SETTING=$(harness_opt memorySync off)
case "$SETTING" in link|commit) ;; *) exit 0 ;; esac
[ "$SUB" = commit ] && [ "$SETTING" != commit ] && exit 0

COMMON=$(git_common_dir) || exit 0
[ -n "$COMMON" ] || exit 0
HUB=$(dirname "$COMMON")
MEM="$HUB/memory"
[ -d "$MEM" ] || exit 0

INDEX_KEEP=150   # 인덱스가 INDEX_MAX 줄을 넘으면 위 INDEX_KEEP 줄만 남기고 나머지를 아카이브 인덱스로
INDEX_MAX=200

case "$SUB" in
  link)
    SLUG=$(pwd | sed 's#[/.]#-#g')
    DIR="$HOME/.claude/projects/$SLUG"
    LINK="$DIR/memory"
    mkdir -p "$DIR" 2>/dev/null || exit 0
    if [ -L "$LINK" ]; then
      [ "$(readlink "$LINK")" = "$MEM" ] && exit 0
      rm -f "$LINK"
    elif [ -d "$LINK" ]; then
      if [ -z "$(ls -A "$LINK" 2>/dev/null)" ]; then
        rmdir "$LINK"
      else
        ASIDE="$DIR/memory.pre-repo-$(date +%Y%m%d%H%M%S)"
        mv "$LINK" "$ASIDE"
        MISSING=$(cd "$ASIDE" && ls *.md 2>/dev/null | while read -r f; do [ -f "$MEM/$f" ] || echo "$f"; done | grep -v '^MEMORY.md$' | head -20)
        echo "[Memory] 이 컴퓨터의 자동 메모리를 $ASIDE 로 옮겨 두고 저장소 memory/ 로 링크함"
        [ -n "$MISSING" ] && echo "  ↳ 저장소에 없는 파일(옮겨 넣을지 확인): $(echo "$MISSING" | paste -sd' ' -)"
      fi
    fi
    ln -s "$MEM" "$LINK" 2>/dev/null && echo "[Memory] 자동 메모리 경로 → 저장소 memory/ 링크 ($SLUG)"
    ;;
  commit)
    cd "$HUB" || exit 0
    BASE=$(base_branch)
    BRANCH=$(git branch --show-current 2>/dev/null)
    if [ "$BRANCH" != "$BASE" ]; then
      git status --porcelain -- memory 2>/dev/null | grep -q . && echo "[Memory] 허브가 $BASE 가 아님($BRANCH) — memory/ 커밋 보류"
      exit 0
    fi
    git status --porcelain -- memory 2>/dev/null | grep -q . || exit 0
    if [ -f "$MEM/MEMORY.md" ] && command -v python3 &>/dev/null; then
      python3 - "$MEM" "$INDEX_KEEP" "$INDEX_MAX" <<'PY'
import sys, os, datetime
mem, keep, mx = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
p = f"{mem}/MEMORY.md"; a = f"{mem}/memory-archive-index.md"
lines = open(p, encoding="utf-8").read().split("\n")
idx = [i for i, l in enumerate(lines) if l.startswith("- ")]
if len(idx) <= mx: sys.exit(0)
move = set(idx[keep:])
moved = [lines[i] for i in sorted(move)]
rest = [l for i, l in enumerate(lines) if i not in move]
open(p, "w", encoding="utf-8").write("\n".join(rest).rstrip("\n") + "\n")
arch = open(a, encoding="utf-8").read().rstrip("\n") if os.path.exists(a) else "# Memory archive index\n\n> MEMORY.md 용량 한도로 옮긴 과거 항목. 한 줄 = 메모리 파일 하나."
open(a, "w", encoding="utf-8").write(arch + f"\n\n## {datetime.date.today().isoformat()} 인덱스 정리로 이동\n\n" + "\n".join(moved) + "\n")
print(f"[Memory] 인덱스 {len(idx)}줄 → {keep}줄, {len(moved)}줄을 memory-archive-index.md 로 이동")
PY
    fi
    git add -A -- memory 2>/dev/null
    if ! git diff --cached --quiet -- memory; then
      N=$(git diff --cached --name-only -- memory | grep -vc 'MEMORY.md$')
      NAMES=$(git diff --cached --name-only -- memory | grep -v 'MEMORY.md$' | sed 's#memory/##; s#\.md$##' | head -3 | paste -sd' ' -)
      git commit -q --no-verify -m "docs(memory): 메모리 ${N}건 — ${NAMES:-index}" -- memory \
        && echo "[Memory] memory/ ${N}건 커밋 ($BASE)"
    fi
    harness_on memorySyncPush false || exit 0
    # push — 올라갈 커밋이 memory/ 만 건드릴 때만. 올릴 게 없으면 네트워크를 쓰지 않는다
    [ "$(git rev-list --count "origin/$BASE..HEAD" 2>/dev/null || echo 0)" -gt 0 ] || exit 0
    run_timeout 30 git fetch -q origin "$BASE" 2>/dev/null || { echo "[Memory] origin fetch 실패 — push 는 다음에"; exit 0; }
    if ! git merge-base --is-ancestor "origin/$BASE" HEAD; then
      echo "[Memory] $BASE 가 origin 과 갈라짐 — git pull --rebase 후 직접 push"
      exit 0
    fi
    if git diff --name-only "origin/$BASE..HEAD" | grep -qv '^memory/'; then
      echo "[Memory] 로컬 $BASE 에 memory 외 커밋이 있어 push 보류 — 직접 git push"
      exit 0
    fi
    run_timeout 60 git push -q --no-verify origin "$BASE" >/dev/null 2>&1 \
      && echo "[Memory] origin/$BASE 로 push 완료" \
      || echo "[Memory] push 실패(네트워크·권한) — 커밋은 남아 있음"
    ;;
  *) echo "usage: memory-sync.sh link|commit" >&2 ;;
esac
exit 0
