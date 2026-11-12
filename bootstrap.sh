#!/bin/bash
# Coding Agent Starter — 부트스트랩 스크립트
#
# 신규 설치 또는 기존 프로젝트 업데이트에 모두 사용합니다.
#
# 사용법:
#   curl -fsSL https://raw.githubusercontent.com/nogamsung/coding-agent-starter/main/bootstrap.sh | bash
#   curl -fsSL https://raw.githubusercontent.com/nogamsung/coding-agent-starter/main/bootstrap.sh | bash -s -- --version v1.18.0
#   curl -fsSL https://raw.githubusercontent.com/nogamsung/coding-agent-starter/main/bootstrap.sh | bash -s -- --no-preserve
#
# 옵션:
#   --version <ref>   특정 git 태그/브랜치/커밋으로 핀 (예: v1.17.0). 기본: main HEAD
#   --no-preserve    update 시 사용자 추가 자산도 모두 덮어씀 (기본: 보존)
#   --preserve       명시적 보존 (기본 동작이지만 의도 표시용)
#
# 보존 대상 (update 모드 + 기본 동작):
#   .claude/agents/custom/    .claude/commands/custom/
#   .claude/hooks/custom/     .claude/skills/custom/
#   .claude/settings.local.json
#   .claude/.starter-version-prev (rollback 용 자동 생성)

set -e

REPO_URL="https://github.com/nogamsung/coding-agent-starter.git"
TMP_DIR=$(mktemp -d)
TARGET_DIR="$(pwd)"
PRESERVE_DIR=$(mktemp -d)

# --- 인자 파싱 ---
VERSION_REF=""
PRESERVE=true
while [ $# -gt 0 ]; do
  case "$1" in
    --version) VERSION_REF="$2"; shift 2 ;;
    --version=*) VERSION_REF="${1#*=}"; shift ;;
    --no-preserve) PRESERVE=false; shift ;;
    --preserve) PRESERVE=true; shift ;;
    -h|--help)
      sed -n '2,21p' "$0"
      exit 0 ;;
    *) echo "❌ 알 수 없는 옵션: $1"; exit 1 ;;
  esac
done

# --- 모드 감지 ---
if [ -d "$TARGET_DIR/.claude" ]; then
  MODE="update"
  OLD_VERSION="(unknown)"
  [ -f "$TARGET_DIR/.claude/.starter-version" ] && OLD_VERSION=$(cat "$TARGET_DIR/.claude/.starter-version")
else
  MODE="install"
  PRESERVE=false   # install 시엔 보존할 게 없음
fi

echo "📦 Coding Agent Starter"
echo "   대상 디렉토리: $TARGET_DIR"
echo "   모드: $MODE"
[ "$MODE" = "update" ] && echo "   현재 버전: $OLD_VERSION"
[ -n "$VERSION_REF" ] && echo "   버전 핀: $VERSION_REF"
[ "$MODE" = "update" ] && echo "   보존 모드: $([ "$PRESERVE" = true ] && echo 'on (custom/ + settings.local.json)' || echo 'off (전체 교체)')"
echo ""

# --- update 경고 ---
if [ "$MODE" = "update" ]; then
  if [ "$PRESERVE" = true ]; then
    echo "ℹ️  기본 보존 항목 외 .claude/ 내부 변경사항은 모두 교체됩니다."
    echo "    보존: agents/custom · commands/custom · hooks/custom · skills/custom · settings.local.json"
    echo "    교체: 그 외 모든 .claude/ 파일 · memory/ 폴더는 건드리지 않음"
  else
    echo "⚠️  --no-preserve: .claude/ 가 백업 없이 전체 교체됩니다."
    echo "    수정한 agent · 추가한 command · hooks · settings.local.json 모두 사라짐."
    echo "    memory/ 폴더는 건드리지 않습니다."
  fi
  echo ""
fi

# --- 보존 대상 백업 ---
if [ "$PRESERVE" = true ] && [ "$MODE" = "update" ]; then
  for sub in agents/custom commands/custom hooks/custom skills/custom; do
    if [ -d "$TARGET_DIR/.claude/$sub" ]; then
      mkdir -p "$PRESERVE_DIR/$(dirname "$sub")"
      cp -r "$TARGET_DIR/.claude/$sub" "$PRESERVE_DIR/$sub"
    fi
  done
  [ -f "$TARGET_DIR/.claude/settings.local.json" ] && cp "$TARGET_DIR/.claude/settings.local.json" "$PRESERVE_DIR/settings.local.json"
fi

# --- 다운로드 (full depth=1 — sparse-checkout 은 cone 모드에서 파일을 거부) ---
git clone --quiet --depth=1 "$REPO_URL" "$TMP_DIR" 2>/dev/null
cd "$TMP_DIR"
if [ -n "$VERSION_REF" ]; then
  # depth=1 클론엔 임의 ref 없으니 다시 fetch
  git fetch --quiet --depth=1 origin "$VERSION_REF" 2>/dev/null || {
    echo "❌ 버전 ref '$VERSION_REF' 를 origin 에서 찾지 못했습니다."
    echo "   사용 가능한 태그: https://github.com/nogamsung/coding-agent-starter/tags"
    rm -rf "$TMP_DIR" "$PRESERVE_DIR"
    exit 1
  }
  git checkout --quiet FETCH_HEAD
fi
cd "$TARGET_DIR"

# --- 이전 버전 기록 (rollback 용) ---
if [ "$MODE" = "update" ] && [ -f "$TARGET_DIR/.claude/.starter-version" ]; then
  PREV_VERSION=$(cat "$TARGET_DIR/.claude/.starter-version")
  mkdir -p "$PRESERVE_DIR/_meta"
  echo "$PREV_VERSION" > "$PRESERVE_DIR/_meta/.starter-version-prev"
fi

# --- 교체 ---
rm -rf "$TARGET_DIR/.claude"
cp -r "$TMP_DIR/.claude" "$TARGET_DIR/"

# --- 보존 자산 복원 ---
if [ "$PRESERVE" = true ] && [ "$MODE" = "update" ]; then
  for sub in agents/custom commands/custom hooks/custom skills/custom; do
    if [ -d "$PRESERVE_DIR/$sub" ]; then
      mkdir -p "$TARGET_DIR/.claude/$(dirname "$sub")"
      cp -r "$PRESERVE_DIR/$sub" "$TARGET_DIR/.claude/$sub"
    fi
  done
  [ -f "$PRESERVE_DIR/settings.local.json" ] && cp "$PRESERVE_DIR/settings.local.json" "$TARGET_DIR/.claude/settings.local.json"
fi

# --- 버전 메타 기록 ---
NEW_VERSION=$(cat "$TMP_DIR/VERSION" 2>/dev/null || echo "unknown")
echo "$NEW_VERSION" > "$TARGET_DIR/.claude/.starter-version"
[ -f "$PRESERVE_DIR/_meta/.starter-version-prev" ] && cp "$PRESERVE_DIR/_meta/.starter-version-prev" "$TARGET_DIR/.claude/.starter-version-prev"

rm -rf "$TMP_DIR" "$PRESERVE_DIR"

echo "✅ .claude/ 설치 완료 (버전: $NEW_VERSION)"
[ -f "$TARGET_DIR/.claude/.starter-version-prev" ] && echo "   이전 버전: $(cat "$TARGET_DIR/.claude/.starter-version-prev") (rollback 가능 — /starter rollback)"
echo ""

if [ "$MODE" = "install" ]; then
  cat <<'EOF'
🚀 첫 사용자 5분 가이드 — Claude Code 에서 이 디렉토리를 연 뒤:

  1. /init                      # 스택 자동 감지 + 하네스 구성
                                # 또는 명시: /init {kotlin|go|python|nextjs|flutter|infra|marketing|sales|product}[-multi]
  2. /start <기능 이름>         # worktree + PRD + 자동 구현 (한 번에)
  3. /commit                    # 작업 후 — feature 브랜치면 /pr 자동 제안
  4. /pr → /merge               # 머지·태그·worktree 정리 자동 체인

📚 자세히:
  • 빠른 시작 / 스택 표 / Agent 목록 → README.md
  • English documentation     → README.en.md
  • 보존 정책 (custom/) / 옵션 → README.md 의 "방법 A" 섹션

🔧 갱신 / 롤백:
  /starter check                # 현재·최신·이전 버전 표시
  /upgrade                      # 카테고리별 변경 통계 (skills, agents 등 부분 갱신)

💬 모드별 plugin 설치 알림 (필요 시):
  marketing/sales — /plugin install marketing-skills@marketingskills
  product         — /plugin marketplace add phuryn/pm-skills 후 8개 pm-* 설치
EOF
else
  cat <<EOF
🔄 갱신 완료 (v$([ -f "$TARGET_DIR/.claude/.starter-version-prev" ] && cat "$TARGET_DIR/.claude/.starter-version-prev" || echo unknown) → v$NEW_VERSION)

다음 단계:
  1. Claude Code 재시작                # 새 커맨드·hook·skill 인식
  2. /upgrade                          # 변경 통계 확인 (선택)
  3. /init                             # 스택 설정이 변경됐다면 재실행

문제 발견 시:
  /starter rollback                    # 직전 버전으로 즉시 복원 (toggle)
EOF
fi
