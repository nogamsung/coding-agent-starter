---
name: handoff
description: 작업을 다른 에이전트(Claude↔Codex)나 새 세션에 넘길 인계 메모 작성 — 사용 한도·도구 전환 때. 다음 세션 시작 시 자동으로 읽힌다.
argument-hint: "(없음) | clear"
disable-model-invocation: true
---

지금 worktree 의 작업 상태를 인계 메모로 남긴다. 같은 worktree 에서 Claude 든 Codex 든 새 세션을 열면 SessionStart 훅(`.claude/hooks/session-start.sh`)이 이 메모를 컨텍스트에 넣는다 — 대화 기록 전체가 아니라 **이어받는 데 필요한 상태만** 넘긴다.

**인자:** $ARGUMENTS

## 위치

```bash
HANDOFF="$(git rev-parse --git-dir)/handoff.md"   # worktree 마다 하나 · git 이 추적하지 않음
```

`clear` 면 `rm -f "$HANDOFF"` 하고 끝. 이어받은 쪽이 작업을 다 넘겨받았으면 지운다.

## 작성

먼저 사실을 모은다 (추측 금지):

```bash
source .claude/hooks/lib.sh 2>/dev/null; BASE=$(base_branch 2>/dev/null || echo main)
git branch --show-current
git log --oneline "origin/$BASE"..HEAD
git status --short
git diff --stat
gh pr view --json number,url,state 2>/dev/null
```

그리고 아래 형식으로 **덮어쓴다** (30줄 이내):

```markdown
# 인계 — <브랜치> · <YYYY-MM-DD HH:MM> · <claude|codex>

## 목표
<사용자가 원한 것 한두 줄. 사용자 말 그대로 인용할 수 있으면 인용>

## 끝난 것
- <커밋·PR·확인한 사실>

## 남은 것 (순서대로)
1. <다음에 할 일 — 파일·명령까지 구체적으로>

## 주의
- <막혔던 것·시도했다 실패한 것·건드리면 안 되는 것·사용자 결정 대기>
```

- 커밋 안 된 변경이 있으면 "## 끝난 것" 에 **커밋 안 됨**이라고 적는다. 가능하면 WIP 커밋을 먼저 만든다 (stash 금지 — 모든 worktree 가 공유).
- 시크릿·토큰은 적지 않는다.
- 작성 후 경로와 요약 한 줄을 사용자에게 알린다.
