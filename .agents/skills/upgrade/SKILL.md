---
name: upgrade
description: 내 프로젝트 하네스(.claude/·.agents/·.codex/)와 최신 스타터 사이의 selective diff. 카테고리별 적용 + 선택 skill 설치.
argument-hint: "[diff | apply <category[,category...]> | apply all | optional [list | <name>]] [--version <ref>]"
disable-model-invocation: true
---

내 프로젝트의 하네스(`.claude/`·`.agents/skills/`·`.codex/`)와 최신 스타터(또는 핀 버전)를 **카테고리 단위로 비교·적용**합니다.

`bootstrap.sh` 는 all-or-nothing 교체이지만, `/upgrade` 는 `agents` 만 / `skills` 만 같이 부분 갱신할 수 있습니다.
스타터가 기본 배포하지 않는 서드파티 skill(예: `archify`)은 `optional` 로 골라 설치합니다.

**명령:** $ARGUMENTS

---

## 서브명령

| 인자 | 동작 |
|------|------|
| (없음) 또는 `diff` | 카테고리별 변경 통계 + 적용 가이드 |
| `apply <cat>[,<cat>...]` | 지정 카테고리만 갱신 (예: `apply skills,hooks`) |
| `apply all` | bootstrap update 와 동일 (custom/ 보존) |
| `optional list` | 선택 skill 목록 (`.claude/templates/optional-skills.json`) + 설치 여부 |
| `optional <name>` | 선택 skill 을 upstream 고정 ref 에서 받아 `.agents/skills/<name>/` 에 설치·갱신 |
| `--version <ref>` | 비교 기준을 main 대신 특정 태그/SHA 로 핀 (예: `--version v2.0.0`) |

**카테고리** (9개):

| 카테고리 | 로컬 경로 | 비고 |
|---------|----------|------|
| `agents` | `.claude/agents/` | 서브에이전트 원본 (Codex TOML 은 여기서 생성) |
| `skills` | `.agents/skills/` | skill 원본 — `.claude/skills` 는 이 디렉토리의 심볼릭 링크 |
| `hooks` | `.claude/hooks/` | Claude·Codex 공통 훅 |
| `githooks` | `.claude/githooks/` | 플랫폼 공통 git 훅 (pre-commit·pre-push) |
| `scripts` | `.claude/scripts/` | init-cleanup·gen-codex-agents·cross-review·coverage-gate 등 |
| `templates` | `.claude/templates/` | AGENTS.{stack}.md · settings.{stack}.json · codex/ · cicd/ |
| `settings` | `.claude/settings.json` | Claude 플랫폼만 |
| `codex` | `.codex/` | Codex 플랫폼만 — hooks.json 갱신 + agents TOML 재생성 (config.toml 은 diff 만) |
| `optional` | `.agents/skills/<name>/` | 선택 skill — `apply` 대상 아님, `optional <name>` 으로 |

> **항상 보존** — bootstrap.sh 와 동일 정책: `agents/custom/`, `commands/custom/`(v1 레거시), `hooks/custom/`, `settings.local.json`,
> 그리고 **스타터 배포본에 없는 skill 디렉토리**(사용자가 만든 skill · 설치한 optional skill).

---

## Step 1 — 비교 대상 다운로드

```bash
TMP=$(mktemp -d)
git clone --quiet --depth=1 https://github.com/nogamsung/coding-agent-starter.git "$TMP" 2>/dev/null
if [ -n "$VERSION_REF" ]; then
  (cd "$TMP" && git fetch --quiet --depth=1 origin "$VERSION_REF" && git checkout --quiet FETCH_HEAD) || {
    echo "❌ 버전 ref '$VERSION_REF' 를 origin 에서 찾지 못했습니다."
    exit 1
  }
fi
REMOTE_VERSION=$(cat "$TMP/VERSION")
LOCAL_VERSION=$(cat .claude/.starter-version 2>/dev/null || echo "(unknown)")
echo "내 프로젝트: $LOCAL_VERSION → 비교: $REMOTE_VERSION"
```

---

## Step 2 — 카테고리별 diff 통계

각 카테고리에 대해 `diff -rq <local> <remote>` 결과를 added(+), modified(~), removed(-) 로 분류.

```bash
categorize() {
  local cat="$1"; local local_dir="$2"; local remote_dir="$3"
  local added=0 modified=0 removed=0
  if [ -d "$remote_dir" ] && [ -d "$local_dir" ]; then
    while IFS= read -r line; do
      case "$line" in
        "Only in $remote_dir"*)  added=$((added+1)) ;;
        "Only in $local_dir"*)
          # custom/ 경로는 카운트 제외
          [[ "$line" == *"/custom"* ]] && continue
          removed=$((removed+1)) ;;
        "Files "*differ)         modified=$((modified+1)) ;;
      esac
    done < <(diff -rq "$local_dir" "$remote_dir" 2>/dev/null)
  elif [ -d "$remote_dir" ]; then
    added=$(find "$remote_dir" -type f | wc -l | tr -d ' ')
  fi
  printf "  %-10s : +%-3d ~%-3d -%-3d\n" "$cat" "$added" "$modified" "$removed"
}

echo "변경 요약 (스타터 $REMOTE_VERSION → 내 프로젝트 $LOCAL_VERSION)"
echo ""
categorize "agents"    .claude/agents    "$TMP/.claude/agents"
categorize "skills"    .agents/skills    "$TMP/.agents/skills"
categorize "hooks"     .claude/hooks     "$TMP/.claude/hooks"
categorize "githooks"  .claude/githooks  "$TMP/.claude/githooks"
categorize "scripts"   .claude/scripts   "$TMP/.claude/scripts"
categorize "templates" .claude/templates "$TMP/.claude/templates"
[ -d .codex ] && categorize "codex" .codex/agents "$TMP/.codex/agents"
# settings 는 파일 단일 (settings.json) — 별도
[ -f "$TMP/.claude/settings.json" ] && [ -f .claude/settings.json ] \
  && cmp -s .claude/settings.json "$TMP/.claude/settings.json" \
  && echo "  settings   : (변경 없음)" \
  || echo "  settings   : ~1   (settings.json 갱신 가능)"
```

> **+** 추가 (스타터에 새로 생김), **~** 변경 (양쪽 다른 내용), **-** 제거 (사용자만 보유 — 그대로 둡니다)
> `skills` 의 **-** 는 대부분 사용자 skill·optional skill 이다 — 갱신해도 지워지지 않는다.
> 로컬에 `.claude/commands/*.md`(v1 레이아웃)가 남아 있으면 "v2 에서 skill 로 이전됨 — `apply all` 권장" 을 함께 출력.

---

## Step 3 — 변경 파일 리스트 (각 카테고리 toggle)

사용자에게 자세히 보고 싶은 카테고리를 묻고, 해당 카테고리 안의 파일별 변경 내역을 나열.

```bash
list_category() {
  local cat="$1"; local local_dir="$2"; local remote_dir="$3"
  echo "=== $cat ==="
  diff -rq "$local_dir" "$remote_dir" 2>/dev/null | while IFS= read -r line; do
    case "$line" in
      "Only in $remote_dir"*)
        rel=${line#Only in $remote_dir}
        echo "  + ${rel#: }"
        ;;
      "Files "*differ)
        f=${line#Files }; f=${f% and *}
        echo "  ~ ${f#$local_dir/}"
        ;;
      "Only in $local_dir"*)
        [[ "$line" == *"/custom"* ]] && continue
        rel=${line#Only in $local_dir}
        echo "  - ${rel#: }   (보존됨 — custom/ 으로 이동 권장)"
        ;;
    esac
  done
}
```

---

## Step 4 — 적용

### `apply <category[,...]>`

선택된 카테고리만 교체. **custom/ 디렉토리·사용자 skill·settings.local.json 은 자동 보존**.

```bash
apply_category() {
  local cat="$1"
  case "$cat" in
    agents|hooks|githooks|scripts)
      # custom/ 백업 → 카테고리 디렉토리 통째 교체 → custom/ 복원
      local CUSTOM_BAK=$(mktemp -d)
      [ -d ".claude/$cat/custom" ] && cp -r ".claude/$cat/custom" "$CUSTOM_BAK/"
      rm -rf ".claude/$cat"
      cp -r "$TMP/.claude/$cat" ".claude/$cat"
      [ -d "$CUSTOM_BAK/custom" ] && cp -r "$CUSTOM_BAK/custom" ".claude/$cat/"
      rm -rf "$CUSTOM_BAK"
      [ "$cat" = githooks ] && chmod +x .claude/githooks/* 2>/dev/null
      # agents 를 갱신하면 Codex TOML 도 다시 만든다
      [ "$cat" = agents ] && [ -d .codex ] && python3 .claude/scripts/gen-codex-agents.py
      echo "✅ $cat 갱신 완료"
      ;;
    skills)
      # 스타터 배포본에 있는 skill 디렉토리만 교체 — 사용자 skill·optional skill 은 그대로
      mkdir -p .agents/skills
      for d in "$TMP"/.agents/skills/*/; do
        n=$(basename "$d")
        rm -rf ".agents/skills/$n"
        cp -R "$d" ".agents/skills/$n"
      done
      # Claude 플랫폼이면 심볼릭 링크 보장 (.claude/skills → ../.agents/skills)
      if [ -f .claude/settings.json ] && [ ! -L .claude/skills ]; then
        [ -d .claude/skills ] && mv .claude/skills ".claude/skills.v1-backup.$(date +%s)"
        ln -s ../.agents/skills .claude/skills
      fi
      echo "✅ skills 갱신 완료 (사용자 skill 보존)"
      ;;
    codex)
      [ -d .codex ] || { echo "ℹ️ .codex/ 없음 — Codex 플랫폼 미설치, 건너뜀"; return 0; }
      cp "$TMP/.claude/templates/codex/hooks.json" .codex/hooks.json
      python3 .claude/scripts/gen-codex-agents.py
      diff -u .codex/config.toml "$TMP/.claude/templates/codex/config.toml" || \
        echo "ℹ️ config.toml 은 사용자 설정이라 덮어쓰지 않음 — 위 diff 를 보고 필요한 줄만 옮기세요"
      echo "✅ codex 갱신 완료 (hooks.json · agents TOML)"
      ;;
    templates)
      rm -rf .claude/templates
      cp -r "$TMP/.claude/templates" .claude/templates
      echo "✅ templates 갱신 완료 (사용자 AGENTS.md/settings.json 은 영향 없음)"
      ;;
    settings)
      [ -f .claude/settings.json ] || { echo "ℹ️ Claude 플랫폼 미설치 — 건너뜀"; return 0; }
      cp "$TMP/.claude/settings.json" .claude/settings.json
      echo "✅ settings.json 갱신 (settings.local.json 은 보존)"
      ;;
    *)
      echo "❌ 알 수 없는 카테고리: $cat"
      return 1
      ;;
  esac
}
```

### `optional [list | <name>]`

선택 skill 은 스타터 저장소에 벤더링하지 않는다(용량·라이선스). 목록과 고정 ref 는 `.claude/templates/optional-skills.json`.

```bash
REG=.claude/templates/optional-skills.json
# list
jq -r '.skills[] | "\(.name)\t\(.ref)\t\(.license)\t\(.description)"' "$REG" | while IFS=$'\t' read -r n ref lic d; do
  [ -f ".agents/skills/$n/SKILL.md" ] && st="설치됨($(cut -d' ' -f2 ".agents/skills/$n/.optional-source" 2>/dev/null))" || st="미설치"
  printf '  %-12s %-10s %-14s %s\n' "$n" "$ref" "$st" "$d"
done

# <name> 설치·갱신 — 레지스트리의 install 단계를 그대로 실행
NAME="$1"
ENTRY=$(jq -e --arg n "$NAME" '.skills[] | select(.name == $n)' "$REG") || { echo "❌ optional skill '$NAME' 없음 — /upgrade optional list"; exit 1; }
REPOSITORY=$(jq -r .repository <<<"$ENTRY"); REF=$(jq -r .ref <<<"$ENTRY"); SKILL_PATH=$(jq -r .path <<<"$ENTRY")
TMP=$(mktemp -d)
git clone --quiet --depth=1 --branch "$REF" "$REPOSITORY" "$TMP/src"
test -f "$TMP/src/$SKILL_PATH/SKILL.md" || { echo "❌ upstream 구조 변경 — $SKILL_PATH/SKILL.md 없음"; rm -rf "$TMP"; exit 1; }
rm -rf ".agents/skills/$NAME" && cp -R "$TMP/src/$SKILL_PATH" ".agents/skills/$NAME"
printf '%s %s\n' "$REPOSITORY" "$REF" > ".agents/skills/$NAME/.optional-source"
rm -rf "$TMP"
echo "✅ $NAME ($REF) 설치 — 라이선스: $(jq -r .license <<<"$ENTRY") · 요구: $(jq -r '.requires | join(", ")' <<<"$ENTRY")"
```

- 설치 전에 사용자에게 **upstream 저장소·ref·라이선스·용량**을 보여 주고 확인받는다 (서드파티 코드를 프로젝트에 들인다).
- 설치된 optional skill 은 스타터 배포본에 없으므로 `bootstrap.sh` update·`apply skills`·`/init` cleanup 에서 보존된다.
- 제거: `rm -rf .agents/skills/<name>`.

### `apply all`

`bootstrap.sh` 를 직접 호출 — 동일한 보존 정책.

```bash
[ -n "$VERSION_REF" ] && OPTS="--version $VERSION_REF" || OPTS=""
curl -fsSL https://raw.githubusercontent.com/nogamsung/coding-agent-starter/main/bootstrap.sh | bash -s -- $OPTS
```

---

## Step 5 — 후속 안내

```bash
# .starter-version 갱신 (apply 한 카테고리 단위 부분 갱신이라도 비교 기준은 맞춰둠)
echo "$REMOTE_VERSION" > .claude/.starter-version

rm -rf "$TMP"

echo ""
echo "✅ 적용 완료. Claude Code / Codex 세션을 재시작하여 새 정의를 로드하세요."
```

---

## 사용 예시

```bash
# 변경 통계만 보기 (디폴트 dry-run 효과)
/upgrade

# skills 와 hooks 만 갱신
/upgrade apply skills,hooks

# 선택 skill 목록 → archify 설치
/upgrade optional list
/upgrade optional archify

# 특정 태그 기준으로 비교 (롤백 시점 확인)
/upgrade --version v2.0.0

# 전부 갱신 (= bootstrap update)
/upgrade apply all
```

---

## 주의사항

- **카테고리 단위 부분 갱신 후** 의존성 불일치 가능성: 예) `skills/` 만 갱신했는데 새 skill 이 미설치 agent·script 를 호출. 이런 경우 `/upgrade apply agents,skills,scripts` 같이 함께 적용.
- **v1 → v2 (commands → skills, CLAUDE.md → AGENTS.md)** 는 레이아웃이 바뀌므로 부분 갱신 대신 `apply all` (= bootstrap update) 후 `/init` 을 권장.
- 사용자가 직접 수정한 stock 파일(`agents/code-reviewer.md`, `.agents/skills/pr/SKILL.md` 등) 은 갱신 시 덮어써집니다 — 보존하려면 agent 는 `agents/custom/` 하위에, skill 은 다른 이름의 디렉토리(예: `.agents/skills/pr-mine/`)로 복사해 두세요.
- `templates/` 갱신은 **루트 AGENTS.md / settings.json 에 영향 없음** (그건 `/init` 이 한 번만 복사). 다음 `/init` 에서 새 템플릿이 반영됩니다.
- `settings` 카테고리는 `.claude/settings.json` 만 — `settings.local.json` 은 항상 보존.
