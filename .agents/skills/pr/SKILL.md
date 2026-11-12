---
name: pr
description: 현재 브랜치에서 PR 생성. base는 dev/main 자동 감지. 보안 리뷰·교차 리뷰(반대 플랫폼 모델)를 병렬로 돌린 뒤 생성, /merge 제안.
argument-hint: "(인수 없음 — 자동으로 push + PR 생성)"
---

현재 worktree의 브랜치에서 PR을 생성합니다.

---

## PR base branch 규칙 (필수)

> 🔒 **이 규칙은 모든 프로젝트·모든 호출에 예외 없이 적용됩니다.**
> 사용자·Claude 누구도 `gh pr create --base <다른브랜치>` 로 override 하면 안 됩니다.

```
로컬 `dev` 존재          → base = dev
로컬 없고 origin/dev 존재 → base = dev
둘 다 없음                → base = main
현재 브랜치가 dev         → base = main   (base == head 금지 예외)
```

## Step 1 — 사전 확인

```bash
BRANCH=$(git branch --show-current)

# 로컬 dev 우선, remote origin/dev 도 체크 (네트워크 실패 시 로컬 결과만 사용)
if git show-ref --verify --quiet refs/heads/dev \
   || git ls-remote --heads origin dev 2>/dev/null | grep -q refs/heads/dev; then
  BASE_BRANCH="dev"
else
  BASE_BRANCH="main"
fi

# 현재 브랜치가 dev 이면 main 으로 폴백 (base == head 방지)
[ "$BRANCH" = "dev" ] && BASE_BRANCH="main"

echo "브랜치: $BRANCH → PR base: $BASE_BRANCH"
```

이미 PR이 있으면 그 URL만 출력하고 Step 3으로 진행:

```bash
EXISTING=$(gh pr view --json url 2>/dev/null | jq -r '.url // empty')
[ -n "$EXISTING" ] && echo "ℹ️  이미 PR 존재: $EXISTING"
```

## Step 1.4 — 리뷰 범위 판정 · 교차 리뷰 먼저 띄우기

```bash
# base 대비 diff 생성
git fetch origin "$BASE_BRANCH" --quiet 2>/dev/null || true
DIFF=$(git diff "origin/$BASE_BRANCH"..."$BRANCH" 2>/dev/null | head -5000)
CHANGED_FILES=$(git diff --name-only "origin/$BASE_BRANCH"..."$BRANCH" 2>/dev/null)

# 문서만 바뀐 PR = 문서 확장자(.md·이미지)만. AGENTS.md·SKILL.md·.claude/·.agents/·.codex/ 는 에이전트 동작을 바꾸므로 문서가 아니다.
DOCS_ONLY=1
while IFS= read -r f; do
  [ -z "$f" ] && continue
  case "$f" in
    .claude/*|.agents/*|.codex/*|*AGENTS.md) DOCS_ONLY=0 ;;
    *.md|*.png|*.svg|*.jpg|*.gif) ;;
    *) DOCS_ONLY=0 ;;
  esac
done <<< "$CHANGED_FILES"

# 교차 리뷰 설정 (.claude/stacks.json 의 harness.crossReview: true | false | 미설정)
source .claude/hooks/lib.sh 2>/dev/null
CROSS=$(harness_opt crossReview unset 2>/dev/null || echo unset)
# 리뷰어 = 지금 도구의 반대편 (Claude → codex, Codex → claude)
if [ -n "$CLAUDECODE" ]; then REVIEWER=codex; elif [ -n "$CODEX_THREAD_ID" ]; then REVIEWER=claude; else REVIEWER=codex; fi
command -v "$REVIEWER" >/dev/null 2>&1 && HAVE_REVIEWER=1 || HAVE_REVIEWER=0
echo "DOCS_ONLY=$DOCS_ONLY CROSS=$CROSS REVIEWER=$REVIEWER HAVE_REVIEWER=$HAVE_REVIEWER"
```

- `DOCS_ONLY=1` → 보안 리뷰(Step 1.5)만 생략한다. 교차 리뷰는 문서 PR 도 실행한다.
- 교차 리뷰는 **diff 와 주변 소스를 반대 플랫폼 서비스(OpenAI Codex 또는 Anthropic Claude)로 전송**한다:

| `CROSS` | 동작 |
|---------|------|
| `false` | 교차 리뷰 생략 — PR 본문에 "교차 리뷰: 꺼짐(harness.crossReview=false)" |
| `unset` (처음) | 사용자에게 **한 번** 묻는다: "교차 리뷰는 diff 를 {REVIEWER} 서비스로 보냅니다. 켤까요?" → 답을 `.claude/stacks.json` 의 `harness.crossReview` 에 저장 (stacks.json 없으면 이번 실행에만 적용) |
| `true` | 실행 (다시 묻지 않는다) |

- `HAVE_REVIEWER=0` (반대 플랫폼 CLI 미설치 — 한 플랫폼만 쓰는 사용자) → 교차 리뷰를 **건너뛰고** PR 본문에 "교차 리뷰: 생략 ({REVIEWER} CLI 미설치)" 를 적는다. 자체 리뷰로 대체했다고 쓰지 않는다. 설치 안내: Codex `npm i -g @openai/codex` · Claude Code `npm i -g @anthropic-ai/claude-code` 후 로그인.
- 실행할 때는 **교차 리뷰를 먼저 백그라운드로 띄운 뒤** 보안 리뷰를 돌린다. 둘은 서로 의존하지 않는다.

```bash
# Claude: Bash run_in_background=true 로 실행(끝나면 알림). Codex: 백그라운드 셸로 띄우고 Step 1.6 에서 기다린다.
bash .claude/scripts/cross-review.sh --base "$BASE_BRANCH" --reviewer "$REVIEWER"   # 최대 15분
```

## Step 1.5 — 🔒 보안 리뷰 (자동, 필수)

> **모든 기능 PR 은 보안 리뷰를 통과해야 합니다.** 인자에 `--skip-security` 가 없으면 자동 실행 (문서만 바뀐 PR 은 Step 1.4 에서 생략).

### security-reviewer agent 호출

> Claude 는 아래 `Agent` 호출. Codex 는 `security-reviewer` 서브에이전트(`.codex/agents/security-reviewer.toml`)를 spawn 하거나, 없으면 `.claude/agents/security-reviewer.md` 지침대로 직접 리뷰한다.

```
Agent(
  subagent_type="security-reviewer",
  prompt="""
  /pr 커맨드에서 자동 호출. 아래 diff 에 대해 OWASP Top 10 + 스택별 보안 pitfall
  검사 + 시크릿 유출 + 의존성 CVE 를 검토하고 리포트 반환.

  대상 브랜치: {BRANCH}
  Base: {BASE_BRANCH}
  변경 파일 수: {file_count}

  --- staged diff (최대 5000 줄) ---
  {DIFF}
  --- end diff ---

  리포트 끝에 반드시 판정값을 포함: PASS / REVIEW / BLOCK
  """
)
```

### 판정별 분기

| 판정 | 동작 |
|------|------|
| **PASS** (Critical/High 없음) | 바로 Step 2 로 진행 |
| **REVIEW** (High 발견) | 리포트 보여주고 "계속 진행? (y/N)" — 기본값 N |
| **BLOCK** (Critical 발견) | 리포트 보여주고 **exit** — "수정 후 다시 /pr 실행하세요" |

### 예외: `--skip-security` 옵션

긴급 hotfix 등에 사용. 여전히 리뷰는 실행되지만:
- Critical 도 경고로 강등 (차단 없음)
- 사용자에게 **이유 입력 요구** (필수)
- PR 본문에 자동 주입:
  ```markdown
  ⚠️ **SECURITY REVIEW SKIPPED** — reason: {사용자 입력}
  Issues found: Critical {N}, High {N}
  Reviewer must verify before merge.
  ```

> **이 옵션은 예외다**. 일반 기능 개발엔 쓰지 말 것. 사용 시 메모리에 자동 기록.

## Step 1.6 — 🔀 교차 리뷰 결과 받기 (다른 모델)

같은 모델은 자기 실수를 잘 못 본다. Step 1.4 에서 띄운 실행이 끝나기를 기다려 **종료 코드**로 아래 표를 따른다.
보안 리뷰 지적을 고치느라 커밋이 바뀌었더라도 다시 돌리지 않는다 — 교차 리뷰 지적을 고친 뒤에도 마찬가지 (BLOCK 때만 다시).
고위험 경로(마이그레이션·인증·권한·결제·보안·훅)가 바뀌면 스크립트가 알아서 깊게(Codex 추론 high · Claude opus) 본다.

| 결과 | 동작 |
|------|------|
| exit 0 | 리포트의 지적을 **하나씩 코드로 확인**한다. 맞는 지적만 고치고 커밋한 뒤 다음 단계로. 틀린 지적은 이유를 한 줄로 남긴다 — 리뷰는 참고용이지 정답이 아니다 |
| exit 0 + `VERDICT: BLOCK` | Critical 을 고치기 전엔 PR 을 만들지 않는다. 고친 뒤 이 단계만 다시 돌린다 |
| exit 3 (반대 플랫폼 usage limit 소진 확인) | **이 경우만 지금 도구의 리뷰어로 대신** — Claude 는 `code-reviewer` 에이전트, Codex 는 자체 리뷰. PR 본문에 "교차 리뷰 usage limit → 자체 리뷰" 와 확인한 오류 사유를 적는다 |
| exit 1 | 로그인·네트워크·승인·시간 초과·불완전한 응답 등 — 원인(`$(git rev-parse --git-dir)/cross-review-error.log`)을 해결한 뒤 재실행. 해결 전에는 교차 리뷰를 통과했다고 기록하지 않는다. 자체 리뷰로 대체 금지. 사용자가 이번 PR 만 생략하라고 하면 PR 본문에 "교차 리뷰: 실패 후 사용자 요청으로 생략 (사유)" |

PR 본문 `## Review` 에 리뷰어·판정·반영한 지적·반영 안 한 지적(이유)을 3~6줄로 요약한다. 원문은 `$(git rev-parse --git-dir)/cross-review.md`.

## Step 2 — push & PR 생성

```bash
git push -u origin $BRANCH

gh pr create \
  --base $BASE_BRANCH \
  --title "{type}: {기능 요약}" \
  --body "$(cat <<'EOF'
## Summary
-

## Changes
-

## Test plan
- [ ] 단위 테스트 추가/통과
- [ ] 로컬 동작 확인

## Review
- 보안 리뷰: {PASS|REVIEW|BLOCK|문서 PR 생략}
- 교차 리뷰: {codex|claude} · {VERDICT} — {반영/미반영 요약}  (또는 생략 사유)

EOF
)"
```

PR 제목의 `{type}` 은 브랜치 prefix에서 추론 (`feature/` → `feat`, `fix/` → `fix`, `refactor/` → `refactor` 등).

## Step 3 — `/merge` 자동 제안

PR 생성 직후 사용자에게 다음 단계를 물어봅니다:

```
✅ PR 생성 완료: <URL>

다음 단계로 /merge 를 실행할까요?
  y  — 즉시 머지 (리뷰/체크 조건 맞으면 바로 머지 + 정리)
  a  — auto-merge 큐잉 (체크 통과 시 자동 머지)
  N  — 지금은 머지하지 않음 (기본값, 나중에 /merge 수동 호출)
```

- `y` → `/merge` 를 곧바로 실행
- `a` → `/merge auto` 를 실행
- `N` 또는 응답 없음 → 종료. 나중에 `/merge` 를 수동 호출 가능

---

## Worktree 현황 확인

```bash
git worktree list
```

---

## 주의사항

- PR 생성에는 `gh` CLI 로그인 필요 (`gh auth status`)
- 교차 리뷰는 반대 플랫폼 CLI(`codex` 또는 `claude`) 설치·로그인이 필요 — 없으면 생략되고 PR 본문에 기록된다. 끄기: `.claude/stacks.json` → `"harness": {"crossReview": false}`
- 팀 프로젝트에서 리뷰가 필요하면 `N` 선택 후 리뷰 완료 시 `/merge` 호출 권장
- 머지·태그·worktree 정리는 `/merge` 가 전담합니다 — 이 커맨드는 PR 생성만 담당
- **base branch override 금지** — 위 "PR base branch 규칙" 에 따라 자동 결정된 값만 사용. 사용자가 특정 base 를 요구해도 규칙을 우선 적용하고, 정말 다른 base 가 필요하면 사용자에게 "규칙 위반이지만 진행할까요?" 를 명시적으로 확인받은 뒤에만 수동 지정
