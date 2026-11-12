#!/bin/bash
# .claude/hooks/session-start.sh
# SessionStart hook — 간결한 프로젝트 컨텍스트 주입 (Claude·Codex 공통)
#
# AGENTS.md 와 별개로 git 상태·활성 스택·worktree·인계 메모만 요약. 매 세션 로드되므로 출력은 ~30줄 이내.
# stacks.json 이 없어도 최소 컨텍스트(날짜·git)는 출력한다. 실패해도 세션을 막지 않는다.

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
cd "$ROOT" 2>/dev/null || true

echo "[Context] $(date +%Y-%m-%d)"

# 1) 스택 정보
if have_stacks; then
  MODE=$(command -v jq &>/dev/null && jq -r '.mode // "single"' "$STACKS_FILE" 2>/dev/null || echo "?")
  STACKS=$(stacks_list | awk -F'\t' '{printf "%s%s@%s", (NR>1?", ":""), $1, $2}')
  [ -n "$STACKS" ] && echo "[Stacks] mode=$MODE · $STACKS" || echo "[Stacks] mode=$MODE"
fi

# 2) Git 상태
if git rev-parse --git-dir &>/dev/null; then
  BRANCH=$(git branch --show-current 2>/dev/null); BRANCH=${BRANCH:-detached}
  CHANGED=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
  AHEAD=$(git rev-list --count @{u}..HEAD 2>/dev/null || echo "?")
  echo "[Git] branch=$BRANCH · changed=$CHANGED · ahead=$AHEAD"

  LAST_COMMITS=$(git log --oneline -3 2>/dev/null | head -3)
  if [ -n "$LAST_COMMITS" ]; then
    echo "[Recent]"
    echo "$LAST_COMMITS" | sed 's/^/  /'
  fi

  # 3) Worktree 격리 상태 — worktreeGuard 가 켜진 프로젝트만
  if have_stacks && harness_on worktreeGuard true; then
    if is_hub; then
      echo "[Worktree] ⚠ 메인 체크아웃(허브)에서 실행 중 — 소스 편집은 worktree-guard 가 차단합니다."
      echo "  ↳ 작업 시작: /start <기능명>  또는  git worktree add .worktrees/<type-name> -b <type>/<name> origin/$(base_branch)"
    else
      echo "[Worktree] ✓ 격리된 worktree 안에서 실행 중 (편집 허용)"
    fi
    WT_COUNT=$(git worktree list 2>/dev/null | grep -c "/.worktrees/")
    [ "${WT_COUNT:-0}" -gt 0 ] && echo "  활성 worktree: ${WT_COUNT}개 (git worktree list)"
  fi

  # 4) 인계 메모(/handoff) — 다른 에이전트·이전 세션이 이 worktree 에 남긴 상태
  HANDOFF="$(git rev-parse --path-format=absolute --git-dir 2>/dev/null)/handoff.md"
  if [ -f "$HANDOFF" ]; then
    echo "[Handoff] 이전 세션의 인계 메모 — 이어서 작업하라 (다 넘겨받았으면 /handoff clear)"
    head -40 "$HANDOFF" | sed 's/^/  /'
  fi

  # 5) git 훅(.claude/githooks) — 빌드·커버리지·허브 커밋·시크릿 게이트를 도구와 무관하게 git 훅으로 돌린다
  #    자동 활성화는 stacks.json 에 "harness": {"gitHooks": true} 를 명시했을 때만 (/init 이 사용자에게 묻고 기록)
  if have_stacks && [ -d .claude/githooks ]; then
    HP=$(git config core.hooksPath 2>/dev/null)
    if [ -z "$HP" ]; then
      if harness_on gitHooks false; then
        if [ -f .claude/scripts/setup-git-hooks.sh ]; then
          bash .claude/scripts/setup-git-hooks.sh >/dev/null 2>&1 && echo "[GitHooks] core.hooksPath=.claude/githooks 설정함"
        else
          git config core.hooksPath .claude/githooks && echo "[GitHooks] core.hooksPath=.claude/githooks 설정함"
        fi
      else
        echo "[GitHooks] 미활성 — 켜려면: bash .claude/scripts/setup-git-hooks.sh"
      fi
    elif [ "$HP" != ".claude/githooks" ]; then
      echo "[GitHooks] core.hooksPath=$HP (다른 훅 관리자) — 스타터 git 훅 미사용"
    fi
  fi
fi

# 6) 프로젝트 메모리
if have_stacks && [ "$(harness_opt memorySync off)" != "off" ]; then
  bash "$(dirname "${BASH_SOURCE[0]}")/memory-sync.sh" link 2>/dev/null || true
  HUB=$(dirname "$(git_common_dir)" 2>/dev/null)
  if [ -f "$HUB/memory/MEMORY.md" ]; then
    MEM_N=$(ls "$HUB"/memory/*.md 2>/dev/null | wc -l | tr -d ' ')
    MEM_DIRTY=$(git -C "$HUB" status --porcelain -- memory 2>/dev/null | wc -l | tr -d ' ')
    echo "[Memory] 저장소 memory/ (원본) · 항목 ${MEM_N} · 미커밋 ${MEM_DIRTY} — 인덱스 MEMORY.md, 검색 grep -ril <키워드> memory/"
  fi
elif [ -f memory/MEMORY.md ]; then
  echo "[Memory] memory/MEMORY.md 로드 가능"
fi

# 7) enabledPlugins (Claude 전용 — settings.json + settings.local.json)
if command -v jq &>/dev/null && [ -f .claude/settings.json ]; then
  PLUGINS=$(jq -r '.enabledPlugins // {} | to_entries[] | select(.value==true) | .key' \
              .claude/settings.json .claude/settings.local.json 2>/dev/null | sort -u | paste -sd, -)
  if [ -n "$PLUGINS" ]; then
    echo "[Plugins] $PLUGINS"
    echo "  ↳ 미설치 시: /plugin install <name>  ·  활성/비활성: /plugin"
  fi
fi

# 8) Telemetry 요약 (opt-in — usage-counter.sh 가 쌓은 로컬 파일이 있을 때만)
if command -v jq &>/dev/null && [ -f .claude/.usage.json ]; then
  TOP5=$(jq -r '.tools | to_entries | sort_by(-.value) | .[:5] | .[] | "\(.key)=\(.value)"' \
           .claude/.usage.json 2>/dev/null | paste -sd, -)
  SINCE=$(jq -r '.since // "?"' .claude/.usage.json 2>/dev/null)
  [ -n "$TOP5" ] && echo "[Usage] since=$SINCE · top5: $TOP5"
fi

exit 0
