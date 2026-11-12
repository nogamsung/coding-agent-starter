#!/bin/bash
# .claude/scripts/setup-git-hooks.sh — 플랫폼 공통 git 훅(.claude/githooks/) 활성화. 클론마다 한 번 (멱등).
#   bash .claude/scripts/setup-git-hooks.sh          # 활성화
#   bash .claude/scripts/setup-git-hooks.sh --off    # 해제 (core.hooksPath unset)
#   bash .claude/scripts/setup-git-hooks.sh --status # 현재 상태만
# core.hooksPath 는 상대경로라 각 worktree 가 자기 브랜치의 .claude/githooks/ 를 쓴다.

HOOKS_PATH=.claude/githooks
ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "[git-hooks] git 저장소가 아님 — 건너뜀"; exit 0; }
cd "$ROOT" || exit 1

status() {
  local cur; cur=$(git config --get core.hooksPath || true)
  if [ "$cur" = "$HOOKS_PATH" ]; then
    echo "[git-hooks] 활성 — core.hooksPath=$HOOKS_PATH (pre-commit: 시크릿·허브 가드 · pre-push: 빌드·커버리지 게이트)"
  elif [ -n "$cur" ]; then
    echo "[git-hooks] 비활성 — core.hooksPath=$cur (다른 훅 경로 사용 중)"
  else
    echo "[git-hooks] 비활성 — core.hooksPath 미설정"
  fi
  command -v gitleaks >/dev/null 2>&1 || echo "[git-hooks] 참고: gitleaks 미설치 — pre-commit 시크릿 스캔 건너뜀 (brew install gitleaks)"
}

case "${1:-}" in
  --status) status; exit 0 ;;
  --off)
    if [ "$(git config --get core.hooksPath || true)" = "$HOOKS_PATH" ]; then
      git config --unset core.hooksPath
      echo "[git-hooks] 해제 — core.hooksPath unset"
    else
      echo "[git-hooks] 이미 해제 상태"
    fi
    exit 0 ;;
  ""|--on) ;;
  *) echo "사용: $0 [--on|--off|--status]" >&2; exit 1 ;;
esac

[ -d "$HOOKS_PATH" ] || { echo "[git-hooks] $HOOKS_PATH 없음 — 스타터 설치 확인"; exit 1; }

CUR=$(git config --get core.hooksPath || true)
if [ -n "$CUR" ] && [ "$CUR" != "$HOOKS_PATH" ]; then
  echo "[git-hooks] ⚠️  기존 core.hooksPath=$CUR 를 $HOOKS_PATH 로 교체합니다 (되돌리기: git config core.hooksPath $CUR)"
fi
git config core.hooksPath "$HOOKS_PATH"
chmod +x "$HOOKS_PATH"/* 2>/dev/null || true

# pre-push 게이트는 원격 접속 뒤에 돈다 — 게이트가 길면 SSH 가 끊겨 push 가 죽는다. 사용자가 정한 sshCommand 는 건드리지 않는다.
if [ -z "$(git config --get core.sshCommand)" ]; then
  git config core.sshCommand "ssh -o ServerAliveInterval=30 -o ServerAliveCountMax=40"
  echo "[git-hooks] core.sshCommand — SSH 연결 유지(30초 간격) 설정"
fi
status
