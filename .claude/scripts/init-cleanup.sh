#!/bin/bash
# .claude/scripts/init-cleanup.sh
# /init 의 Step 2 (불필요한 agent/skill/template 제거) 전담.
# Claude 의 자연어 추론 의존을 deterministic bash 로 대체.
#
# 사용법:
#   bash .claude/scripts/init-cleanup.sh <mode>              # dry-run (디폴트)
#   bash .claude/scripts/init-cleanup.sh <mode> --apply      # 실제 rm
#   bash .claude/scripts/init-cleanup.sh monorepo kotlin nextjs flutter --apply
#
# mode: kotlin|kotlin-multi|go|go-multi|python|python-multi
#       |nextjs|nextjs-multi|flutter|infra
#       |marketing|sales|product|monorepo
#
# 보존 (항상): agents/custom/  commands/custom/  hooks/custom/
#              워크플로 skill(commit·pr·start 등) 전부 · 스타터가 모르는 skill 디렉토리(사용자 작성)
#              settings.local.json  .starter-version*
# skill 원본은 .agents/skills/<name>/SKILL.md (.claude/skills 는 그 심볼릭 링크)

set -eo pipefail

# --- 인자 파싱 ---
MODE=""
APPLY=false
EXTRA_STACKS=""

for arg in "$@"; do
  case "$arg" in
    --apply) APPLY=true ;;
    --dry-run) APPLY=false ;;
    -h|--help) sed -n '2,18p' "$0"; exit 0 ;;
    *)
      if [ -z "$MODE" ]; then MODE="$arg"
      else EXTRA_STACKS="$EXTRA_STACKS $arg"; fi
      ;;
  esac
done

if [ -z "$MODE" ]; then
  echo "❌ mode 인자 필수. -h 로 옵션 확인" >&2
  exit 1
fi

# --- 유지 목록 정의 ---

# 모든 모드 공통
KEEP_AGENTS_COMMON="code-reviewer security-reviewer planner"
KEEP_SKILLS_COMMON="security-patterns observability-patterns mcp-presets"
# 워크플로 skill (구 commands) — 모든 모드에서 유지
WORKFLOW_SKILLS="commit harness init marketing memory merge new plan pr release review rule start starter test upgrade handoff"
SKILLS_DIR=.agents/skills
KEEP_TEMPLATES_COMMON="prd.md role-prompt.md memory.md gitleaks.toml optional-skills.json"

# stack 별 유지 목록 (한 줄에 type:vals 형식)
keep_for_stack() {
  case "$1" in
    kotlin|kotlin-multi)
      echo "agents: kotlin-generator kotlin-modifier kotlin-tester api-designer ui-designer github-actions-designer"
      echo "skills: kotlin-patterns db-patterns api-design-patterns github-actions-patterns docker-patterns cache-patterns"
      echo "templates: AGENTS.${1}.md settings.${1}.json"
      ;;
    go|go-multi)
      echo "agents: go-generator go-modifier go-tester api-designer github-actions-designer"
      echo "skills: go-patterns db-patterns api-design-patterns github-actions-patterns docker-patterns cache-patterns"
      echo "templates: AGENTS.${1}.md settings.${1}.json"
      ;;
    python|python-multi)
      echo "agents: python-generator python-modifier python-tester ai-researcher ai-generator ai-modifier ai-tester api-designer github-actions-designer"
      echo "skills: python-patterns ai-patterns ai-eval-patterns db-patterns api-design-patterns github-actions-patterns docker-patterns cache-patterns"
      echo "templates: AGENTS.${1}.md settings.${1}.json"
      ;;
    nextjs|nextjs-multi)
      echo "agents: nextjs-generator nextjs-modifier nextjs-tester ui-designer github-actions-designer"
      echo "skills: nextjs-patterns ui-design-impl motion-patterns github-actions-patterns docker-patterns cache-patterns"
      echo "templates: AGENTS.${1}.md settings.${1}.json"
      ;;
    flutter)
      echo "agents: flutter-generator flutter-modifier flutter-tester ui-designer github-actions-designer"
      echo "skills: flutter-patterns ui-design-impl motion-patterns github-actions-patterns"
      echo "templates: AGENTS.flutter.md settings.flutter.json"
      ;;
    infra)
      echo "agents: infra-generator github-actions-designer"
      echo "skills: terraform-patterns kubernetes-patterns helm-patterns github-actions-patterns docker-patterns"
      echo "templates: AGENTS.infra.md settings.infra.json"
      ;;
    marketing)
      echo "agents: gtm-planner"
      echo "skills:"
      echo "templates: AGENTS.marketing.md settings.marketing.json marketing-plan.md gtm-history.md"
      ;;
    sales)
      echo "agents: gtm-planner"
      echo "skills:"
      echo "templates: AGENTS.sales.md settings.sales.json sales-plan.md gtm-history.md"
      ;;
    product)
      echo "agents: gtm-planner"
      echo "skills:"
      echo "templates: AGENTS.product.md settings.product.json marketing-plan.md sales-plan.md gtm-history.md"
      ;;
    *)
      echo "❌ 알 수 없는 stack: $1" >&2
      return 1
      ;;
  esac
}

# --- 모드별 유지 목록 누적 ---
KEEP_AGENTS="$KEEP_AGENTS_COMMON"
KEEP_SKILLS="$KEEP_SKILLS_COMMON $WORKFLOW_SKILLS"
KEEP_TEMPLATES="$KEEP_TEMPLATES_COMMON"

accumulate() {
  local stack="$1"
  while IFS= read -r line; do
    local key=$(echo "$line" | cut -d':' -f1)
    local vals=$(echo "$line" | cut -d':' -f2- | sed 's/^ *//')
    case "$key" in
      agents) KEEP_AGENTS="$KEEP_AGENTS $vals" ;;
      skills) KEEP_SKILLS="$KEEP_SKILLS $vals" ;;
      templates) KEEP_TEMPLATES="$KEEP_TEMPLATES $vals" ;;
    esac
  done < <(keep_for_stack "$stack")
}

if [ "$MODE" = "monorepo" ]; then
  # 공통 모노레포 자산
  KEEP_AGENTS="$KEEP_AGENTS github-actions-designer"
  KEEP_SKILLS="$KEEP_SKILLS github-actions-patterns"
  KEEP_TEMPLATES="$KEEP_TEMPLATES AGENTS.monorepo.md settings.monorepo.json"

  if [ -z "$EXTRA_STACKS" ]; then
    echo "⚠️ monorepo 인데 감지된 stack 인자 없음 — 보수적으로 모든 코드 stack 유지" >&2
    EXTRA_STACKS="kotlin kotlin-multi go go-multi python python-multi nextjs nextjs-multi flutter"
  fi

  for stack in $EXTRA_STACKS; do
    accumulate "$stack"
  done
else
  accumulate "$MODE"
fi

# --- 차집합 계산 ---

is_keep() {
  case " $1 " in *" $2 "*) return 0 ;; esac
  return 1
}

calc_removals_dir() {
  local dir="$1" keep="$2"
  [ -d "$dir" ] || return 0
  for f in "$dir"/*.md; do
    [ -f "$f" ] || continue
    case "$f" in *"/custom/"*) continue ;; esac
    local bn=$(basename "$f" .md)
    if ! is_keep "$keep" "$bn"; then
      echo "$f"
    fi
  done
}

calc_removals_templates() {
  [ -d .claude/templates ] || return 0
  for f in .claude/templates/*; do
    [ -f "$f" ] || continue
    case "$f" in *"/custom/"*) continue ;; esac
    local bn=$(basename "$f")
    if ! is_keep "$KEEP_TEMPLATES" "$bn"; then
      echo "$f"
    fi
  done
}

# 스타터가 배포하는 skill 이름 전체 — 이 목록 밖의 skill 디렉토리는 사용자 것이므로 건드리지 않는다
known_skills() {
  echo "$KEEP_SKILLS_COMMON $WORKFLOW_SKILLS"
  for s in kotlin go python nextjs flutter infra marketing sales product; do
    keep_for_stack "$s" | sed -n 's/^skills://p'
  done
}
KNOWN_SKILLS=" $(known_skills | tr '\n' ' ') "

calc_removals_skills() {
  [ -d "$SKILLS_DIR" ] || return 0
  for d in "$SKILLS_DIR"/*/; do
    [ -f "$d/SKILL.md" ] || continue
    local bn=$(basename "$d")
    is_keep "$KNOWN_SKILLS" "$bn" || continue      # 사용자 skill
    is_keep "$KEEP_SKILLS" "$bn" || echo "$SKILLS_DIR/$bn"
  done
}

AGENTS_RM=$(calc_removals_dir .claude/agents "$KEEP_AGENTS" || true)
SKILLS_RM=$(calc_removals_skills || true)
TEMPLATES_RM=$(calc_removals_templates || true)

count_lines() { [ -z "$1" ] && echo 0 || echo "$1" | grep -c '^.'; }

A_CNT=$(count_lines "$AGENTS_RM")
S_CNT=$(count_lines "$SKILLS_RM")
T_CNT=$(count_lines "$TEMPLATES_RM")

# --- 출력 ---

echo "=== /init cleanup (mode=$MODE${EXTRA_STACKS:+ extra=$EXTRA_STACKS}) ==="
echo ""
echo "보존 (항상):"
echo "  .claude/agents/custom/    .claude/commands/custom/    .claude/hooks/custom/"
echo "  .claude/settings.local.json   .claude/.starter-version*"
echo "  워크플로 skill (commit·pr·start 등) · 스타터가 모르는 skill 디렉토리 (사용자 작성)"
echo ""
echo "제거 대상:"
echo "  agents:    $A_CNT 개"
[ -n "$AGENTS_RM" ] && echo "$AGENTS_RM" | sed 's|^|    - |'
echo "  skills:    $S_CNT 개"
[ -n "$SKILLS_RM" ] && echo "$SKILLS_RM" | sed 's|^|    - |'
echo "  templates: $T_CNT 개"
[ -n "$TEMPLATES_RM" ] && echo "$TEMPLATES_RM" | sed 's|^|    - |'
[ -d .github/assets ] && echo "  .github/assets/ 디렉토리 (스타터 이미지)"

# --- 실제 rm (--apply) ---

if [ "$APPLY" = false ]; then
  echo ""
  echo "ℹ️ dry-run 모드 — 실제 제거하려면 --apply 추가"
  exit 0
fi

echo ""
echo "🗑  제거 중..."

[ -n "$AGENTS_RM" ]    && echo "$AGENTS_RM"    | xargs -r rm -f
[ -n "$SKILLS_RM" ]    && echo "$SKILLS_RM"    | xargs -r rm -rf
[ -n "$TEMPLATES_RM" ] && echo "$TEMPLATES_RM" | xargs -r rm -f
[ -d .github/assets ] && rm -rf .github/assets

echo ""
echo "✅ cleanup 완료"
echo "   agents:    $A_CNT 개 제거"
echo "   skills:    $S_CNT 개 제거"
echo "   templates: $T_CNT 개 제거"
