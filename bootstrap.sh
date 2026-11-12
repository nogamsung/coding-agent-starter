#!/bin/bash
# Coding Agent Starter — 부트스트랩 스크립트 (Claude Code · Codex 공용)
#
# 신규 설치 또는 기존 프로젝트 업데이트에 모두 사용합니다.
#
# 사용법:
#   curl -fsSL https://raw.githubusercontent.com/nogamsung/coding-agent-starter/main/bootstrap.sh | bash
#   curl -fsSL .../bootstrap.sh | bash -s -- --platform codex
#   curl -fsSL .../bootstrap.sh | bash -s -- --version v2.0.0
#   curl -fsSL .../bootstrap.sh | bash -s -- --no-preserve
#
# 옵션:
#   --platform <p>    claude | codex | both. 기본: 이전 설치값 → 없으면 설치된 CLI 로 자동 감지(둘 다/없음 = both)
#   --version <ref>   특정 git 태그/브랜치/커밋으로 핀 (예: v2.0.0). 기본: main HEAD
#   --no-preserve     update 시 사용자 추가 자산도 모두 덮어씀 (기본: 보존)
#   --preserve        명시적 보존 (기본 동작이지만 의도 표시용)
#
# 설치 위치:
#   공통    .agents/skills/<name>/SKILL.md (skill 원본) · .claude/{agents,hooks,scripts,githooks,templates}
#   claude  .claude/settings.json · .claude/skills → ../.agents/skills (심볼릭 링크)
#   codex   .codex/{hooks.json,rules/,agents/,config.toml}
#
# 보존 대상 (update 모드 + 기본 동작):
#   .claude/agents/custom/  .claude/commands/custom/  .claude/hooks/custom/
#   .claude/settings.local.json · .codex/config.toml · .codex/rules/ 의 사용자 규칙
#   스타터가 배포하지 않은 .agents/skills/<name>/ (사용자 skill)
#   memory/ · AGENTS.md 는 건드리지 않음

set -e

REPO_URL="https://github.com/nogamsung/coding-agent-starter.git"
TMP_DIR=$(mktemp -d)
TARGET_DIR="$(pwd)"
PRESERVE_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR" "$PRESERVE_DIR"' EXIT

# --- 인자 파싱 ---
VERSION_REF=""
PRESERVE=true
PLATFORM=""
while [ $# -gt 0 ]; do
  case "$1" in
    --version) VERSION_REF="$2"; shift 2 ;;
    --version=*) VERSION_REF="${1#*=}"; shift ;;
    --platform) PLATFORM="$2"; shift 2 ;;
    --platform=*) PLATFORM="${1#*=}"; shift ;;
    --no-preserve) PRESERVE=false; shift ;;
    --preserve) PRESERVE=true; shift ;;
    -h|--help)
      sed -n '2,30p' "$0"
      exit 0 ;;
    *) echo "❌ 알 수 없는 옵션: $1"; exit 1 ;;
  esac
done

# --- 모드 감지 ---
if [ -d "$TARGET_DIR/.claude" ] || [ -d "$TARGET_DIR/.agents/skills" ] || [ -f "$TARGET_DIR/.codex/hooks.json" ]; then
  MODE="update"
  OLD_VERSION="(unknown)"
  [ -f "$TARGET_DIR/.claude/.starter-version" ] && OLD_VERSION=$(cat "$TARGET_DIR/.claude/.starter-version")
else
  MODE="install"
  PRESERVE=false   # install 시엔 보존할 게 없음
fi

# --- 플랫폼 결정 ---
if [ -z "$PLATFORM" ] && [ -f "$TARGET_DIR/.claude/.starter-platform" ]; then
  PLATFORM=$(tr -d '[:space:]' < "$TARGET_DIR/.claude/.starter-platform")
fi
if [ -z "$PLATFORM" ]; then
  HAS_CLAUDE=false; HAS_CODEX=false
  command -v claude &>/dev/null && HAS_CLAUDE=true
  command -v codex &>/dev/null && HAS_CODEX=true
  if [ "$HAS_CLAUDE" = true ] && [ "$HAS_CODEX" = false ]; then PLATFORM=claude
  elif [ "$HAS_CODEX" = true ] && [ "$HAS_CLAUDE" = false ]; then PLATFORM=codex
  else PLATFORM=both; fi
fi
case "$PLATFORM" in
  claude|codex|both) ;;
  *) echo "❌ --platform 은 claude | codex | both 중 하나: $PLATFORM"; exit 1 ;;
esac
WANT_CLAUDE=false; WANT_CODEX=false
[ "$PLATFORM" != codex ] && WANT_CLAUDE=true
[ "$PLATFORM" != claude ] && WANT_CODEX=true

echo "📦 Coding Agent Starter"
echo "   대상 디렉토리: $TARGET_DIR"
echo "   모드: $MODE · 플랫폼: $PLATFORM"
[ "$MODE" = "update" ] && echo "   현재 버전: $OLD_VERSION"
[ -n "$VERSION_REF" ] && echo "   버전 핀: $VERSION_REF"
[ "$MODE" = "update" ] && echo "   보존 모드: $([ "$PRESERVE" = true ] && echo 'on (custom/ · 사용자 skill · settings.local.json · .codex/config.toml)' || echo 'off (전체 교체)')"
echo ""

if [ "$MODE" = "update" ] && [ "$PRESERVE" = false ]; then
  echo "⚠️  --no-preserve: .claude/ · .agents/skills/ · .codex/ 가 백업 없이 전체 교체됩니다."
  echo "    memory/ 와 AGENTS.md 는 건드리지 않습니다."
  echo ""
fi

# --- 다운로드 (full depth=1 — sparse-checkout 은 cone 모드에서 파일을 거부) ---
# STARTER_SRC=<로컬 체크아웃> 이면 clone 대신 그 내용을 쓴다 (CI·로컬 검증용, --version 과 함께 쓰지 않음)
if [ -n "${STARTER_SRC:-}" ] && [ -z "$VERSION_REF" ]; then
  for item in .claude .agents .codex VERSION; do
    [ -e "$STARTER_SRC/$item" ] && cp -R "$STARTER_SRC/$item" "$TMP_DIR/"
  done
else
  git clone --quiet --depth=1 "$REPO_URL" "$TMP_DIR" 2>/dev/null
fi
if [ -n "$VERSION_REF" ]; then
  # depth=1 클론엔 임의 ref 없으니 다시 fetch
  (cd "$TMP_DIR" && git fetch --quiet --depth=1 origin "$VERSION_REF" 2>/dev/null && git checkout --quiet FETCH_HEAD) || {
    echo "❌ 버전 ref '$VERSION_REF' 를 origin 에서 찾지 못했습니다."
    echo "   사용 가능한 태그: https://github.com/nogamsung/coding-agent-starter/tags"
    exit 1
  }
fi
SRC="$TMP_DIR"
LEGACY=false   # v1.x (commands/ + 평면 skills/*.md) 핀 설치
[ -d "$SRC/.agents/skills" ] || LEGACY=true

# --- 보존 대상 백업 ---
if [ "$PRESERVE" = true ] && [ "$MODE" = "update" ]; then
  for sub in agents/custom commands/custom hooks/custom skills/custom; do
    [ -d "$TARGET_DIR/.claude/$sub" ] || continue
    [ "$sub" = skills/custom ] && [ -L "$TARGET_DIR/.claude/skills" ] && continue   # v2 는 .agents/skills 로 따로 보존
    mkdir -p "$PRESERVE_DIR/claude/$(dirname "$sub")"
    cp -R "$TARGET_DIR/.claude/$sub" "$PRESERVE_DIR/claude/$sub"
  done
  [ -f "$TARGET_DIR/.claude/settings.local.json" ] && cp "$TARGET_DIR/.claude/settings.local.json" "$PRESERVE_DIR/settings.local.json"
  [ -f "$TARGET_DIR/.codex/config.toml" ] && cp "$TARGET_DIR/.codex/config.toml" "$PRESERVE_DIR/codex-config.toml"
  if [ -d "$TARGET_DIR/.codex/rules" ]; then
    mkdir -p "$PRESERVE_DIR/codex-rules"
    for r in "$TARGET_DIR"/.codex/rules/*; do
      [ -f "$r" ] || continue
      [ -f "$SRC/.codex/rules/$(basename "$r")" ] || cp "$r" "$PRESERVE_DIR/codex-rules/"
    done
  fi
fi

# --- 이전 버전 기록 (rollback 용) ---
PREV_VERSION=""
[ "$MODE" = "update" ] && [ -f "$TARGET_DIR/.claude/.starter-version" ] && PREV_VERSION=$(cat "$TARGET_DIR/.claude/.starter-version")
PREV_SKILLS=""
[ -f "$TARGET_DIR/.claude/.starter-skills" ] && PREV_SKILLS=" $(tr '\n' ' ' < "$TARGET_DIR/.claude/.starter-skills") "

# --- .claude/ 교체 ---
rm -rf "$TARGET_DIR/.claude"
cp -R "$SRC/.claude" "$TARGET_DIR/"
rm -f "$TARGET_DIR/.claude/settings.local.json"   # 스타터 저장소 개인 설정은 배포하지 않음

# --- .agents/skills 교체 (사용자 skill 은 보존) ---
if [ "$LEGACY" = false ]; then
  rm -rf "$TARGET_DIR/.claude/skills"
  mkdir -p "$TARGET_DIR/.agents/skills"
  UPSTREAM_SKILLS=$(cd "$SRC/.agents/skills" && for d in */; do [ -f "$d/SKILL.md" ] && echo "${d%/}"; done)
  for d in "$TARGET_DIR"/.agents/skills/*/; do
    [ -d "$d" ] || continue
    name=$(basename "$d")
    if [ "$PRESERVE" = false ] || echo "$UPSTREAM_SKILLS" | grep -qx "$name"; then
      rm -rf "$d"                                      # 스타터 skill → 새 버전으로 교체
    else
      case "$PREV_SKILLS" in *" $name "*) rm -rf "$d" ;; esac   # 이전 버전에서만 배포되고 지금은 빠진 skill
    fi
  done
  for name in $UPSTREAM_SKILLS; do
    cp -R "$SRC/.agents/skills/$name" "$TARGET_DIR/.agents/skills/$name"
  done
  echo "$UPSTREAM_SKILLS" > "$TARGET_DIR/.claude/.starter-skills"
fi

# --- 보존 자산 복원 ---
if [ "$PRESERVE" = true ] && [ "$MODE" = "update" ]; then
  for sub in agents/custom commands/custom hooks/custom; do
    if [ -d "$PRESERVE_DIR/claude/$sub" ]; then
      mkdir -p "$TARGET_DIR/.claude/$(dirname "$sub")"
      cp -R "$PRESERVE_DIR/claude/$sub" "$TARGET_DIR/.claude/$sub"
    fi
  done
  # v1 의 .claude/skills/custom/*.md → v2 의 .agents/skills/<name>/SKILL.md
  if [ -d "$PRESERVE_DIR/claude/skills/custom" ]; then
    if [ "$LEGACY" = true ]; then
      mkdir -p "$TARGET_DIR/.claude/skills"
      cp -R "$PRESERVE_DIR/claude/skills/custom" "$TARGET_DIR/.claude/skills/custom"
    else
      for f in "$PRESERVE_DIR"/claude/skills/custom/*.md; do
        [ -f "$f" ] || continue
        name=$(basename "$f" .md)
        out="$TARGET_DIR/.agents/skills/$name/SKILL.md"
        [ -e "$out" ] && continue
        mkdir -p "$(dirname "$out")"
        if head -1 "$f" | grep -q '^---$'; then
          if sed -n '2,/^---$/p' "$f" | grep -q '^name:'; then cp "$f" "$out"
          else { echo '---'; echo "name: $name"; tail -n +2 "$f"; } > "$out"; fi
        else
          { echo '---'; echo "name: $name"; echo "description: 사용자 skill ($name)"; echo '---'; echo; cat "$f"; } > "$out"
        fi
        echo "   ↪ custom skill 이전: .claude/skills/custom/$name.md → .agents/skills/$name/SKILL.md"
      done
    fi
  fi
  [ -f "$PRESERVE_DIR/settings.local.json" ] && cp "$PRESERVE_DIR/settings.local.json" "$TARGET_DIR/.claude/settings.local.json"
fi

# --- 플랫폼별 배치 ---
if [ "$LEGACY" = false ]; then
  if [ "$WANT_CLAUDE" = true ]; then
    ln -sfn ../.agents/skills "$TARGET_DIR/.claude/skills"
  else
    rm -f "$TARGET_DIR/.claude/settings.json"
  fi

  if [ "$WANT_CODEX" = true ] && [ -d "$SRC/.codex" ]; then
    mkdir -p "$TARGET_DIR/.codex"
    rm -rf "$TARGET_DIR/.codex/agents" "$TARGET_DIR/.codex/hooks.json" "$TARGET_DIR/.codex/README.md"
    [ "$PRESERVE" = false ] && rm -rf "$TARGET_DIR/.codex/rules"
    for item in "$SRC"/.codex/*; do
      name=$(basename "$item")
      case "$name" in
        config.toml) [ -f "$TARGET_DIR/.codex/config.toml" ] || cp "$item" "$TARGET_DIR/.codex/config.toml" ;;
        rules) mkdir -p "$TARGET_DIR/.codex/rules"; cp -R "$item"/. "$TARGET_DIR/.codex/rules/" ;;
        *) cp -R "$item" "$TARGET_DIR/.codex/$name" ;;
      esac
    done
    if [ -d "$PRESERVE_DIR/codex-rules" ]; then cp -R "$PRESERVE_DIR/codex-rules"/. "$TARGET_DIR/.codex/rules/"; fi
    if [ -f "$PRESERVE_DIR/codex-config.toml" ]; then cp "$PRESERVE_DIR/codex-config.toml" "$TARGET_DIR/.codex/config.toml"; fi
  fi
fi

# --- 버전·플랫폼 메타 기록 ---
NEW_VERSION=$(cat "$SRC/VERSION" 2>/dev/null || echo "unknown")
echo "$NEW_VERSION" > "$TARGET_DIR/.claude/.starter-version"
echo "$PLATFORM" > "$TARGET_DIR/.claude/.starter-platform"
[ -n "$PREV_VERSION" ] && echo "$PREV_VERSION" > "$TARGET_DIR/.claude/.starter-version-prev"

echo "✅ 설치 완료 (버전: $NEW_VERSION · 플랫폼: $PLATFORM)"
[ -f "$TARGET_DIR/.claude/.starter-version-prev" ] && echo "   이전 버전: $(cat "$TARGET_DIR/.claude/.starter-version-prev") (rollback 가능 — /starter rollback)"
echo ""

# --- v1 → v2 지침 파일 이전 안내 ---
if [ "$LEGACY" = false ] && [ -f "$TARGET_DIR/CLAUDE.md" ]; then
  echo "⚠️  CLAUDE.md 가 있습니다. v2 의 지침 파일은 AGENTS.md 하나입니다 (Claude Code·Codex 공통)."
  echo "    CLAUDE.md 가 남아 있으면 Claude Code 는 AGENTS.md 를 읽지 않습니다. 이전:"
  echo "      bash .claude/scripts/migrate-agents-md.sh          # dry-run"
  echo "      bash .claude/scripts/migrate-agents-md.sh --apply  # git mv CLAUDE.md → AGENTS.md (하위 디렉토리 포함)"
  echo ""
fi

if [ "$MODE" = "install" ]; then
  cat <<'EOF'
🚀 첫 사용자 5분 가이드 — Claude Code 또는 Codex 에서 이 디렉토리를 연 뒤:

  1. /init                      # 스택 자동 감지 + 하네스 구성 (AGENTS.md · settings · git 훅)
                                # 또는 명시: /init {kotlin|go|python|nextjs|flutter|infra|marketing|sales|product}[-multi]
  2. /start <기능 이름>         # worktree + PRD + 자동 구현 (한 번에)
  3. /commit                    # 작업 후 — feature 브랜치면 /pr 자동 제안
  4. /pr → /merge               # 리뷰·머지·태그·worktree 정리 자동 체인

  Codex 에서는 skill 을 `$init`, `$start` 처럼 부르거나 자연어로 요청하면 됩니다.

📚 자세히: README.md (English: README.en.md)

🔧 갱신 / 롤백:
  /starter check                # 현재·최신·이전 버전 표시
  /upgrade                      # 카테고리별 변경 통계 (부분 갱신 · optional skill 설치)
EOF
else
  cat <<EOF
🔄 갱신 완료 (v${PREV_VERSION:-unknown} → v$NEW_VERSION)

다음 단계:
  1. Claude Code / Codex 재시작        # 새 skill·hook 인식
  2. /upgrade                          # 변경 통계 확인 (선택)
  3. /init                             # 스택 설정이 변경됐다면 재실행

문제 발견 시:
  /starter rollback                    # 직전 버전으로 즉시 복원 (toggle)
EOF
fi
