# Second Brain — Coding Agent Starter (구 Claude Code Starter)

> 이 파일은 프로젝트의 기관 기억(institutional memory)입니다.
> 기술 결정, 교훈, 반복되는 패턴을 여기에 누적하세요.
> 규칙은 `CLAUDE.md`, 맥락과 히스토리는 이 파일에 기록합니다.

---

## 2026-11-12: v2.0.0 — coding-agent-starter 로 개명, Claude Code · Codex 공용 하네스

**카테고리:** 결정

### 배경
사용자 요청: jelog(이 스타터로 시작해 Claude·Codex 를 함께 쓰며 진화한 프로젝트)의 하네스 개선점을 전부 역이식하고,
Codex 만 / Claude 만 / 둘 다 쓸 수 있게. 이름은 후보(agent-harness-starter 등) 중 사용자가 `coding-agent-starter` 선택.
GitHub repo 는 `gh repo rename` (구 URL 자동 리다이렉트).

### 결정
- **지침 = AGENTS.md 하나** (Claude Code ≥ 2.1.277 이 읽음). CLAUDE.md 가 있으면 AGENTS.md 가 무시되므로 CLAUDE.md 생성 금지 →
  `claude-md-management` 플러그인 제거·CI 금지, v1 이전용 `migrate-agents-md.sh`.
- **skill 원본 = `.agents/skills/<name>/SKILL.md`** (Codex 경로), `.claude/skills` 는 심볼릭 링크 (jelog 방식). 구 commands 도 skill 로.
- **`.claude/` 는 플랫폼 무관 하네스 홈으로 유지** (agents·hooks·scripts·templates·stacks.json). Codex-only 설치에도 존재 —
  경로 대이동(수백 참조)보다 이게 낫다고 판단. Codex 배선만 `.codex/` (hooks.json → 같은 `.claude/hooks/*.sh`).
- **subagent 원본 = `.claude/agents/*.md`**, `.codex/agents/*.toml` 은 생성물 (`gen-codex-agents.py --check` 를 pre-commit·CI 가 강제). agent 에 `effort:` 필수.
- **모든 모드에서 stacks.json 생성** — "stacks.json 없으면 exit 0" 원칙 유지 + `harness` 옵션 블록. 공격적 기능은 opt-in:
  memorySync off · modelRouter off · gitHooks 자동설정은 명시 true 일 때만 · crossReview 는 첫 /pr 에서 전송 동의 질문.
- **에이전트 무관 게이트는 git 훅** (`.claude/githooks`, core.hooksPath). 에이전트 모드 pre-push 는 git 훅이 설정돼 있으면 no-op (이중 실행 방지).
- update 시 사용자 skill 판별 = `.claude/.starter-skills` 매니페스트 (스타터가 배포하지 않은 이름은 보존).
- archify 같은 서드파티 skill 은 벤더링하지 않고 `templates/optional-skills.json` + `/upgrade optional`.

### 교훈
- v1 pre-push 에이전트 모드는 exit 1 이라 실제로 push 를 막지 못했다 (Claude hook 차단은 exit 2).
- install-matrix 는 그동안 `bootstrap.sh` 가 원격 main 을 clone 해 **PR 내용이 아닌 main 을 검증**하고 있었다 → `STARTER_SRC` 로 수정.
- `argument-hint: [a | b] (...)` 는 YAML 로 무효 — Codex 의 엄격한 파서 대비 따옴표 필수.

---

## 2026-08-16: v1.43.0 — agent 모델 버전 고정 제거 (티어 별칭)

**카테고리:** 결정

### 배경
사용자 요청: "agent 들이 항상 최신 클로드 모델을 쓰게 해달라." agent frontmatter 의
`model:` 이 `claude-sonnet-4-6` 등 특정 버전에 고정 → 새 모델 출시 시 스타터 전체가 구모델 배포.

### 결정
- **`model:` 은 항상 티어 별칭** (`sonnet` / `opus` / `haiku`) — Claude Code 가 최신 모델로 자동 해석.
- 26개 agent 일괄 교체. 이후 새 agent 추가 시에도 버전 고정 금지.
- agent 본문의 Anthropic API 코드 예시(`ai-generator.md` 등)는 사용자 프로젝트 생성 코드라 별개 —
  이번엔 유지, 필요 시 별도 갱신.

---

## 2026-06-04: v1.42.0 — dev→main 버전 사이클 + ghcr Docker 이미지 CI 템플릿

**카테고리:** 결정

### 배경
사용자가 "버전업은 dev→main 머지 시 지정, 그 버전을 git tag·GitHub Release·ghcr 패키지에 모두 기록,
해당 버전 태그 이미지 + `latest-prd` 동시 갱신, `latest-dev` 는 dev 머지마다 갱신, latest-dev→latest-prd
승격이 곧 버전업+실서버 배포, dev 머지마다 second brain 갱신" 을 요청.

이 repo 는 앱·Dockerfile·dev 브랜치가 없는 파일 라이브러리 → 사이클을 직접 실행하지 않고
**사용자 프로젝트용 재사용 템플릿**으로 제공하기로 결정 (사용자 확인).

### 결정 (설계 분기 — 사용자 확정)
- **버전 소스 = git 태그 기반** (VERSION 파일 main 커밋 없음). conventional commits 로 다음 SemVer 자동 계산.
  → CI 가 파일을 main 에 되커밋할 필요가 없어 무한루프 회피.
- **메모리 갱신 = CI 결정론적 append** (PR 번호·제목·작성자·날짜·이미지 태그). Claude Code Action 미채택 → API 키 불필요.
- **레지스트리 = ghcr.io** (`GITHUB_TOKEN` `packages: write`, 외부 시크릿 없음).
- **승격 = `docker buildx imagetools create`** 로 `latest-dev` digest 를 `:X.Y.Z`+`:latest-prd` 로 re-tag.
  재빌드 안 함 → "dev 에서 테스트한 바이트 == 프로덕션".

### 구현 메모
- 신규 디렉토리 `.claude/templates/cicd/` (dev-ci.yml, release-promote.yml, next-version.sh, Dockerfile.example, README.md).
- **`init-cleanup.sh` 무수정으로 자동 보존**: `calc_removals_templates` 가 `[ -f "$f" ]` 로 파일만 제거 → 디렉토리는 skip.
  install-matrix 의 template 제거 count(예: kotlin 29) 도 불변 → CI 안전. orphan/mapping lint 는 skills/agents·top-level 파일만 검사.
- `init.md` Step 5(main+dev) 에 옵션 설치 단계 추가.
- 검증: next-version.sh 단위(0.1.0/patch/minor/major/BREAKING) 통과, actionlint clean, cleanup count 불변, --apply 후 cicd 생존.

### 주의 (README 에 문서화)
- `dev-ci.yml` 의 memory 잡이 `dev` 에 직접 push → dev 브랜치 보호가 "PR 필수" 면 봇 커밋 거부될 수 있음. status-check-only 권장 or 메모리 잡 제거.
- Workflow permissions = Read and write 필요.

### 변경 파일
.claude/templates/cicd/{dev-ci.yml,release-promote.yml,next-version.sh,Dockerfile.example,README.md}  # 신규
.claude/commands/init.md      # Step 5 옵션 설치
CLAUDE.md                     # 버전 관리 인덱스 + auto-tag.yml 파일명 정정
VERSION / plugin.json         # 1.41.0 → 1.42.0

---

## 2026-05-15: v1.41.0 — Token audit 라운드 5 (commands/new.md 압축)

**카테고리:** 결정

### 배경
v1.40.0 (init.md 압축) 후속. /new 도 자주 호출되는 entry point. 626줄 측정.

분석:
- api 섹션 120줄 = 3 stack (Go / Spring / Python) 각자 핵심 파일 + 주의사항 반복
- module 섹션 71줄 = 4 stack 매니페스트 등록 절차 반복
- 두 섹션이 30% 차지

### 결정

**Stack 반복 → 표 통합 + agent 위임**:

**api 섹션 (120 → 60, -50%)**:
- 스택별 핵심 파일 + 어노테이션 1 표
- "상세 코드 패턴은 stack-generator agent + patterns.md" 위임 명시
- 중복 제거: "swag godoc 필수" 같은 규칙은 generator agent 본문에 이미 있음

**module 섹션 (71 → 40, -44%)**:
- 타입 감지 + 디렉토리 패턴 + 매니페스트 등록 1 표
- stack 별 핵심 규칙 4줄씩

### 핵심 정책 결정

**1. 정보 위임 vs 직접 명시**
- /new 는 디스패처 — agent 호출 명령
- 코드 패턴 상세는 agent 본문 + skills/{stack}-patterns.md 에 이미 있음
- 명시적 위임 ("상세 코드 패턴은 ... 에 정의") + new.md 는 high-level 워크플로만

**2. worktree / 서브명령 결정 섹션 보존**
- worktree 120줄 — git 명령 시퀀스 + 브랜치 네이밍 규칙. 정보 밀도 높음
- 서브명령 결정 113줄 — 5 step 인수 패턴. 단순화 시 분기 모호
- 두 섹션은 디스패처의 핵심 책임 → 유지

### 의식적 배제

- **worktree / 서브명령 결정 단축** — 정보 밀도 vs 압축
- **plan.md 동시 압축** — 적정 크기 (390), 우선순위 낮음

### 변경 파일
```
.claude/commands/new.md            # 626 → 510 (-19%)
.claude-plugin/plugin.json         # 1.40.0 → 1.41.0
README.md / README.en.md           # 배지
CHANGELOG.md, VERSION              # 1.40.0 → 1.41.0
```

### Token-audit 시리즈 정리 (v1.30~v1.41)
| 버전 | 영역 | 절감 |
|------|------|------|
| v1.30.0 | agents description | ~70자/세션 |
| v1.31.0 | templates/CLAUDE.md cap | ~250 토큰/세션 (product 만) |
| v1.32.0 | settings data | (maintainer 가드) |
| v1.33.0 | settings hooks | (maintainer 가드) |
| v1.40.0 | commands/init.md | ~620 토큰/호출 |
| **v1.41.0** | **commands/new.md** | **~290 토큰/호출** |

다음 후보 (낮은 우선순위):
- skills/github-actions-patterns.md (1174줄) — on-invoke
- agents/ai-tester.md, security-reviewer.md (200~285줄) — on-invoke

자주 호출되는 entry point 압축 사이클 사실상 완료. 다음 audit 는 on-invoke 만 남음 (낮은 우선순위).

---

## 2026-05-14: v1.40.0 — Token audit 라운드 4 (commands/init.md 압축)

**카테고리:** 결정

### 배경
22 릴리스 동안 자주 호출되는 `/init` 본문 점검 0회. 측정 결과 636줄로 비대.

분석:
- Step 3 (하네스 설치): 213줄 — 4 mode 반복 cp 명령
- Step 6 (완료 메시지): 162줄 — 4 mode 반복 5 기둥 + 이제 할 일
- 4 mode 반복이 60% 차지

### 결정

**4 mode 반복을 공통 패턴 + 모드별 차이 표로 통합**:

**Step 3 (213 → 55줄, -74%)**:
- 공통 2 step ("CLAUDE.md 설치" + "settings.json 설치") + 모드별 추가
- stacks.json 다중 backend 예시 1개로 통합 (단일의 superset)
- Marketing/Sales/Product plugin 안내 → 표 4줄
- Infra 모드 추가 (이전 누락)

**Step 6 (162 → 25줄, -85%)**:
- 4 mode 의 5 기둥 출력 → 공통 템플릿 + 모드별 표

### 핵심 정책 결정

**1. 표로 통합 vs 인라인 case**
- 표가 더 압축적 + scan 가능
- Claude 가 표 읽고 모드별 분기 추론 — 잘 동작

**2. 정보 손실 0 보장**
- 핵심 정보 (5 기둥, plugin 필수성, 추가 명령) 모두 보존
- boilerplate (반복 출력 패턴) 만 제거

**3. 다른 commands 같이 압축 X**
- new.md (626줄), plan.md (390줄) 도 비대
- 한 PR 에 너무 많은 변경 위험 → 별도 후속

### 측정 — /init 호출 시 절감
- 매 호출 ~250줄 × 2.5 토큰/줄 ≈ 600 토큰 절감
- /init 는 새 프로젝트 setup 의 entry point — 누적 효과 명확

### 의식적 배제

- **3-B schema 단축** — name 추출 규칙은 정보 밀도 높음. 유지.
- **8 pm-* plugin 명령 일일이 명시** — 약식 (toolkit / product-discovery / ...) 으로 표 한 줄
- **new.md / plan.md 동시 압축** — 별도 PR

### 변경 파일
```
.claude/commands/init.md           # 636 → 387 (-39%)
.claude-plugin/plugin.json         # 1.39.0 → 1.40.0
README.md / README.en.md           # 배지
CHANGELOG.md, VERSION              # 1.39.0 → 1.40.0
```

### Token-audit 시리즈 정리 (v1.30~v1.40)
| 버전 | 영역 |
|------|------|
| v1.30.0 | agents description (frontmatter) |
| v1.31.0 | templates/CLAUDE.md (≤120 cap) |
| v1.32.0 | settings data (plugin/allow/deny) |
| v1.33.0 | settings behavior (hooks) |
| **v1.40.0** | **commands/init.md body (자주 호출되는 entry point)** |

다음 후보:
- commands/new.md (626줄) 압축
- commands/plan.md (390줄) 압축

---

## 2026-05-14: v1.39.0 — Orphan + mapping CI 가드 (mcp-presets 재발 자동 catch)

**카테고리:** 결정

### 배경
v1.38.0 에서 mcp-presets 가 모든 mode keep 목록에서 누락된 1회성 사고 fix. 같은 클래스 사고 (skill/agent 가 어디에도 매핑 안 됨) 가 향후 발생할 수 있는 영구 가드 필요.

### 결정

**두 CI 가드 추가** (install-matrix.yml static-lints job 안 step):

**A. orphan check**
- 19 skills + 27 agents 각자 9 mode 에서 dry-run
- 모든 mode 에서 제거 대상이면 = orphan = fail
- 향후 새 skill 추가 시 init-cleanup.sh 갱신 강제

**B. mapping check**
- init-cleanup.sh 의 keep 목록 이름 추출 + 실제 파일 존재 검증
- typo 잡기 (`kotline-patterns` 같은 오타)
- 동적 인자 `${1}` skip (kotlin-multi 등으로 풀려서 사용)

### 핵심 정책 결정

**1. 새 job 신설 X — 기존 static-lints job 에 step 추가**
- v1.37.0 의 교훈: 새 job = runner overhead 30s. step 추가 = 0
- 두 가드 모두 빠른 정적 검증 → step 으로 적합

**2. 자동 keep 목록 갱신 X**
- orphan 발견 시 자동으로 KEEP_SKILLS_COMMON 에 추가 안 함
- maintainer 가 의도 (common 인지 stack 별 인지) 명시해야

**3. dynamic 인자 ${1} skip**
- keep_for_stack 함수의 `CLAUDE.${1}.md` 같은 동적 patterns
- false positive 방지 위해 grep -v

### 의식적 배제

- **stack 별 매핑 비율 강제** — 예: 모든 stack 에 docker-patterns keep 강제. stack 별 자유 유지.
- **자동 fix 모드** — read-only lint 만. 의도 없는 수정 위험.

### 변경 파일
```
.github/workflows/install-matrix.yml   # static-lints 에 orphan + mapping step 추가
.claude-plugin/plugin.json             # 1.38.0 → 1.39.0
README.md / README.en.md               # 배지
CHANGELOG.md, VERSION                  # 1.38.0 → 1.39.0
```

### Critical fix → Permanent guard 패턴

| 사고 (1회성 fix) | 영구 가드 |
|----------------|----------|
| v1.36.0 (/init 5 원인) | init-cleanup-smoke (9 mode 카운트) |
| v1.38.0 (mcp-presets 누락) | **v1.39.0 orphan + mapping** |

발견 → fix → 가드 → 재발 catch 패턴 정착.

---

## 2026-05-14: v1.38.0 — Skill audit (mcp-presets 모든 mode 제거되던 버그 fix)

**카테고리:** 결정

### 사고
v1.36.0 (init-cleanup.sh) 직후 추가 audit 라운드에서 발견:
- 19 skills 중 **mcp-presets 만** 어느 mode keep 목록에도 안 들어감
- 측정: `/init kotlin --apply` 후 `ls .claude/skills/mcp-presets.md` → "No such file"
- v1.22.0 (MCP 프리셋) 의 사용자 워크플로 (snippet 직접 복사) 가 불가능했던 것

### 결정

**`KEEP_SKILLS_COMMON` 에 mcp-presets 추가**:
- 14 mode 모두에서 keep
- 이유: MCP 서버 권장 설정은 stack 무관 (postgres / filesystem / github MCP 등 모든 stack 에서 유용)

CI `init-cleanup-smoke` job 의 9 mode expected count 모두 skills -1 갱신.

### 핵심 결정 사유

**1. mcp-presets 를 COMMON 으로 (stack 별 옵션 X)**
- MCP 서버는 stack 무관 (postgres MCP 는 kotlin/go/python 모두 유용)
- common 으로 두는 게 단순 + 정합

**2. CI 가드 갱신 패턴**
- expected count 가 hardcode 라 변경 시 명시적 갱신 — 자동 catch
- 향후 skill 추가/삭제 시 expected count 변하면 CI fail → 명시 갱신 강제

### 의식적 배제

- **전 skill consistency 가드 신설** — 19 skill 각자 어느 mode 든 keep 목록에 있는지 매핑 검증. 가치 있지만 복잡 → 후순위. 현재 expected count 변화로 부분 catch.
- **mcp-presets 를 stack 별로 분기** — kotlin 만 keep 같이 — 의미 없음 (모든 stack 에서 유용)

### 변경 파일
```
.claude/scripts/init-cleanup.sh         # KEEP_SKILLS_COMMON 에 mcp-presets 추가
.github/workflows/install-matrix.yml    # 9 mode expected count + stock 카운트 갱신
.claude-plugin/plugin.json              # 1.37.0 → 1.38.0
README.md / README.en.md                # 배지
CHANGELOG.md, VERSION                   # 1.37.0 → 1.38.0
```

### 회고 — Audit 패턴의 가치

v1.36.0 → v1.38.0 의 2-step audit:
1. v1.36.0: /init 자체가 동작 안 함 (5 critical 원인)
2. v1.38.0: 동작은 하지만 mcp-presets 자료 누락 (1 skill 매핑 누락)

**측정 → 이상치 발견 → fix → CI 가드 갱신** 패턴이 v1.30~v1.33 의 token-audit 시리즈에 이어 또 효과. 일관된 패턴.

### 다음 audit 후보 (낮은 우선순위)
- 전 skill / agent 가 어느 mode 든 매핑되는지 union 가드 신설
- agents body 길이 측정 (ai-tester 285줄, security-reviewer 266줄 등) — 정보 손실 평가 후
- commands body 길이 (init.md 636줄, new.md 626줄) — 자주 호출되는 명령이라 가치 평가

---

## 2026-05-14: v1.37.0 — GHA 비용 절감 + 태그 안전화 (사용자 보고 fix)

**카테고리:** 결정

### 사용자 보고
"GHA test/CI 가 매 push 마다 돌아서 limit 빠르게 채움. 또한 이상한 태그가 release/package 에 등록되지 않게 하고 싶음. 최대한 절약."

### 진단

**비용 구조**:
- `install-matrix.yml`: 13 jobs, `push: main` + `pull_request` 양쪽 트리거
- 이번 세션 18 PR × 13 jobs + 18 main push × 13 jobs ≈ **468 job runs**
- 각 job runner overhead ~30s × 13 = 6.5분 overhead per workflow run

**태그 위험**:
- `auto-tag.yml` 이 VERSION 형식 검증 안 함 → 잘못된 VERSION (`dev`, `1.2`, 빈 값) commit 시 이상한 태그 생성
- prerelease (`-rc.N`) 도 무조건 `latest` 차지

### 결정

**A. install-matrix 13 jobs → 2 jobs 통합**
- static-lints 1개 (6 lint sequential steps)
- install-scenarios 1개 (7 시나리오 sequential, 각자 mktemp 격리)
- 핵심: matrix strategy 안 씀. matrix 도 결국 각자 runner = overhead 그대로. **sequential steps in one runner 가 가장 효율적**.

**B. push: main 트리거 제거**
- PR 통과 검증 후 squash merge → main push 시 또 13 jobs 재실행 = 100% 중복
- 결정: `on: pull_request` 만. main push 검증 안 함.

**C. concurrency 그룹 추가**
- 같은 PR 의 새 commit push 시 이전 job 자동 cancel
- `concurrency.group: install-matrix-${{ github.head_ref || github.ref }}`

**D. auto-tag.yml SemVer 강제**
- VERSION 정규식 `^[0-9]+\.[0-9]+\.[0-9]+(-(rc|beta|alpha)\.[0-9]+)?$`
- 불일치 시 workflow fail + 태그 생성 차단
- 잘못된 태그가 GitHub Release · 패키지에 등록되는 사고 자동 방지

**E. Prerelease 자동 분리**
- `-rc.N` / `-beta.N` / `-alpha.N` 포함 시 `prerelease: true` + `make_latest: false`
- 안정 릴리스만 `latest` 차지 (v1.17.0 GHCR 정책과 정합)

### 핵심 정책 결정 사유

**1. matrix vs sequential steps**
- matrix strategy 각 entry = 별도 runner = overhead 그대로
- sequential steps in one runner = overhead 1회 + 작업 시간 추가
- 우리 13 시나리오 합쳐도 5분 이내 → 단일 runner 효율적

**2. main push 검증 제거 시 위험 분석**
- 위험: PR 머지와 main 의 상태가 drift 가능 (예: merge conflict 자동 해결 시)
- 완화: squash merge 사용 (history 단순) + PR 통과 = main 통과 가정
- 결정: 위험 vs 비용 → 비용 절감 우선. drift 발견 시 hot-fix.

**3. concurrency vs queue**
- queue (`cancel-in-progress: false`) 모든 push 검증
- cancel (`cancel-in-progress: true`) 최신만 검증
- 결정: cancel — 마지막 commit 만 main 으로 가니까

**4. prerelease detect 정확성**
- regex `-(rc|beta|alpha)\.N` 만 인정. `-dev` 등은 fail (위 SemVer 검증에서 차단)
- 명확한 패턴만 prerelease 처리

### 의식적 배제

- **matrix strategy 사용** — runner overhead 그대로
- **scheduled health check** — PR 단계 검증 충분
- **release notes 자동 생성** — CHANGELOG awk 추출이 이미 잘 동작

### 측정 — GHA 분 절감
| 항목 | 이전 | 이후 | 절감 |
|------|------|------|------|
| PR 당 jobs | 13 | 2 | -85% |
| PR 당 runner 분 | ~10 | ~3 | -70% |
| main push 검증 | 13 재실행 | 0 | -100% |
| 월간 (18 PR) | ~250 | ~50 | **-80%** |

### 변경 파일
```
.github/workflows/install-matrix.yml   # 563 → 281줄 (-50%)
.github/workflows/auto-tag.yml         # SemVer 검증 + prerelease 분리 (+15줄)
.claude-plugin/plugin.json             # 1.36.0 → 1.37.0
README.md / README.en.md               # 배지
CHANGELOG.md, VERSION                  # 1.36.0 → 1.37.0
```

### 회고 — 비용 의식의 후순위 사고

- v1.19.0 (install-matrix CI 7 jobs 신설) 부터 v1.36.0 (13 jobs) 까지 매 PR 마다 가드 추가. 가치는 명확했지만 **runner overhead 비용 무시**.
- 13 jobs 중 6개가 빠른 lint (각 10~30s) — 이걸 통합 안 한 게 비용 polluter.
- 향후 CI 가드 추가 시 **새 job 추가 vs 기존 static-lints job 에 step 추가** 결정 필요. 기본은 step 추가 (overhead 0).

### 향후 GHA 비용 가드 후보
- usage analytics — GitHub API 로 월별 minutes 추적 + 70% 도달 시 알림
- workflow_dispatch 만 trigger 인 heavy job 분리 (manual 검증 전용)

---

## 2026-05-12: v1.36.0 — Critical fix (/init cleanup 동작 안 함)

**카테고리:** 결정 (사고 회고 포함)

### 사고
사용자 보고: "/init 을 해도 불필요한 agents, skills 등이 제대로 제거가 안 됨".

**18 릴리스 (v1.19~v1.35) 동안 발견 안 됨**. 이유: 우리 (maintainer) 가 자체 .claude/ 에 풀 자산 다 필요해서 /init 안 함. 사용자가 실제 install 후 /init 시도해야 발견되는 버그.

### 5가지 근본 원인

1. **자연어 인스트럭션 의존** (init.md:149):
   - "유지 목록에 없는 .claude/agents/, .claude/skills/, .claude/templates/ 하위 파일 제거"
   - Claude 가 표 → 매핑 → 차집합 → rm 흐름을 직접 추론
   - deterministic X

2. **Agent 이름 brace expansion**:
   - 표에 `kotlin-{gen,mod,test}` 약어 → Claude 가 `kotlin-generator`/`kotlin-modifier`/`kotlin-tester` 풀어야
   - 잘못 풀면 매칭 실패 (`kotlin-gen.md` 찾으려 함)

3. **`custom/` 보존 정책 미반영**:
   - v1.19.0 에서 bootstrap update 의 custom/ 보존 정책 도입 (PR #23)
   - **init.md 에는 반영 안 됨** — `/init` 이 `agents/custom/my-agent.md` 도 제거 위험

4. **모노레포 union 계산 추론 의존**:
   - "감지된 스택들의 합집합" — Claude 가 3-5개 stack 의 유지 목록 union 직접 계산
   - 35+ 파일 결정 부담

5. **`Bash(rm *)` 권한 부재 — 가장 결정적**:
   - 14 settings 중 단 하나도 rm 권한 허용 안 함
   - Claude 가 rm 시도 시 매번 permission prompt → 사용자가 수십 회 confirm 부담 → skip
   - 측정: `jq '.permissions.allow' | grep rm` → 모두 (none)

### 결정: 별도 스크립트 분리

**`.claude/scripts/init-cleanup.sh`** — 모든 5건 deterministic 해소:
- 자연어 → bash 함수 (`keep_for_stack` 의 14 mode case)
- brace expansion → 풀 이름 명시
- `custom/` 보존 강제 (case glob)
- monorepo → 인자로 명시 (`monorepo kotlin nextjs flutter`)
- **1회 권한** (`Bash(bash .claude/scripts/*)`) → permission prompt 1회

### 핵심 정책 결정

**1. 스크립트 vs 명시적 bash 코드 블록**
- init.md 안에 bash 블록 인라인 vs 별도 스크립트 분리
- 스크립트 분리 선택 — testable + CI 가드 가능 + 재사용
- 단점: 추가 자산 1개. 가치 > 비용 (deterministic 자체가 가치)

**2. dry-run 디폴트**
- `--apply` 명시 안 하면 dry-run. 사용자 확인 후 적용
- /init 도 이 패턴 — dry-run 결과 보여주고 확인 → --apply

**3. 1회 권한 모델**
- 개별 rm 권한 추가 (예: `Bash(rm .claude/agents/*)`) → fine-grained 부담 + 사용자 매번 prompt
- 스크립트 1회 권한 → 깔끔 + 보안 (스크립트 내용은 우리가 보장)

**4. CI 가드의 expected count 모델**
- 14 mode 의 정확한 제거 카운트를 CI 에 hardcode
- 향후 stock 자산 추가 시 카운트 변화 → CI fail → expected 갱신 강제
- 즉 자산 변화가 cleanup 카운트와 sync 되도록 자동 catch

### 의식적 배제

- **개별 rm 권한 추가** — 14 mode × 평균 20개 = ~280 권한. settings 폭증.
- **자연어 인스트럭션 유지하며 안내 강화** — 근본 원인 (추론 의존) 해소 안 됨
- **/init 의 다른 step 도 스크립트화** — Step 3 (CLAUDE.md 설치), Step 4 (모노레포) 는 자연어 충분. Step 2 만 critical.

### 변경 파일
```
.claude/scripts/init-cleanup.sh        # 신규 (~180줄)
.claude/commands/init.md               # Step 2 자연어 → 스크립트 호출
.claude/templates/settings.*.json      # 14개 × allow 에 Bash(bash .claude/scripts/*) 추가
.github/workflows/install-matrix.yml   # init-cleanup-smoke job (12→13 jobs)
.claude-plugin/plugin.json             # 1.35.0 → 1.36.0 (sync)
README.md / README.en.md               # 배지
CHANGELOG.md, VERSION                  # 1.35.0 → 1.36.0
```

### 검증
- 9 single-stack mode × dry-run → 정확한 카운트 (e.g., kotlin → 18 agents 제거, 9 유지)
- --apply + 4 custom 자산 (agents/skills/hooks/commands) 모두 보존
- monorepo 3-stack union 정상 (extra 인자로 명시)

### 사고 회고 — Maintainer dogfooding 한계

이 버그는 **maintainer 가 자체 .claude/ 에서 /init 안 함** 때문에 18 릴리스 동안 잠재. 비슷한 한계:
- /release (v1.21.0 도입 후 7 릴리스 동안 미사용 → v1.29.0 dogfood 라운드)
- 텔레메트리 (v1.27.0 도입 후 maintainer 자체 활성 안 함)

**교훈**: 사용자 흐름 자체를 dogfood 안 하는 자산은 잠재 bug 위험. 향후 critical 기능 (`/init` 같은 entry point) 은 CI 가드로 사용자 시나리오 시뮬레이션 필수.

### 다음 dogfood 후보
- `/init` 자체를 CI 에서 시뮬레이션 (claude code 없이는 어렵지만 init-cleanup.sh 부분은 검증 완료)
- /release 우리 자체 dogfood 첫 시도 (v1.37.0+)

---

## 2026-05-11: v1.35.0 — 보안 강화 (secret commit 차단 + dep audit 알림)

**카테고리:** 결정

### 배경
이전 추천의 C 카테고리. 두 영역:
1. dependency 변경 시 즉시 보안 검토 권장
2. main 브랜치 또는 secret 파일 안전장치

기존 상태:
- `security-reviewer` agent 는 `/pr` 단계에서만 자동 호출 → dep 변경이 PR 까지 가야 발견
- `safety-guard.sh` 는 보호 브랜치 force push / reset --hard / amend 차단 — secret commit 은 통과

### 결정

**A. Secret commit 차단** (`safety-guard.sh`):
- `git commit` 실행 직전 `git diff --cached --name-only` 검사
- secret 파일명 (`.env`, `*.pem`, `*.key`, `id_rsa`, `credentials.json`, `.npmrc` 등) 매치 시 exit 2
- 모든 브랜치 적용 — secret 은 어디든 위험
- `.env.example` 같은 예시 파일은 정확 매치 X (통과)

**B. Dependency 파일 audit 알림** (`post-edit-lint.sh`):
- 7개 스택의 dep 파일 편집 시 스택별 audit 명령 출력 + `security-reviewer` agent 권장
- npm/go/python/rust/flutter/ruby/jvm 커버

### 핵심 정책 결정

**1. main commit 자체 차단 거부**
- 검토 → 거부. 사용자 의도된 commit (release) 도 막음.
- push 차단으로 충분 (이미 force push 차단 + PR 워크플로 권장).

**2. 자동 audit 실행 거부**
- hook 에서 `npm audit` 직접 실행 안 함 — 매 dep 변경마다 수십초 지연.
- 알림만, 실행은 사용자 결정.

**3. 파일명만 검사, 내용 스캔 X**
- secret pattern (e.g., `AWS_SECRET_KEY=`) 내용 스캔은 false positive + 별도 도구 (gitleaks, trufflehog) 영역.
- 파일명만으로도 80% 의 secret 누출 catch.

**4. 보호 브랜치 무관**
- secret 은 main 이든 feature 든 어디 commit 해도 위험 (git history 영구).
- 보호 브랜치 한정 X, 모든 브랜치 적용.

### 의식적 배제

- main commit 차단 — 너무 엄격
- 자동 audit 실행 — 시간 비용
- 내용 스캔 — false positive
- secret rewrite 자동화 — 위험 (git history 변경)
- `.env*` 전체 차단 — `.env.example`, `.env.template` 등 예시 파일 정당

### 변경 파일
```
.claude/hooks/safety-guard.sh        # git commit case + secret patterns (~20줄)
.claude/hooks/post-edit-lint.sh      # dep 파일 case + 스택별 audit 명령 (~20줄)
.claude-plugin/plugin.json           # 1.34.0 → 1.35.0
README.md / README.en.md             # 배지
CHANGELOG.md, VERSION                # 1.34.0 → 1.35.0
```

### 측정 — 보안 catch cycle
| 시나리오 | 이전 | 변경 후 |
|---------|------|--------|
| `.env` staged commit | git push → GitHub 누출 | commit 시점 차단 |
| 신규 dep CVE | `/pr` 의 security-reviewer | edit 시 즉시 알림 |
| SSH key (`id_rsa`) accidental commit | 사용자가 인지 못 하면 push | commit 차단 + 가이드 |

### 다음 보안 후보 (낮은 우선순위)
1. `git push` (non-force) 보호 브랜치 차단 — PR 워크플로 강제
2. CI 에 gitleaks 또는 trufflehog 통합 — 내용 스캔
3. dependency-review-action 의 GitHub Actions 통합

---

## 2026-05-11: v1.34.0 — Onboarding 강화 (bootstrap.sh 안내 풍부화)

**카테고리:** 결정

### 배경
15 릴리스 동안 bootstrap.sh 의 install 안내가 4줄 `/init` 옵션 나열만. 사용자가 `/init` 후 다음 단계 모름 → README 읽으러 가야 함. 첫 사용자 마찰의 가장 큰 원인.

### 결정

**install 안내 → 4단계 워크플로 + 문서 링크 + 갱신/롤백 + plugin 설치 안내**:
1. `/init` (스택 감지)
2. `/start <기능>` (worktree + PRD + 자동 구현)
3. `/commit` (→ `/pr` 자동 제안)
4. `/pr → /merge` (머지·태그·정리)

**update 안내 → 버전 변동 명시 + rollback 경로**:
- `v$PREV → v$NEW` 표시
- `/upgrade` 부분 갱신 확인 옵션
- `/starter rollback` hot-fix 경로

### 핵심 정책 결정

**1. echo 라인 → cat heredoc**
- 13줄 echo → cat <<'EOF' 한 블록. 가독성 + 단일 source.
- 한글 + emoji 가 echo 에선 escape 필요 (heredoc 은 그냥 통과).

**2. 모드별 자동 분기 X**
- bootstrap 시점엔 사용자가 어떤 모드 쓸지 모름. `/init` 이 분기 담당.
- 9개 모드 옵션은 한 줄 가로 나열로 압축 (이전 9줄 → 1줄).

**3. 색상 강조 X**
- ANSI 색상은 일부 터미널 미지원 (Windows cmd 등).
- emoji 만 사용 (모든 모던 터미널 호환).

### 의식적 배제

- **rich text formatting** — 호환성 우선
- **5단계 이상 가이드** — 5분 안에 못 읽음. 핵심 4 + 링크.
- **mode-specific 안내 자동 출력** — 사용자 의도 모름. plugin 설치는 README 위임.

### 변경 파일
```
bootstrap.sh                   # install/update 안내 (echo → cat heredoc)
.claude-plugin/plugin.json     # 1.33.0 → 1.34.0 (sync)
README.md / README.en.md       # 배지
CHANGELOG.md, VERSION          # 1.33.0 → 1.34.0
```

### 측정 — onboarding 마찰 변화
| 측면 | 이전 | 변경 후 |
|------|------|--------|
| install 안내 줄 수 | 13줄 (옵션만) | 22줄 (4단계 + 링크 + 갱신 + plugin) |
| 첫 사용자 mental load | "/init 다음 뭐?" → README 검색 | 직접 출력에 4단계 명시 |
| update 안내 줄 수 | 2줄 | 7줄 (버전 변동 + 옵션) |

bootstrap 메시지는 install 시 1회만 출력 (매 세션 토큰 아님) → 늘려도 토큰 비용 0.

### 다음 D 후보
- ~~install 후 5분 가이드~~ → 이번 PR 으로 충족
- bootstrap.sh 가 `--help` 옵션 출력 (현재 sed 로 헤더 추출, 출력 형식 비일관) — 후순위
- `/init` 후 첫 PR 까지의 sample tutorial — 별도 docs/tutorial.md (선택)

---

## 2026-05-11: v1.33.0 — Maintainer 가드 라운드 2 (settings hooks contract lint)

**카테고리:** 결정

### 배경
v1.32.0 (settings-consistency-lint) 가 settings.json 의 **data layer** (plugin/allow/deny) 누락 catch. 이번엔 **behavior layer** (hooks) 도 같은 패턴으로.

측정: 14 settings 의 hooks 패턴 — 두 layer 발견:
1. 모든 14 stack 공통 (3 hooks): session-start, safety-guard, usage-counter
2. 코드 stack 11개만 (2 추가): pre-push, post-edit-lint

### 결정

**`settings-hooks-lint` CI job (12번째)**:
- 모든 14 stack 의 hooks 에서 *.sh 명령 추출
- 공통 3개 hook 누락 시 fail
- 코드 stack (marketing/sales/product 제외 11개) 의 추가 2개 hook 누락 시 fail

### 핵심 정책 결정

**1. 코드 stack 분류 = 파일명 기반**
- `marketing`/`sales`/`product` = 비코드 (3개)
- 그 외 11개 = 코드 (kotlin/kotlin-multi/go/go-multi/python/python-multi/nextjs/nextjs-multi/flutter/infra/monorepo)
- 단순하고 명확. permissions.allow 의 `Bash(./gradlew *)` 같은 마커로 추론할 수도 있지만 unnecessary complexity.

**2. matcher 강제 X**
- PostToolUse 의 `matcher: "Edit|Write|MultiEdit"` 패턴은 hook 별 정당한 차이.
- command (실행 sh) 만 강제, matcher 는 자유.

**3. Stop hook 강제 X**
- 코드 stack 만 Stop 정의 (test/lint 명령). 명령 패턴이 매우 stack 별 (./gradlew test, go test, npm test, ...).
- 별도 lint 가드 부담 vs 가치 — 보류. 우선순위 낮음.

### 의식적 배제

- **자동 hook 채우기** — 의도 없는 수정 위험. read-only lint 만.
- **stack 별 Stop hook 명령 검증** — 다양성 인정. 별도 작업으로 분리.
- **monorepo 의 hooks 가 11개 코드 stack 의 union 인지** — 매우 복잡. 일단 base 만.

### 로컬 검증 시 zsh 함정

`for r in $REQUIRED_ALL` 가 zsh 에서는 word splitting 안 됨 (zsh 디폴트 X). 검증 시 명시적 `bash -c "..."` 또는 array `("${REQUIRED_ALL[@]}")` 사용.

CI 의 ubuntu bash 는 IFS=' ' 디폴트라 정상 동작. 이 함정은 **검증 환경 차이가 silent 통과 일으킬 수 있다** 는 교훈.

### 변경 파일
```
.github/workflows/install-matrix.yml    # settings-hooks-lint job (11→12 jobs)
.claude-plugin/plugin.json              # 1.32.0 → 1.33.0 (sync)
README.md / README.en.md                # 배지
CHANGELOG.md, VERSION                   # 1.32.0 → 1.33.0
```

### Maintainer-guard 시리즈 (v1.32.0 + v1.33.0)
| 버전 | settings layer | 결과 |
|------|----------|------|
| v1.32.0 | data (plugin/allow/deny 13) | 모두 통과, 누락 catch |
| v1.33.0 | behavior (hooks: 공통 3 + 코드 2) | 모두 통과, 누락 catch |

settings.json 의 두 layer 가드 완비. v1.27.0 같은 14 settings 동시 편집 PR 누락 catch 자동화.

### 다음 audit 후보 (낮은 우선순위)
1. agents body 워크플로 중복 (5 stack generator 90% 공유) — on-invoke
2. commands description (평균 70자 — 후순위)
3. monorepo hooks union 검증 — 복잡

---

## 2026-05-11: v1.32.0 — Maintainer 가드 (settings.{stack}.json consistency lint)

**카테고리:** 결정

### 배경
v1.30.0/v1.31.0 의 token-audit 라운드 후속. 이번엔 사용자 토큰 절감이 아닌 **maintainer 측 누락 catch**.

측정: 14개 `settings.{stack}.json` 중 13개 항목이 모두 동일 = 4 plugins + 5 allow + 4 deny.

문제: v1.27.0 (텔레메트리 hook) 같이 14 settings 동시 편집이 필요한 PR 에서 1~2개 누락 시 silent 통과 → 일부 사용자만 hook 미설치 → 발견 후 hot-fix 비용 큼.

### 결정

**`settings-consistency-lint` CI job (11번째)** — 14 settings 가 다음 base 누락 시 fail:
- enabledPlugins: claude-md-management, commit-commands, github, hookify (4)
- permissions.allow: cp, git, mkdir, mv, touch (5)
- permissions.deny: rm -rf /, rm -rf ~*, git push --force, git push -f (4)

총 13개 base 항목. 각 stack 은 추가 항목 자유, base 누락만 차단.

### 핵심 정책 결정 사유

**1. 공통 추출 + merge 시스템 거부**
- `_common.json` + deep-merge 안 검토 → 거부
- 이유: bootstrap.sh 의 단순함이 핵심 가치 — install 흐름 복잡화 안 됨
- lint 만으로 maintainer 누락 충분히 catch

**2. base 13개만 강제, hooks 등 다양성 인정**
- 코드 stack (kotlin/go/python/nextjs/flutter) 은 PostToolUse 에 lint hook 필요
- marketing/sales/product 는 코드 없으니 lint hook 불필요
- 공통 강제 = base 13개만, stack 별 차이는 그대로

**3. v1.27.0 시나리오 재발 방지**
- 텔레메트리 hook 14 settings 동시 추가 — 만약 1개 누락했으면? 일부 사용자만 텔레메트리 작동 안 함 → 데이터 편향. CI 가 catch 했어야.
- 이번 가드가 그 클래스의 누락을 자동화.

### 의식적 배제

- **공통 base 자동 채우기** — 의도 없는 자동 수정. lint 만 (read-only)
- **stack 별 hook 검증** — 다양성 인정 (marketing/sales/product 는 lint hook 없음)
- **enabledPlugins 의 stack-specific plugin 강제** (kotlin-lsp, typescript-lsp 등) — stack 마다 다르므로 stack 별 추가 가드는 부담. base 만.

### 변경 파일
```
.github/workflows/install-matrix.yml    # settings-consistency-lint job (10→11 jobs)
.claude-plugin/plugin.json              # 1.31.0 → 1.32.0 (sync)
README.md / README.en.md                # 배지
CHANGELOG.md, VERSION                   # 1.31.0 → 1.32.0
```

### 다음 audit 후보
1. agents body 의 워크플로 중복 (5 stack generator 가 워크플로 90% 공유) — on-invoke 라 우선순위 낮음
2. commands description (평균 70자) — 후순위
3. CLAUDE.md 의 sub-CLAUDE.md (모노레포) consistency 검증

### Token-audit 시리즈 정리

| 버전 | audit 영역 | 결과 |
|------|----------|------|
| v1.30.0 | agents/*.md frontmatter description | ui-designer 만 multi-line 안티패턴 → 1줄 fix + lint |
| v1.31.0 | templates/CLAUDE.{stack}.md | product 만 폭증 (172→72) + ≤120 cap |
| v1.32.0 | templates/settings.{stack}.json 공통 base | 모두 통과, 누락 catch CI |

3 라운드 모두 측정 → 이상치 fix → CI 가드 패턴 일관.

---

## 2026-05-11: v1.31.0 — Token audit 라운드 2 (CLAUDE.product.md + template cap)

**카테고리:** 결정

### 배경
v1.30.0 에서 agent description audit. 다음 후보로 **`templates/CLAUDE.{stack}.md` 14개** 측정. `CLAUDE.product.md` 가 172줄로 다른 9개 평균 80줄의 2.15배. 12 릴리스 동안 점검 0회.

### 결정

**A. CLAUDE.product.md 172 → 72줄 (100줄 / 58% 절감)**:
- pm-skills plugin command 카테고리별 53줄 나열 → 인덱스 1줄
  - **핵심 통찰**: Claude Code 는 plugin command 를 자동 인식한다. CLAUDE.md 에 다시 나열하면 nested duplication.
- 플러그인 설치 명령 15줄 → "README 참고" 1줄
- 디렉토리 구조 35줄 → 14줄 (sub 디렉토리 코멘트만 유지)

**B. CI template-line-cap job (10번째 job)**:
- `templates/CLAUDE.*.md` ≤ 120줄 (전체 CLAUDE.md ≤ 300 의 40%)
- 사용자 프로젝트 매 세션 로드되는 자산이라 더 엄격
- 현재 14개 평균 78줄, 최대 100줄 (CLAUDE.infra.md)

### 핵심 정책 결정

**1. plugin command 자동 인식 활용**
- Claude Code 가 marketplace 등록된 plugin 의 command 를 자동 인식. CLAUDE.md 에 다시 적는 건 stale 위험 + 토큰 낭비.
- 다른 모드 (marketing, sales) 도 같은 패턴 점검 필요했으나 product 만 폭증. 다른 건 이미 압축됨 (76, 81줄).

**2. ≤120줄 cap (≤300 보다 엄격)**
- templates 는 사용자 프로젝트 루트에 복사되어 매 세션 로드. ≤300 가드만으로 부족.
- 현재 평균 78줄 → 120줄 = 50% 여유. 미래 확장도 가능하면서 안티패턴은 차단.

**3. MUST/NEVER 는 그대로**
- 정책 문구는 정보 손실 가치 큼 — 압축 대상 X. 디렉토리 구조 / 명령어 나열만 압축.

### 의식적 배제

- **다른 13개 template 도 일괄 단축** — 이미 평균 78줄 적정 수준. 정보 손실 위험.
- **CLAUDE.product.md 의 7개 카테고리 이름 (Discovery/Strategy/.../Research) 도 제거** — 사용자가 mental model 잡는 구조이므로 유지.
- **CLAUDE.md ≤ 300 가드 폐기** — templates 외 사용자 직접 작성 CLAUDE.md (모노레포의 sub-CLAUDE.md 등) 에 여전히 ≤300 가드 필요. 이중 가드.

### 토큰 절감 측정
- `/init product` 사용자 ~250 토큰/세션 (줄당 2.5 토큰 추정)
- 다른 모드 영향 없음
- 향후 추가될 template 의 폭증 차단 (CI 가드 효과)

### 변경 파일
```
.claude/templates/CLAUDE.product.md     # 172 → 72줄
.github/workflows/install-matrix.yml    # template-line-cap job (9→10 jobs)
.claude-plugin/plugin.json              # 1.30.0 → 1.31.0 (sync)
README.md / README.en.md                # 배지
CHANGELOG.md, VERSION                   # 1.30.0 → 1.31.0
```

### 다음 audit 후보
1. `templates/settings.{stack}.json` 의 enabledPlugins / permissions 중복
2. commands description (현재 평균 70자 — 후순위)
3. agents body 의 워크플로 정의 중복 (예: 5개 stack 의 generator agent 가 같은 워크플로 90% 공유)

---

## 2026-05-08: v1.30.0 — Token audit (ui-designer description fix + CI lint 가드)

**카테고리:** 결정

### 배경
v1.19~v1.29 11 릴리스 동안 26 agent + 16 commands 의 frontmatter `description` 한 번도 점검 안 했음. 측정 결과:
- 26 agent description 합 ~2400자 = 매 세션 모든 사용자에게 600~800 토큰
- **`ui-designer` 만 multi-line YAML block scalar (`|`)** 사용 — 14줄 ~300자, 다른 agent 의 3배
- 나머지 26개는 single-line, 평균 95자

### 결정

**A. `ui-designer` description 1줄로 압축**:
- 이전: `description: |` + 14줄 (이름 설명 + 6개 trigger 예시)
- 변경: 230자 single-line description + 본문 markdown 의 `## 트리거 예시` 섹션 (Claude 가 agent 호출 결정 시 description 만 봄, trigger 예시는 사용자가 보는 docs)
- 절감: ~70자/세션/사용자

**B. CI agent-description-lint job 추가**:
- multi-line YAML scalar 차단 (`description: |` 또는 `description: >`)
- 길이 ≤ 250자 가드
- description 필드 누락 차단

미래에 새 agent 추가하면서 같은 안티패턴 반복하지 못하도록 자동 catch.

### 핵심 정책 결정 사유

**1. multi-line YAML 안티패턴**
- Agent tool schema 의 description 필드는 single-line string. multi-line YAML 을 string 으로 변환하면 줄바꿈 문자(`\n`) 가 그대로 들어가 LLM 매칭 효율 저하 가능.
- 다른 26개 agent 가 이미 single-line 이라 일관성 fix.

**2. 길이 cap = 250자**
- 측정상 현재 가장 긴 게 ui-designer 146자 (수정 후), 그 다음 ai-generator 135자
- 250자는 충분한 여유 (실제 평균의 2.5배). 그래도 cap 있어야 향후 폭증 차단.

**3. trigger 예시는 description 이 아닌 본문에**
- description = LLM 이 agent 선택할 때 보는 한 줄 요약
- trigger 예시 = 사용자가 docs 로 보는 자료
- 둘은 다른 audience. multi-line description 으로 합치면 LLM 입장에선 noise.

### 의식적 배제

- **모든 agent description 일괄 단축** — 정보 손실 위험. 평균 95자 이미 적정.
- **commands description audit 도 함께** — 16개 commands description 합 ~1100자, 평균 ~70자 이미 적정. 우선순위 낮음.
- **agent model 다양화 (haiku 분리)** — 검토했으나 quality vs token 의 trade-off 명확하지 않음. 보안/리뷰 작업에 haiku = false negative 위험.

### 변경 파일
```
.claude/agents/ui-designer.md          # description multi-line → single-line
.github/workflows/install-matrix.yml   # agent-description-lint job (8→9 jobs)
.claude-plugin/plugin.json             # 1.29.0 → 1.30.0 (sync 가드 통과)
README.md / README.en.md               # 배지
CHANGELOG.md, VERSION                  # 1.29.0 → 1.30.0
```

### 다음 token audit 후보
1. `templates/CLAUDE.{stack}.md` 9개 — 사용자 프로젝트 매 세션 로드. 평균 ~85줄 (CLAUDE.product.md 가 172줄로 가장 큼)
2. `templates/settings.{stack}.json` 의 enabledPlugins / permissions 중복 점검
3. commands description (현재 평균 70자 — 후순위)

---

## 2026-05-08: v1.29.0 — Dogfood 라운드 (/release commit message + plugin meta CI)

**카테고리:** 결정

### 배경
직전 9 릴리스 (v1.19~v1.28) 회고 결과 두 격차 발견:

**격차 A**: `/release` 도입 (v1.21.0) 후에도 7번 릴리스 모두 수동. 이유는 `/release.md` Step 6 의 commit message = `chore(release): vX.Y.Z` 가 우리 실제 패턴과 어긋남. 우리는 **기능 PR 안에 VERSION 동시 bump** 라 commit message 가 `feat(observability):` `feat(infra):` 같은 형태. `chore(release):` 으로 강제하면 PR 본문이 의미를 잃음.

**격차 B**: v1.28.0 의 `.claude-plugin/marketplace.json` + `plugin.json` 메타가 main 에 있지만 검증 CI 없음. plugin.json version 이 VERSION 파일과 sync 안 되면 marketplace 사용자가 잘못된 버전 install. 검증 가드 부재.

### 결정

**A. `/release.md` Step 5 신설 — staged 파일 기반 commit message 자동 추론**:

| staged 패턴 | type 추론 |
|------------|----------|
| `--message "<msg>"` 인자 | 그대로 사용 (override 우선) |
| `agents/commands/skills/templates` 신규 | `feat` |
| `hooks/workflows` 수정 | `fix` |
| VERSION/CHANGELOG/README 만 | `chore(release): vX.Y.Z` |

`--message` 가 가장 안전. 추론은 보조 — 사용자에게 1회 확인 권고.

**B. CI plugin-meta-validation job 추가**:
- JSON 유효성 + 필수 필드 (Anthropic schema 준수)
- marketplace name kebab-case + 예약 이름 차단 (claude-plugins-official 등 8개)
- **plugin.json version ↔ VERSION 파일 sync 가드** — 이게 핵심. 릴리스 시 plugin.json 갱신 누락하면 CI 실패. 자동 catch.

### 핵심 정책 결정 사유

**1. commit message 추론보다 `--message` 우선**
- 추론은 거짓 positive 위험 (예: skill 갱신인데 hook 도 같이 staged 면 fix 추론). 사용자 의도 명시가 가장 안전.
- 추론은 fallback. 결과를 사용자에게 1회 묻는 게 안전.

**2. `chore(release):` 를 폐기 안 함**
- 순수 release-only commit (VERSION/CHANGELOG/README 만 staged) 일 때는 여전히 적절.
- 우리 패턴이 기능 동반 bump 가 디폴트일 뿐 — 둘 다 지원.

**3. Anthropic 예약 이름 차단**
- 8개 reserved name (`claude-code-marketplace` 등) 을 CI 에서 차단. 향후 marketplace 명을 잘못 변경할 때 즉시 catch.

**4. version sync 가드의 가치**
- 이번 PR 자체가 첫 적용 — plugin.json 1.28.0 → 1.29.0 bump 누락이면 CI 실패. dogfood 의 진짜 dogfood.

### 변경 파일
```
.claude/commands/release.md            # Step 5 추가, 6/7/8/9 재번호 (198→230줄)
.github/workflows/install-matrix.yml   # plugin-meta-validation job 추가 (7→8 jobs)
.claude-plugin/plugin.json             # 1.28.0 → 1.29.0 (sync 가드 첫 적용)
README.md / README.en.md               # 배지
CHANGELOG.md, VERSION                  # 1.28.0 → 1.29.0
```

### 의식적 배제

- **자동 commit message 추론에 100% 의존** — 거짓 positive 위험. `--message` 우선.
- **chore(release): 폐기** — 순수 release-only 케이스엔 여전히 적절.
- **/release 자체를 이 PR 에서 사용** — 자기 자신을 수정 중이라 dogfood 의 dogfood 무한 재귀. 이 PR 은 수동, 다음 릴리스부터 적용.

### 다음 dogfood 후보

- **v1.30.0 부터** `/release` 직접 호출 시도 — Step 5 추론 + `--message` override 동작 확인
- agent model 다양화 (E1 — 단순 작업 haiku 분리)

---

## 2026-05-08: v1.28.0 — P3 마지막 (Plugin marketplace 메타 + 한계 명시)

**카테고리:** 결정

### 배경
P3 후보 3건 중 마지막. 자체 plugin marketplace 등록을 검토. Anthropic 공식 marketplace 형식 (`.claude-plugin/marketplace.json` + `.claude-plugin/plugin.json`) 조사 후 진행.

### 핵심 발견 — 우리 가치 제안과 plugin 시스템의 미스매치

**plugin 시스템이 install 가능한 자산**: `commands` / `agents` / `skills` / `MCP servers` / `LSP servers`
**plugin 시스템이 install 불가능한 자산**: `hooks` / `templates` (CLAUDE.{stack}.md, settings.{stack}.json) / `memory/`

우리 스타터의 핵심 가치는 `bootstrap.sh` 의 **풀 install** (`.claude/` 전체 + hooks + templates + `.starter-version` 메타). plugin 으로 받으면 commands/agents/skills 만 들어오고, 사용자는 여전히 `/init` 또는 `bootstrap.sh` 를 추가로 실행해야 hooks/templates 활성화. 즉 plugin 화는 install 단계를 줄이는 게 아니라 **늘림**.

### 결정

**메타 추가 + 한계 정직하게 명시**:
1. `.claude-plugin/marketplace.json` 신설 — Anthropic 공식 schema 준수
2. `.claude-plugin/plugin.json` 신설 — 단일 plugin, source `"."` (저장소 자체 = 단일 plugin)
3. README 양쪽 (한/영) 에 "방법 C — Plugin marketplace (실험적)" 추가
4. **bootstrap.sh 가 여전히 권장 entry point** 임을 명시
5. plugin 한계 (hooks/templates 미지원) 사용자에게 명시

### 의식적 배제

**1. plugin 화를 위해 .claude/ 구조 재편 거부**
- 안 검토안: `plugins/{stack-pack}/.claude-plugin/` 디렉토리 신설하고 .claude/ 자산을 거기로 옮기기 (또는 symlink)
- 거부 이유: bootstrap.sh + /init 흐름이 핵심 가치. 그 자산을 plugins/ 에 미러링하면 single source of truth 깨짐
- 결정: source `"."` 으로 저장소 자체를 단일 plugin 처리. plugins/ 디렉토리 신설 안 함.

**2. Anthropic marketplace 등록 자동화 거부**
- 우리는 메타 파일만 commit. Anthropic 공식 marketplace 제출은 외부 프로세스 (PR to claude-plugins-official) 로 사용자 (maintainer) 가 직접.
- 자동화하면 잘못된 메타로 spam 등록 위험.

**3. plugin 한계 숨기기 거부**
- "plugin 으로도 풀 install 가능" 같은 잘못된 약속 안 함
- README 의 ⚠️ 박스로 "hooks/templates 는 plugin 으로 못 install — bootstrap.sh 권장" 명시

### 변경 파일
```
.claude-plugin/marketplace.json   # 신규 (저장소 루트)
.claude-plugin/plugin.json         # 신규 (저장소 루트)
README.md                          # 방법 C 추가, 배지 갱신
README.en.md                       # 방법 C 추가, 배지 갱신
CHANGELOG.md, VERSION (1.27.0 → 1.28.0)
```

### Anthropic 공식 marketplace 등록 (별도 외부 프로세스)
maintainer 가 별도로 진행:
1. https://github.com/anthropics/claude-plugins-official 에 PR
2. 그쪽 marketplace.json 에 우리 plugin 추가 요청
3. Anthropic 측 검토·승인 후 `claude-code-starter@claude-plugins-official` 으로 등록 가능
4. 또는 사용자가 직접 `/plugin marketplace add nogamsung/claude-code-starter` 로 third-party marketplace 사용

이번 PR scope = (4) 까지. (1)~(3) 은 별도 단계.

### P 카테고리 마무리

| 카테고리 | 진행 |
|---------|-----|
| P0 (안정성) | ✅ 1/1 (v1.19.0) |
| P1 (사용자 흐름) | ✅ 4/4 (v1.20.0~v1.22.0) |
| P2 (영역 확장) | 3/4 (observability ✅ + DevOps/Infra ✅ + AI regression ✅, 추가 스택 ⏸) |
| P3 (장기 채택·운영) | ✅ 3/3 (i18n ✅ + 텔레메트리 ✅ + plugin marketplace ✅) |

P2-마지막 (추가 스택 — Rust/NestJS/Django) 은 텔레메트리 데이터 누적 후 사용자 요청 기반으로 결정. 이번 세션은 P0/P1/P3 100% + P2 75% 완료.

---

## 2026-05-08: v1.27.0 — P3 두 번째 (opt-in 사용량 텔레메트리)

**카테고리:** 결정

### 배경
"어떤 command/agent 를 가장 많이 쓰는가" 데이터 없이 토큰 절감·UX 의사결정 진행 중. 어떤 자산을 더 다듬을지, 어떤 hook 을 더 무겁게 할지 모름. 익명·opt-in·로컬 누적으로 본인 작업 패턴 가시화.

### 결정

**3가지 핵심 정책**:

1. **opt-in (디폴트 disabled)** — `.claude/settings.local.json` 의 `"telemetry": true` 명시해야 동작. 사용자 신뢰의 가장 큰 가치는 "묻지 않고 동작 안 함".
2. **외부 전송 0** — 로컬 `.claude/.usage.json` 파일에만 누적. anonymous opt-in upload 옵션도 미제공 (남용 우려).
3. **tool_name 만 수집** — `Bash`/`Edit`/`Read` 같은 카운트만. 명령 내용·파일 경로·입출력 모두 기록 안 함. PII 위험 0.

**구현**:
- `hooks/usage-counter.sh` (PostToolUse) — opt-in 게이팅 + jq 로 atomic 갱신
- `hooks/session-start.sh` 에 top 5 tool 한 줄 출력
- 14개 settings 템플릿 `hooks.PostToolUse` 에 일괄 등록
- `.gitignore` 에 `.usage.json` + `settings.local.json` 추가 (기존 README 약속이었으나 누락)

### 의식적 배제

- **익명 업로드 옵션** — 한번 켜면 데이터 통제 어려워짐. 신뢰성 최우선.
- **command 별 집계** — slash command 는 사용자 직접 입력이라 PostToolUse 에서 못 잡음. tool 카운트로 우회.
- **input/output 기록** — PII 누출 위험. tool_name 만 충분.
- **시간대별 집계** — 형식 단순화, 누적 카운트만.
- **자동 활성화 안내** — settings.local.json 자동 생성·수정 안 함. 사용자가 의식적으로 활성화.

### 사용자 흐름
```bash
echo '{"telemetry": true}' >> .claude/settings.local.json  # 활성화
# ... 작업 ...
cat .claude/.usage.json     # 직접 확인
# 비활성화: telemetry 키 false 또는 제거
rm .claude/.usage.json      # 누적 데이터 초기화
```

### 변경 파일
```
.claude/hooks/usage-counter.sh        # 신규 (32줄)
.claude/hooks/session-start.sh        # +9줄 (Usage 표시)
.claude/templates/settings.*.json     # 14개 (PostToolUse 에 hook 추가)
.gitignore                            # .usage.json + settings.local.json 추가
README.md, README.en.md (배지)
CHANGELOG.md, VERSION (1.26.0 → 1.27.0)
```

### Dogfooding
이 저장소도 opt-in 활성화하면 maintainer 자신의 작업 패턴 가시화 가능. README/CHANGELOG/skills 중 어느 카테고리가 토큰을 가장 많이 쓰는지 다음 결정의 데이터.

### 다음 P3 후보
- plugin marketplace 등록 (Anthropic 승인 필요 — 큰 작업)

---

## 2026-05-08: v1.26.0 — P3 첫 번째 (i18n: English README)

**카테고리:** 결정

### 배경
P0/P1/P2 의 핵심 격차는 정리됨. P3 후보 3건 (i18n / 텔레메트리 / plugin marketplace) 중 가장 영향 큰 i18n 부터.

한국어 only 상태 → 글로벌 채택의 가장 큰 마찰. 영문 README 가 없으면 한국 외 사용자는 첫 페이지에서 이탈.

### 결정

**README 만 i18n, templates 는 그대로**:
- `README.en.md` 신규 (402줄) — 한국어 README 와 동일 구조의 영문 번역
- 양쪽 최상단에 언어 토글 (`[🇰🇷 한국어](README.md) · [🇬🇧 English](README.en.md)`)
- `templates/CLAUDE.{stack}.md` 9개는 **한국어 그대로** — 사용자 프로젝트로 복사되는 자산이라 i18n 시 매 세션 토큰 ×2

### 의식적 배제 (의도된 lazy translation)

**1. templates/ i18n 거부**
- 토큰 비용 ×2: `CLAUDE.kotlin.ko.md` + `CLAUDE.kotlin.en.md` 둘 다 유지하면 매 세션 어느 한쪽이 항상 dead weight
- 사용자가 자기 프로젝트 언어에 맞게 번역하는 게 더 자연스러움 (`/init` 후 직접 편집)
- 결정: README 만 i18n, templates 는 user-side i18n 위임

**2. 자동 동기화 거부**
- `README.en.md` 가 한국어 변경에 자동 따라가게 만드는 GHA 안 검토 → 거부
- 이유: LLM 자동 번역은 뉘앙스 손실. "stale 해도 한국어가 source of truth" 명시 + 사용자가 PR 로 동기화
- README.en.md 마지막 섹션에 명시: "Translations track the Korean source. If they ever drift, the Korean README is authoritative."

**3. CLAUDE.md / CHANGELOG / 기타 i18n 거부**
- README 가 entry point. 그 안에 들어온 사람은 영문 자료 없어도 코드 읽을 수 있음 (개발자).
- README 만 i18n 하는 게 80/20.

### 변경 파일
```
README.en.md             # 신규 (402줄)
README.md                # 최상단 언어 토글 추가, 배지 갱신
CHANGELOG.md, VERSION (1.25.0 → 1.26.0)
```

### 다음 P3 후보
1. opt-in 텔레메트리 (사용량 집계 → 토큰 절감 의사결정 근거)
2. 자체 plugin marketplace 등록 (Anthropic 승인 필요 — 큰 작업)

---

## 2026-05-08: v1.25.0 — P2 세 번째 (AI prompt regression — ai-eval-patterns skill)

**카테고리:** 결정

### 배경
ai-tester agent 가 단위/통합/RAG 테스트 패턴은 다루지만 **회귀 검증 (regression / eval)** 영역이 비어 있었음. LLM 출력은 비결정적이라 `assert ==` 가 안 통하는데, 그에 대응하는 표준 프로세스 부재.

기존 ai-patterns.md 가 530줄로 비대해 거기에 추가하면 가드레일 부담. 별도 skill 분리.

### 결정

**`ai-eval-patterns.md` 신설** (별도 skill, 202줄) — 4가지 검증 layer:

1. **Golden snapshot** — 가장 흔한 패턴
   - `tests/fixtures/prompts/{case}.json` (입력) + `{case}.golden` (기대 출력)
   - `UPDATE_GOLDEN=1 pytest` 로 갱신
   - golden 변경은 **항상 PR 에 포함 + 리뷰** — 자동 갱신 후 검토 없이 머지 금지

2. **LLM-as-judge** — 자유 형식 답변
   - rubric → score (1-5) → threshold 통과 여부
   - **target ≠ judge 모델** — 같은 모델로 자기 평가 = 가짜 합격

3. **메트릭 기반** (BLEU/ROUGE/embedding cosine) — 보조만
   - 의미 무시 등 한계 명시
   - 단독 사용 금지

4. **RAG 분리 평가** — retrieval recall + answer grounding
   - 검색 정확도와 생성 충실도를 나눠 측정

### 핵심 정책 결정

**1. Golden 자동 갱신 거부**
- v1.17.0 사고 (CHANGELOG 누락) 와 같은 교훈 — "검증 없는 자동 갱신" 은 의도 누락 위험.
- `UPDATE_GOLDEN=1` 은 명시적 갱신 모드, 결과는 PR diff 로 리뷰어 검증.

**2. judge 모델 분리 강제**
- target 이 sonnet 이면 judge 는 haiku. 같은 모델로 자기 평가 시 false positive 빈발 (논문 Anthropic eval 가이드).

**3. CI 비용 게이트**
- PR CI = mocked + golden (무료, 빠름)
- nightly = real LLM (낮은 비용)
- weekly = full eval set 100+ cases (높은 비용)
- 매 PR 실 호출 안티패턴 명시

**4. eval set 사람 큐레이션**
- LLM 자동 생성 거부 — 노이즈 + 정답 편향. 최소 5~10 케이스를 사람이 만들어야.

### 의식적 배제

- **`assert response == expected` 비결정 출력에** — golden + UPDATE_GOLDEN 패턴
- **temperature=0 결정성 강제** — 일부 모델만 지원, 미세 변동 여전
- **단일 케이스 합격** — 최소 5~10 fixture, 다양성 확보
- **eval set LLM 자동 생성** — 정답 편향
- **mock 없이 매 PR 실 호출** — 비용 폭증 + flaky CI

### 변경 파일
```
.claude/skills/ai-eval-patterns.md    # 신규 (202줄)
.claude/agents/ai-tester.md           # 워크플로 step 3 추가
.claude/commands/init.md              # python/python-multi/모노레포-python/infra 4 군데
README.md, CHANGELOG.md, VERSION (1.24.0 → 1.25.0)
```

### 다음 P2 후보
1. 추가 코드 스택 (Rust / NestJS / Django) — 사용자 요청 누적 시
   (P2 마지막 항목)

---

## 2026-05-08: v1.24.0 — P2 두 번째 (DevOps/Infra 카테고리 신설)

**카테고리:** 결정

### 배경
P2 후보 4건 중 가장 큰 공백 — 5개 코드 스택 (kotlin/go/python/nextjs/flutter) + 3개 코드 없는 모드 (marketing/sales/product) 외 인프라 영역이 통째로 비어 있었음. 사용자가 자기 앱의 helm chart, terraform module, k8s manifest 를 다룰 때 참조할 패턴 없음.

### 결정

**한 PR 로 인프라 클래스 통째 신설** — skill 3개 + agent 1개 + template 2개 + /init infra 모드:

1. **skill 3개**: terraform/kubernetes/helm 각각 ~130줄. 패턴 + 의식적 배제 + 운영 체크리스트.
2. **infra-generator agent (단일)**: modifier/tester 분리 안 함 — 인프라는 변경 빈도 낮고 작업 단위가 거의 generator 와 동일.
3. **/init infra 모드**: 코드 없이 IaC 만 다루는 프로젝트용. 자동 감지 안 함 (백엔드 프로젝트의 부속 인프라일 수 있음).

### 핵심 정책 결정

**1. Helm vs kustomize 우선순위**
- 자기 앱 manifest = kustomize (template 엔진 X, 단순)
- 외부 OSS (Prometheus, Cert-Manager 등) = Helm
- `helm-patterns.md` 의 첫 섹션이 이 결정 명시

**2. terraform workspace 배제**
- 환경 분리에 부적합 (같은 backend 의 다른 key 만 다를 뿐 blast radius 동일)
- 디렉토리 분리 (`envs/{prod,staging,dev}/`) 가 안전
- 예외: 동일 환경 multi-region 만 workspace 가능

**3. K8s 필수 항목**
- resources requests/limits — 미설정 = 안티패턴 (노드 OOM 시 random kill)
- liveness ≠ readiness — 둘 다 정의 (재시작 vs 트래픽 차단)
- image tag = SemVer 명시, latest 금지
- Secret 평문 금지 — ExternalSecret/SOPS/Sealed Secrets

**4. apply 자동화 거부**
- `settings.infra.json` 의 deny 리스트에 `terraform apply -auto-approve`, `kubectl delete namespace`, `helm uninstall` 명시
- 운영 환경 실수 차단

**5. modifier/tester agent 분리 안 함**
- 코드 스택은 generator/modifier/tester 3종이지만, 인프라는 generator 한 개로 충분
- 이유: 인프라 변경 빈도 낮음, 단위 테스트 개념 약함 (terraform plan/k8s dry-run 자체가 검증), modifier 와 generator 경계 모호 (대부분 새 모듈 추가 또는 변수 추가)

### 변경 파일
```
.claude/skills/terraform-patterns.md      # 신규 (129줄)
.claude/skills/kubernetes-patterns.md     # 신규 (147줄)
.claude/skills/helm-patterns.md           # 신규 (138줄)
.claude/agents/infra-generator.md         # 신규 (70줄)
.claude/templates/CLAUDE.infra.md         # 신규 (100줄)
.claude/templates/settings.infra.json     # 신규
.claude/commands/init.md                  # infra 모드 행 + 자동 감지 안내 갱신
README.md, CHANGELOG.md, VERSION (1.23.0 → 1.24.0)
```

### 의식적 배제

- **infra 자동 감지** — `*.tf`, `Chart.yaml` 마커는 백엔드 프로젝트 부속일 수 있어 가정 안 함. 명시 선택만.
- **infra-modifier / infra-tester** — 코드 스택 패턴 답습 안 함. 인프라 컨텍스트엔 generator 만으로 충분.
- **모노레포 공통 유지에 infra-generator 추가** — 모노레포가 너무 비대해짐. 인프라 작업은 별도 infra 모드로 분리.

### 다음 P2 후보
1. AI prompt regression suite (ai-tester 보강)
2. 추가 코드 스택 (Rust / NestJS / Django) — 사용자 요청 누적 시

---

## 2026-05-08: v1.23.0 — P2 첫 번째 (observability-patterns skill)

**카테고리:** 결정

### 배경
P1 5건 완료 → P2 카테고리 진입. P2 후보 4건 (observability / DevOps-Infra / 추가 스택 / AI prompt regression) 중 가장 영향 범위 넓은 observability 부터.

### 결정

**Observability 영역을 단일 skill 로 통합** — 스택별로 분산하지 않음:
- 후보: 스택별 `observability-{kotlin,go,python,nextjs,flutter}.md` 5개로 쪼개기
- 결정: **횡단 단일 skill** (`observability-patterns.md`) — 패턴 (logging, tracing, error tracking, SLO) 자체는 스택 무관. 스택별 라이브러리만 표 형태로 매핑.
- 이유: 토큰 효율 (5번 로드보다 1번), 일관성 (필드 컨벤션 한 곳에 정의), 유지보수 비용 (5분의 1)

### 핵심 정책 결정

**1. structured logging 필드 컨벤션**
- `ts`, `level`, `msg`, `trace_id`, `span_id`, `service`, `env` — 모든 스택 공통 필수
- 이벤트 이름 = 스네이크케이스 명사 (`user.signup`)
- PII 직접 로깅 금지 (ID 만)

**2. OTel 환경변수 표준화**
- `OTEL_EXPORTER_OTLP_ENDPOINT` / `OTEL_SERVICE_NAME` / `OTEL_RESOURCE_ATTRIBUTES`
- 5개 스택 모두 동일 환경변수 — 인프라 한 곳에서 설정

**3. Flutter OTel 한계 명시**
- Dart SDK 미성숙 → Sentry 또는 Firebase Performance 권장. 거짓 약속 안 함.

**4. SLO 3개 이내 권고**
- Availability / Latency p99 / Error rate 만. "관리 가능 범위" 강조.

### 의식적 배제

- **모든 함수에 span** — 비용 폭증, 안티패턴
- **개발 환경 OTLP 강제** — 로컬 노이즈 → `OTEL_SDK_DISABLED=true`
- **4xx Sentry 전송** — 사용자 입력 오류는 알람 가치 없음

### 변경 파일
```
.claude/skills/observability-patterns.md  # 신규 (122줄)
.claude/commands/init.md                  # 5개 스택 + 모노레포 공통에 추가
README.md, CHANGELOG.md, VERSION (1.22.0 → 1.23.0)
```

### 다음 P2 후보 우선순위
1. DevOps/Infra (terraform/k8s/helm) — 완전 비어있는 영역
2. 추가 코드 스택 (Rust/NestJS/Django) — 사용자 요청 누적되면
3. AI prompt regression (snapshot/golden 테스트) — ai-tester 보강

---

## 2026-05-08: v1.22.0 — P1 묶음 (MCP 프리셋 skill + session-start plugin 표시)

**카테고리:** 결정

### 배경
P1 카테고리 5건 중 3건 (`/upgrade`, `/release`, P0 4건) 완료. 남은 2건 (MCP 프리셋, plugin health check) 둘 다 작은 작업이라 한 PR 에 묶음.

### 결정

**MCP 프리셋 — skill 로만 제공, 자동 활성화 X**:
- `settings.{stack}.json` 에 `mcpServers` 디폴트 채우는 안을 검토 → 배제.
- 이유: 잘못된 환경변수 (`${DATABASE_URL}` 미설정) 로 매 세션이 npx 다운로드 또는 connection error 로 깨질 수 있음. 사용자가 의식적으로 활성화하는 것이 안전.
- 결정: `.claude/skills/mcp-presets.md` 에 스택별 snippet 만. 사용자가 `settings.local.json` (개인) 또는 `settings.json` (팀 공유) 에 직접 붙여넣음.
- 5개 MCP 커버: postgres, filesystem, github, puppeteer (Next.js), fetch (marketing).

**Plugin health check — 표시만, 검증 X**:
- session-start.sh 가 enabledPlugins 의 plugin 키를 `claude plugin list` 로 검증 가능한지 검토 → 그런 CLI 명령 없음.
- Claude Code 내부 plugin 설치 상태는 외부 bash hook 에서 알 수 없음.
- 결정: enabledPlugins 키 한 줄 표시 + `/plugin install` 안내. 사용자가 `/plugin` 으로 직접 확인.
- settings.json + settings.local.json 합집합 — 개인 plugin 도 표시 (jq -s `.[]` 가 아닌 `to_entries[]` 로 두 파일 union 처리).

### 의식적 배제

- **mcpServers 디폴트 활성화** — 파괴 위험 vs 편의성. 안전 우선.
- **plugin 자동 설치** — `/plugin install` 은 사용자 동의 필요. hook 에서 자동 호출 부적절.
- **enabledPlugins 미설치 plugin 강제 제거** — 사용자가 임시로 비활성화한 것일 수 있음.

### 변경 파일
```
.claude/skills/mcp-presets.md         # 신규 (~140줄)
.claude/hooks/session-start.sh        # +10줄 (Plugins 표시)
README.md, CHANGELOG.md, VERSION (1.21.0 → 1.22.0)
```

### P1 카테고리 마무리
| P1 항목 | 버전 | 상태 |
|---------|------|------|
| /upgrade selective diff | v1.20.0 | ✅ |
| /release 자동화 | v1.21.0 | ✅ |
| MCP 프리셋 | v1.22.0 | ✅ |
| Plugin health check | v1.22.0 | ✅ (표시만) |

P1 5건 (#5–#8 + P0) 모두 완료. 다음은 P2 (DevOps/Infra, Observability, 추가 스택, AI prompt regression) 또는 P3 (i18n, 텔레메트리, plugin marketplace).

---

## 2026-05-08: v1.21.0 — P1 `/release` 커맨드 (SemVer + CHANGELOG 동기화 + PR 체인)

**카테고리:** 결정

### 배경
v1.17.0 → v1.17.1 사고 (CHANGELOG 누락 + README 배지 미갱신) 가 **사람이 매 릴리스마다 동일 작업을 수동으로 하다 빠뜨린** 결과. v1.18.0 ~ v1.20.0 까지도 매번 VERSION + CHANGELOG + README + memory 4개 파일을 손으로 갱신. 한 단계 자동화 안 하면 같은 사고가 반복됨.

### 결정

**`/release [patch|minor|major]` 커맨드 신설** — 릴리스 단계를 한 번에:
1. 사전 조건 검증 (브랜치 ≠ main, working tree 깨끗)
2. SemVer bump 계산
3. CHANGELOG 검증 (사용자가 미리 작성했어야 — 없으면 템플릿 안내 후 종료)
4. CHANGELOG 헤더의 버전·날짜 자동 sync
5. VERSION 갱신
6. README 배지 갱신 (`version-X.Y.Z-blue`)
7. `chore(release): vX.Y.Z` 커밋
8. `/pr` 체인 (--no-pr 가 아니면)

### 핵심 정책 결정

**1. CHANGELOG 자동 작성 금지 — 검증만**
- 자동 생성 시 의도 누락 가능성 (어떤 카테고리, 왜 변경했는지). v1.17.0 사고가 "사람의 누락" 이지 "자동화 부재" 가 아님.
- 사용자가 작성 안 했으면 템플릿 보여주고 정중히 종료.

**2. main 브랜치 호출 거부**
- 우리 패턴은 별도 release PR 이 아니라 **기능 PR 에 VERSION/CHANGELOG 동시 bump** (v1.18.0~1.20.0 모두). `/release` 가 이 패턴을 강제.

**3. 태그 push 안 함**
- `auto-tag.yml` 이 main 의 VERSION 변경을 감지해 태그 자동 생성. `/release` 가 직접 태그하면 중복.

### 의식적 배제

- `/release --auto-changelog` 같은 자동 생성 옵션 — v1.17 사고 재발 방지를 위해 일부러 미제공
- `/release` 가 main 으로 직접 push — 기능 PR 패턴 강제 (위 정책 2)
- pre-release (`-rc.1` 등) 지원 — GitHub Actions 에서도 명시적으로 stable 만 latest 태그. `/release` 도 stable 만.

### 변경 파일
```
.claude/commands/release.md      # 신규 (198줄)
README.md                         # 빠른 시작에 /release 안내
CHANGELOG.md, VERSION (1.20.0 → 1.21.0)
```

### Dogfooding 한계
이번 v1.21.0 자체는 `/release` 가 도입되는 PR 이라 본인을 사용해 자기를 릴리스할 수 없음 (chicken-and-egg). v1.21.1 부터 본격 dogfood.

---

## 2026-05-08: v1.20.0 — P1 `/upgrade` selective diff 커맨드

**카테고리:** 결정

### 배경
v1.19.0 에서 `bootstrap.sh` 가 custom 자산을 보존하도록 개선됐지만 갱신 단위는 여전히 all-or-nothing. 사용자가 "skills 만 새로 받아보고 싶다", "agents 변경 없이 hooks 만 갱신" 같은 부분 갱신을 원할 때 경로 없음. 큰 변경(예: 26개 agents 일괄 변경) 을 한 번에 적용하기엔 심리적 부담이 큼.

### 결정

**`/upgrade` 커맨드 신설** — 카테고리 단위 selective diff:
- `agents`, `commands`, `skills`, `templates`, `hooks`, `settings` 6개 카테고리
- 디폴트는 dry-run (통계만), `apply <cat>` 로 명시적 적용
- `--version <ref>` 로 임의 시점 비교 가능 (롤백 결정용)
- 보존 정책은 bootstrap.sh 와 동일 (`custom/` + `settings.local.json`)

### 인터페이스 결정 사유

세 가지 후보 중 **카테고리 단위** 선택:
1. **카테고리 단위** ✅ — 변경 단위가 자연스럽고 인터랙션 1~2회로 끝남
2. 파일별 fine-grained — 정밀하지만 인터랙션 폭증 (8개 변경이면 16번 Y/N)
3. 프리셋 (minimal/standard/full) — 단순하지만 사용자 의도와 매핑 안 맞음

### 사용 시나리오

```
/upgrade                      → 통계 (예: skills +0 ~2 -0)
/upgrade apply skills         → skills 만 갱신
/upgrade --version v1.18.0    → 1.18.0 과 비교 (롤백 결정용)
/upgrade apply all            → bootstrap update 호출
```

### `/starter` 와의 관계

| 커맨드 | 입자 | 인터랙션 |
|--------|------|----------|
| `/starter update` | 전체 | 1회 확인 |
| `/upgrade apply <cat>` | 카테고리 | 카테고리당 1회 |
| `/upgrade apply all` | 전체 | `/starter update` 와 동일 (내부 호출) |

`/upgrade apply all` 이 bootstrap.sh 를 그대로 호출하므로 `/starter` 와 기능 중복 같지만, **diff 보기 → 부분 적용 흐름** 이 `/upgrade` 의 핵심 가치. 둘 다 유지.

### 변경 파일
```
.claude/commands/upgrade.md     # 신규 (205줄)
README.md                        # 빠른 시작에 /upgrade 안내
CHANGELOG.md, VERSION (1.19.0 → 1.20.0)
```

### 한계
- 카테고리 단위 부분 갱신 시 의존성 불일치 가능 (예: `commands/` 만 갱신했는데 새 command 가 미설치 agent 호출). 사용자에게 경고 명시.
- `templates/` 갱신은 사용자 루트 `CLAUDE.md` 에 영향 없음 — `/init` 재실행 시에만 반영.

---

## 2026-05-07: v1.19.0 — P0 안정성 패치 (bootstrap 비파괴 + 버전 핀 + CI 매트릭스 + 300줄 가드)

**카테고리:** 결정

### 배경
v1.18.0 까지 `/start` 등 사용자 경험은 다듬어졌으나, **하네스 자체의 안정성 격차** 4건이 누적돼 있었음:
1. `bootstrap.sh` update 가 사용자 custom agent/hook/`settings.local.json` 을 통째로 덮어씀 → 매 update 마다 사용자 자산 손실 위험.
2. 버전 핀·롤백 불가 — 깨진 릴리스 발생 시 복구 수단 없음.
3. README 가 "PR 전 `bootstrap.sh` 직접 실행" 을 약속하지만 CI 검증 없음.
4. CLAUDE.md ≤ 300줄 캡 (v1.17.0) 이 정책으로만 존재, hook 가드 없음.

### 결정

**P0 4건 일괄 패치**:

1. **`bootstrap.sh` 디폴트 보존 모드** — `agents/custom/`, `commands/custom/`, `hooks/custom/`, `skills/custom/`, `settings.local.json` 자동 보존. `--no-preserve` 가 escape hatch.
2. **`--version <ref>` 핀 옵션** — `git fetch --depth=1 origin <ref>` 로 임의 태그/브랜치/SHA 체크아웃 후 sparse-checkout. `curl | bash -s -- --version v1.x.x` 형태.
3. **`.starter-version-prev` 자동 기록** — update 시 직전 버전을 보존 디렉토리 경유로 기록 → `/starter rollback` 으로 toggle 복원 가능.
4. **`/starter` 커맨드 확장** — `check` 가 3개 버전(현재/최신/이전) 표시, `update --version` 핀, `rollback` 신설.
5. **CI install matrix** — fresh-install / update-preserve / update-no-preserve / version-pin / rollback-meta / hooks-on-empty-project / claude-md-line-cap 7개 job.
6. **CLAUDE.md 300줄 가드 hook** — `post-edit-lint.sh` 의 case 에 `*CLAUDE.md|*CLAUDE.*.md` 추가, 초과 시 경고 + 이관 가이드.

### 사용자 자산 디렉토리 규약 (신설)

스타터 update 후에도 보존되는 영역:
```
.claude/agents/custom/     .claude/commands/custom/
.claude/hooks/custom/      .claude/skills/custom/
.claude/settings.local.json
```

루트 직속(`agents/`, `commands/` 등) 에 둔 사용자 파일은 update 시 사라짐. 이 정책을 README + `/starter` 커맨드에서 명시.

### 영향
- 사용자 update 시 자산 손실 위험 0
- 깨진 릴리스 발생 시 30초 안에 rollback 가능
- 매 PR 마다 install/update/preserve/pin/rollback 시나리오 자동 검증
- CLAUDE.md 비대화 hook 으로 즉시 차단

### 변경 파일
```
bootstrap.sh                                  # --version, --no-preserve, --preserve, 보존 로직, prev 기록
.claude/commands/starter.md                   # check/update/rollback 재작성
.claude/hooks/post-edit-lint.sh               # CLAUDE.md case 추가
.github/workflows/install-matrix.yml          # 신규 (7 jobs)
README.md                                     # 옵션 + 보존 규약 + rollback 안내
CHANGELOG.md, VERSION (1.18.0 → 1.19.0)
```

### 검증
로컬에서 fresh-install / update-preserve / update-no-preserve / `--version v1.17.0` 핀 / 빈 프로젝트 hook silent / 300줄 가드 트리거 — 6개 시나리오 모두 통과.

### 마이그레이션
- 기존 `bootstrap.sh` 사용자: 변경 불필요. 새 디폴트가 더 안전.
- custom agent/command 가 있는 사용자는 `custom/` 하위로 이동 권장.

---

## 2026-04-27: v1.18.0 — 신규 기능 시작 흐름 단순화 (`/start` 신설 + `/planner` → `/plan` 흡수)

**카테고리:** 결정

### 배경
신규 기능 시작이 `/new worktree → /planner → /plan` 3단계로 분리돼 있어 사용자 인지 부담이 컸음. `/planner` 와 `/plan` 의 범용 모드가 거의 동일 (둘 다 소크라테스식 인터뷰 + 자연어 요청 처리) 해서 어떤 걸 쓸지 매번 망설이게 했음. 모노레포에선 인터랙션 2회 (실행 모드 선택 + 안전장치 yes/no) 가 매번 발생.

### 결정

**`/start <기능>` 신설** — 신규 기능 시작의 단일 진입점:
1. worktree 자동 생성 (`feature/{name}`, base = origin/dev 또는 origin/main)
2. planner agent 호출 → PRD + 역할별 프롬프트
3. 단일 스택은 자동 generator 실행 / 모노레포는 1회만 확인
4. 인터뷰는 요청이 명확하면 0개 — 모호할 때만 최대 3개

**`/plan` 이 `/planner` 흡수**:
- 디폴트 = PRD + 역할 프롬프트 (이전 `/planner` 동작, 실행 없음)
- `--teams` = PRD 후 즉시 generator (이전 `/planner --teams`)
- `--light` = 가벼운 단일 변경 계획 (이전 `/plan` 범용 모드)
- `api`/`db` 서브 그대로
- `--marketing|--sales|--gtm` 그대로

`commands/planner.md` 제거 — frontmatter description 1개 절감 (매 세션 로드되는 토큰).

### 영향
- 사용자 흐름 5 inputs → 1~2 inputs (신규 기능 시작 마찰 80% 감소)
- 모노레포 인터랙션 2회 → 1회
- frontmatter description 14 → 13 (스킬 리스트 토큰 절감)
- 본문은 on-invoke 이지만 통합으로 ~150줄 절감

### 변경 파일 (총 19개)
```
.claude/commands/start.md            # 신규
.claude/commands/plan.md             # planner 흡수 (271→390줄, 통합 효과)
.claude/commands/planner.md          # 삭제
.claude/commands/init.md             # 완료 메시지에 /start 우선 안내
.claude/agents/{planner,gtm-planner,security-reviewer}.md  # 호출자 표기 갱신
.claude/templates/CLAUDE.{kotlin,go,python,nextjs,flutter}.md  # 5개 — 표에 /start 행 추가
.claude/templates/CLAUDE.{monorepo,marketing,sales,product}.md # 4개 — /planner → /plan 또는 /start
.claude/templates/{role-prompt,gtm-history}.md             # 호출자 표기 갱신
README.md, CHANGELOG.md, VERSION (1.17.1 → 1.18.0)
```

### 마이그레이션
- `/planner X` → `/plan X`
- `/planner X --teams` → `/start X` (worktree 포함) 또는 `/plan X --teams` (worktree 없이)
- `/new worktree feature-X` + `/planner X` → `/start X` 한 번에

---

## 2026-04-25: v1.17.0 — GHCR semver-only 정책 + CLAUDE.md ≤ 300줄 캡

**카테고리:** 결정

### 배경
GitHub Packages (GHCR) 가 publish 워크플로 호출마다 `v1`, `v1.0`, `1.0.0`, `latest`, `sha-*` 등 5–7개 태그를 동시에 만들어내며 패키지 목록이 비대화. 동시에 사용자 프로젝트의 CLAUDE.md 도 정해진 상한 없이 비대해져 매 세션 토큰 낭비가 누적되는 패턴 관찰. 두 문제 모두 "단일 진실의 형식"이 없어서 발생한 것으로 보고 한 릴리스에서 묶어 정책화.

### 핵심 결정

1. **GHCR 태그는 `MAJOR.MINOR.PATCH` + `latest` 만** — `v1`, `v1.0`, `sha-*`, `dev`, `pr-*` 모두 발행 금지. 이전 docker/metadata-action 의 multi-tag 출력 (`{{major}}`, `{{major}}.{{minor}}`) 도 전부 삭제. semver 단일 vs 부분 태그 혼용은 캐시·롤백 모호성을 만들어 운영 사고 위험이 더 큼.
2. **`latest` 는 안정 릴리스에만** — pre-release (`-rc.1`, `-beta`) 는 enable 조건 `!contains(github.ref_name, '-')` 로 제외. `is_default_branch` 가 아닌 ref 기반 — 릴리스는 무조건 태그에서 트리거되므로.
3. **non-semver cleanup 은 같은 워크플로 안에서** — publish job 의 needs 후속으로 `cleanup-non-semver` job 강제. `actions/github-script` + `packages.deletePackageVersion*` API 로 자동 삭제. cleanup 을 별도 scheduled workflow 로 빼면 사용자가 끄거나 잊을 수 있음 — publish 와 한 묶음으로 강제.
4. **동일 semver overwrite 허용 + `workflow_dispatch` 트리거** — 정정 빌드(예: 같은 1.2.3 재빌드)는 의도된 동작. GHCR 은 기본 덮어쓰기.
5. **스테이징 이미지는 별도 패키지명** — production GHCR 에 비-semver 태그가 단 하나도 없어야 cleanup job 이 안전하게 동작. 스테이징 필요 시 `{repo}-staging` 별도 패키지 또는 별도 레지스트리 사용 권장.
6. **CLAUDE.md ≤ 300줄 — 4곳 분산 가드** — 한 곳에만 두면 우회 가능. 스타터 핵심 원칙 1-1 (이 저장소) / `/init` Step 3 (설치 시) / `/rule` Step 5 (규칙 추가 시) / 13개 templates footer (사용자 즉석 편집 시). 280–300 경고, > 300 차단.
7. **이관 형식: `상세: .claude/skills/{topic}.md` 한 줄** — 인덱스 패턴 통일. claude code 가 필요시에만 skill 파일을 on-demand 로드.

### 철학
- **단일 진실의 형식이 없으면 비대화는 시간 문제** — 패키지 태그도, 컨텍스트 파일도. 형식을 좁히면 자동 정리/검증이 가능해짐.
- **정책은 가능한 가장 가까운 곳에서 강제** — GHCR cleanup 을 별도 cron 으로 빼지 않고 publish 워크플로 끝에 묶은 것, CLAUDE.md cap 을 install/rule/template 모든 진입점에 박은 것 동일한 원리.
- **사용자 매 세션 비용을 0이 아닌 수로 곱한 값이 토큰 비용** — CLAUDE.md 1줄은 100명 × 매 세션. 10줄 줄이면 1000줄/일 절감.

### 영향 범위
- 신규 사용자 프로젝트: `/init` 시점부터 두 정책 자동 적용
- 기존 사용자 프로젝트: `/starter update` 또는 직접 적용 필요
- 스타터 자체 publish 워크플로는 .github/workflows 에 별도 publish.yml 이 없어서 이번 릴리스에는 영향 없음 (정책만 라이브러리에 추가)

### 후속
- v1.17.1 — README.md version badge 1.16.0 → 1.17.1 업데이트, 본 메모리 항목 추가 (v1.17.0 릴리스 시 누락된 부수 문서 갱신)

---

## 2026-04-20: v1.16.0 — Tier 1 보안 리뷰 자동화 + Docker/Redis 패턴

**카테고리:** 결정

### 배경
기능 구현 완료 시점에 보안 검토가 수동이었고, Dockerfile·Redis 패턴도 프로젝트마다 재발명하고 있었음. 기능이 머지되기 직전에 **반드시 통과해야 하는 게이트**로 보안을 못박고, 컨테이너·캐시 베스트 프랙티스를 스킬로 내재화.

### 핵심 결정

1. **security-reviewer 는 agent, 개입 시점은 `/pr` Step 1.5** — 사용자가 기능을 만들 때마다 마지막 단계에서 자동 호출. 코드 수정은 안 하고 리포트만 반환 (수정은 해당 스택의 modifier agent).
2. **3단계 판정 체계** — PASS/REVIEW/BLOCK. Critical 1개면 exit (강제 차단), High 1개면 확인 후 진행, 나머지는 경고만.
3. **`--skip-security` 는 hotfix 전용 예외** — 이유 입력 필수 + PR 본문에 경고 주입. 일반 개발 플로우엔 쓰지 말 것.
4. **Docker 는 `/new dockerfile` 서브명령으로 분리** — `/new` 의 기존 api/component/screen 라인에 얹어서 호출. `docker-patterns.md` 스킬이 실제 템플릿 공급.
5. **Redis/Cache 는 스킬 only** — 별도 커맨드 없음. ai-generator/python-generator/kotlin-generator 가 필요 시 `cache-patterns.md` 읽고 적용. 과도한 커맨드 증식 방지.

### 철학
기능 게이트는 command/skill 레이어가 아니라 **agent 호출 자체**로 강제해야 안 우회됨 — `/pr` 하면 반드시 security-reviewer 가 돈다. 우회 옵션(`--skip-security`)은 있지만 비용이 높게(이유 요구 + PR 본문 경고) 설계.

### 구조

```
.claude/
  agents/security-reviewer.md        # 신규 agent (opus, Read/Grep/Bash/Skill)
  skills/security-patterns.md        # OWASP + 스택별 체크리스트
  skills/docker-patterns.md          # 멀티스테이지 + compose + .dockerignore
  skills/cache-patterns.md           # Redis cache/rate-limit/lock/session
  commands/pr.md                     # Step 1.5 보안 리뷰 자동 실행 추가
  commands/new.md                    # dockerfile 서브명령 추가
```

---

## 2026-04-17: v1.9.0 — /planner GTM 옵션 + gtm-planner agent

**카테고리:** 결정

### 배경
v1.8.0 의 `/marketing` 은 카피·SEO 같은 **task 단위** 라우터였고, 기능 단위 GTM 문서(포지셔닝·런치 체크리스트·세일즈 덱)를 체계적으로 생산·보관할 수단이 없었음. 기획(/planner PRD) ↔ 마케팅/세일즈 전략 ↔ 실제 릴리스 버전을 **한 축으로** 연결하는 구조가 필요했음.

### 핵심 결정

1. **플래그 확장, 서브명령 없음** — `/planner <기능> --marketing|--sales|--gtm`. 기존 `--teams`/`--output-only` 패턴과 일관.
2. **전담 agent 분리** — `planner` (PRD 전담) / `gtm-planner` (GTM 전담). 코드 작성은 둘 다 금지. 도구 차이 — gtm-planner 만 `Skill` 보유해 `marketing-skills:*` 체이닝 가능.
3. **2단 산출물 구조** — `docs/specs/{feature}/{marketing,sales}.md` 은 **살아있는 문서**, `docs/gtm/{YYYY-MM-DD}-{feature}/` 은 **스냅샷**. 중복처럼 보이지만 의도적 — 편집 vs 기록을 분리.
4. **날짜 + 버전 두 축 히스토리** — 디렉토리는 날짜 기반 (초안 시점), `meta.yaml` 의 `released_version` 은 버전 기반 (`/merge` 에서 자동 기록). `history.md` 는 두 관점 모두로 조회 가능.
5. **재기획 시 새 디렉토리** — 동일 feature 재GTM 하면 기존 스냅샷 보존하고 새 날짜 디렉토리 추가. 히스토리성.
6. **`/marketing` 과 역할 분리** — `/marketing` = task 단위 스킬 라우터, `/planner --gtm` = 기능 단위 종합 문서. 상호 보완, 대체 아님.

### 구조

```
.claude/
  agents/gtm-planner.md                 # 신규 agent (opus, Skill 포함)
  commands/planner.md                   # --marketing/--sales/--gtm 플래그 추가
  commands/merge.md                     # 3-2b 단계 추가 — GTM 스냅샷 릴리스
  templates/marketing-plan.md           # 살아있는/스냅샷 템플릿
  templates/sales-plan.md
  templates/gtm-history.md

docs/
  specs/{feature}/marketing.md          # 살아있는
  specs/{feature}/sales.md
  gtm/history.md                        # 인덱스
  gtm/{date}-{feature}/                 # 스냅샷
```

### 열린 이슈
- `/merge` 의 브랜치명 → feature 이름 추출이 `feature/*` / `fix/*` 등 표준 prefix 를 가정. 비표준 브랜치명이면 매칭 실패
- history.md 편집 로직이 python3 의존 — 다른 환경에선 meta.yaml 만 갱신됨

---

## 2026-04-17: v1.8.0 — /marketing 커맨드 + marketing-skills 플러그인

**카테고리:** 결정

### 배경
코드 생성 중심의 기존 커맨드 셋(/new, /plan, /planner 등) 외에, 마케팅·카피·SEO·CRO 같은 **비개발 워크플로**를 Claude Code 안에서 일관되게 처리할 수 있는 진입점이 없었음. `marketing-skills` 플러그인이 35개의 전문 스킬을 제공하지만, 어떤 스킬을 언제 호출해야 하는지 매번 기억해야 하는 부담이 있었음.

### 핵심 결정

1. **라우터 커맨드로 구현** — `/marketing` 은 코드를 작성하지 않는 순수 라우터. 35개 스킬을 6개 카테고리(strategy/seo/cro/channel/retention/context)로 압축해 인지 부하 축소.
2. **3-layer 진입 방식** — (a) 메뉴 (인수 없음) → (b) 서브명령 (`/marketing seo audit`) → (c) 자연어 (`/marketing 회원가입 전환율이 낮아`). 자연어 모드는 한·영 키워드 점수 매칭으로 **최고점 1개 자동 실행** (동점 시 표 등장 순서상 위쪽 우선).
3. **카테고리 6개로 고정** — 35개를 flat 하게 나열하면 선택 비용이 높아, 사용 빈도·의미 단위로 6개로 묶음.
4. **`product-marketing-context` 는 자연 호출** — 전용 서브명령을 두지 않고, 최초 실행 시 한 번만 설정을 권유. 강제하지 않음.
5. **스택 무관** — monorepo 역할 prefix(backend/frontend/mobile) 체크 없이 그대로 실행.

### 구조

```
.claude/commands/marketing.md    # 라우터 커맨드 (3-layer 진입)
.claude/settings.json            # marketing-skills@marketingskills 플러그인 활성화
```

### 열린 이슈
- 자연어 라우팅 점수 정확도는 사용 로그로 보정 필요 (현재는 표 등장 순서 우선)
- `.agents/product-marketing-context.md` 가 없는 최초 사용자의 UX — 현재는 안내만 하고 강제하지 않음

---

## 2026-04-17: v1.7.0 — 모노레포 모드 + 기획자 agent

**카테고리:** 결정

### 배경
기존에는 `/init` 이 **한 스택만** 선택하고 나머지 agent/template 를 삭제하는 구조였음. 그러나 실제로는 `backend/` + `frontend/` + `mobile/` 을 한 저장소에서 운영하는 조직이 많고, 매 저장소마다 다른 하네스를 유지하면 일관성이 깨졌음. 또한 기능 기획 → 구현 사이에 "각 스택에 어떤 지시를 내릴지" 를 매번 수동으로 작성하는 부담이 있었음.

### 핵심 결정

1. **모노레포 자동 감지 + 단일 스택 호환** — 루트에서 `backend|api|server/`, `frontend|web|client/`, `mobile|app/` 디렉토리를 스캔해 2개 이상이면 `monorepo` 모드, 1개/0개면 기존 단일 스택 로직으로 폴백. 파괴적 변경 없음.
2. **`.claude/stacks.json` 을 단일 진실의 원천으로** — `/new`, `/plan`, `/planner`, `pre-push.sh`, PostToolUse/Stop hooks 가 모두 이 파일을 읽어 분기. 없으면 기존 동작.
3. **CLAUDE.md 중첩 배치** — 루트는 얇은 인덱스, 각 역할 디렉토리에 `{path}/CLAUDE.md` 배치. Claude Code 의 상위 CLAUDE.md 누적 로드 특성을 활용해 컨텍스트 오염 최소화.
4. **역할 prefix** — `/new backend api User`, `/plan frontend component Button` 식으로 대상 스택을 명시. 경로는 `stacks.json` 에서 lookup 하므로 별칭 디렉토리명 (`api`, `web`, `app`) 지원.
5. **기획자 agent 분리** — PRD 작성과 역할별 프롬프트 분배를 **코드 작성과 분리된 agent** 에 맡김. `planner` agent 는 Read/Write/Grep/Glob 만 가지고 `docs/specs/` 산출.
6. **Agent Teams 는 옵션** — 한 번의 호출로 backend·frontend·mobile generator 를 **병렬** 실행 가능하지만, 반드시 옵션으로. 기본은 `ask` 모드.

### 구조

```
.claude/
  stacks.json               # 매니페스트 (모노레포일 때만)
  agents/planner.md         # 기획자 agent (opus)
  commands/planner.md       # /planner 슬래시 커맨드
  templates/
    CLAUDE.monorepo.md      # 루트 인덱스 템플릿
    settings.monorepo.json  # 병합 settings (경로 가드 hooks)
    prd.md                  # PRD 템플릿
    role-prompt.md          # 역할별 구현 프롬프트 템플릿

docs/specs/{feature}.md     # PRD (팀 공유)
docs/specs/{feature}/
  backend.md                # backend 구현 프롬프트
  frontend.md               # frontend 구현 프롬프트
  mobile.md                 # mobile 구현 프롬프트
```

### 교훈

- **hook 은 루트 1개**라는 Claude Code 제약을 받아들이고 hook 내부에서 경로로 분기하는 방식이 깔끔 — 하위 디렉토리 `.claude/` 중첩은 복잡성만 키움
- **병렬 agent 호출**은 파일 경로가 역할별로 분리될 때만 안전 — 단일 스택에선 Teams 의미 없음 (자동 폴백)
- **별칭 디렉토리명 허용**은 유연성 ↑ 이지만 **역할 prefix 는 표준 이름 고정** (`backend`/`frontend`/`mobile`) — UX 일관성 우선

### 다음 호기 고려 항목
- `.claude/settings.json` 에 `planner.defaultExecution` 추가 (ask / teams / output-only 기본값)
- `docs/specs/` GitHub Actions 로 lint (PRD 섹션 누락 체크)
- PR 템플릿 연동 — `/pr` 이 관련 PRD 를 자동 링크

---

## 2026-04-17: v1.6.0 — 커맨드 전면 재편 + 워크플로 단순화

**카테고리:** 결정

### 배경
커맨드 16개가 평평(flat)하게 흩어져 있어 근육 기억 부담이 크고, `new-*`, `design-*`, `review-*` 접두사가 혼재해 의미가 겹쳤음. 또한 커밋→PR→머지→정리 과정이 수작업이라 피처 완료 후 정리 단계가 누락되는 경우가 있었음.

### 변경 사항

**커맨드 통합 (16 → 11)**
- `new-*` 6개 → `/new` 디스패처 (+ 자동 감지: 이름 패턴·스택으로 서브 생략 가능)
- `design-*` 2개 → `/plan` 으로 흡수 (`/plan api`, `/plan db`)
- `/review-api` → `/review` api 모드로 흡수
- `/improve` → `/rule` 로 개명 (결과물 중심 네이밍)
- `/pr` 신설 (기존 `/new-feature pr` 분리)
- `/merge` 신설 (`gh pr merge` + main 최신화 + 태그 + worktree 정리)
- `/starter` 신설 (install/update 통합 진입점)

**자동 체인 (각 단계 확인)**
- `/commit` → 피처 브랜치면 `/pr` 제안 → 수락 시 `/pr` → `/merge` 제안 → 수락 시 `/merge`
- 완전 자동이 아닌 "연속 확인" 체인 (각 단계에서 y/N 또는 옵션 선택)

**컨텍스트 자동 로드**
- `memory/MEMORY.md` 를 세션 시작 시 자동 참조하도록 CLAUDE.md 템플릿 전체에 지시 추가
- `/memory show` 모드 제거 (자동 로드로 대체)

**bootstrap.sh install/update 통합**
- 기존 `.claude/` 감지 시 백업 없이 전체 교체
- `.claude/.starter-version` 에 버전 기록 (팀 공유용)

### 핵심 원칙
- 디스패처 커맨드는 스택·이름 패턴으로 자동 감지 → 사용자가 타이핑 최소화
- 명시 서브명령은 override 용도로만 사용 (자동 감지가 틀릴 때)
- 체인 제안은 "다음 단계를 물어봄" — 강제하지 않음

**관련 파일:** `.claude/commands/*.md` (11개), `.claude/templates/CLAUDE.*.md`, `bootstrap.sh`, `README.md`, `CHANGELOG.md`

---

## 2026-04-15: v1.4.0 — /design-db DB 설계 자동화 추가

**카테고리:** 결정

### 배경
새 기능 개발 시 DB 스키마를 먼저 설계하고 Migration SQL을 만드는 과정이 수동이어서 패턴 불일치 발생 위험이 있었음.

### 추가된 기능
- `/design-db <도메인 설명>` — MySQL 스키마 설계 → ERD 검토 → Migration SQL 자동 생성
- `db-patterns.md` — MySQL 타입 선택, 공통 컬럼, 인덱스, Flyway/golang-migrate 규칙 레퍼런스

### 설계 원칙
- **설계 → 코드 순서 강제**: `/design-db` 완료 후 `/new-api` 실행 유도
- **스택별 분기**: Kotlin은 Flyway(`V{N}__*.sql`), Go는 golang-migrate(`{000000}_*.up/down.sql`)
- **nextjs/flutter 제외**: DB migration 커맨드는 백엔드 스택에서만 유지

### 워크플로
```
/design-db → Migration SQL 생성 → /new-api → Entity/Repository 코드 생성
```

**관련 파일:** `.claude/commands/design-db.md`, `.claude/skills/db-patterns.md`

---

## 2026-04-15: v1.5.0 — REST API 설계 자동화 추가

**카테고리:** 결정

### 추가된 파일
- `api-designer` agent: REST API 설계 전문 에이전트 (OpenAPI 3.0 YAML 초안, BearerAuth/Pagination/Error 패턴)
- `api-design-patterns.md` skill: URL 구조·응답 형식·RFC 7807 에러·인증·스택별 어노테이션 패턴 레퍼런스
- `/design-api` command: 5단계 인터랙티브 설계 → `/new-api`(Kotlin) / `/new-go-api`(Go) 연결
- `/review-api` command: REST 컨벤션·보안·OpenAPI 문서 완성도 리뷰 (심각도 3단계)

### 설계 원칙
- **백엔드 전용**: `/init nextjs`, `/init flutter` 시 자동 제거 대상
- **플로우 연결**: `/design-api` → 설계 확인 → `/new-api` or `/new-go-api` 구현으로 이어짐
- **`/commit` 문서 자동화**: feat/fix 커밋 시 CHANGELOG·README·memory 자동 업데이트 단계 추가

### 충돌 해결 기록
`feature/api-design-settings` 브랜치가 `feature/db-design`(PR#2) merge 후 `dev`와 충돌.
`init.md`의 스택별 유지/제거 목록이 양쪽에서 수정됨 → rebase 후 두 변경사항 병합으로 해결.

**관련 파일:** `.claude/agents/api-designer.md`, `.claude/commands/design-api.md`, `.claude/commands/review-api.md`, `.claude/skills/api-design-patterns.md`, `.claude/commands/commit.md`

---

## 2026-04-15: Git 브랜치 네이밍 — dev/* 충돌 교훈

**카테고리:** 교훈

### 문제
`dev` 브랜치(통합)와 `dev/feature-*` 브랜치(피처)를 동시에 운용하려 했으나 Git이 거부.

### 원인
Git refs는 파일시스템 경로처럼 동작함. `refs/heads/dev`(파일)와 `refs/heads/dev/feature-login`(디렉토리)은 같은 경로에 공존 불가.
`fatal: cannot lock ref 'refs/heads/dev/feature-db-design': 'refs/heads/dev' exists`

### 해결
피처 브랜치 prefix를 `dev/` 에서 타입별 독립 prefix로 변경:
- `feature/{name}` · `fix/{name}` · `hotfix/{name}` · `refactor/{name}` · `chore/{name}`

통합 브랜치(`dev`)는 그대로 유지.

### 수정된 파일
- `new-feature.md` — 브랜치 생성 명령 및 예시 수정
- `CLAUDE.*.md` 7개 — 브랜치 전략 테이블 수정
- `README.md` — 브랜치 전략 다이어그램 수정

**관련 파일:** `.claude/commands/new-feature.md`, `.claude/templates/CLAUDE.*.md`

---

## 2026-04-15: v1.3.0 — 멀티 모듈 지원 추가

**카테고리:** 결정

### 배경
단일 모듈 구조(패키지 기반 레이어)만 지원하던 것에서 물리적 경계가 있는 멀티 모듈 구조 추가.
Kotlin Gradle 멀티 모듈 / Next.js Turborepo / Go Workspace 3가지 variant 도입.

### 설계 원칙
- **에이전트 신규 생성 없음** — CLAUDE.md 템플릿이 구조를 설명하면 기존 generator/modifier/tester가 자동으로 해당 구조를 따름
- **하위 호환** — 기존 단일 모듈 `/init kotlin|nextjs|go|flutter` 동작 변경 없음
- **자동 감지** — `go.work` / `turbo.json` / `settings.gradle.kts` include 여부로 단일/멀티 모듈 자동 분기

### 추가된 파일
- 템플릿 6개: `CLAUDE.{kotlin,nextjs,go}-multi.md`, `settings.{kotlin,nextjs,go}-multi.json`
- 커맨드 1개: `/new-module` (서브모듈/패키지/서비스 추가)
- 커맨드 수정 2개: `/init`, `/new-api` (멀티 모듈 분기 추가)
- Skills 수정 3개: 각 스택 patterns 파일에 멀티 모듈 패턴 섹션 추가

### 각 스택 멀티 모듈 구조
- **Kotlin**: `:api`(presentation) → `:domain`(entity+service) ← `:infra`(repository)
- **Next.js**: `apps/web` + `packages/{ui,lib,config}` (Turborepo)
- **Go**: `services/{api,worker}` + `pkg/shared` (go.work)

**관련 파일:** `.claude/templates/CLAUDE.*-multi.md`, `.claude/commands/new-module.md`

---

## 2026-04-14: 프로젝트 초기 구성

**카테고리:** 결정

이 레포는 Claude Code를 새 프로젝트에 빠르게 세팅하기 위한 스타터입니다.
Kotlin Spring Boot, Next.js, Flutter 세 스택을 지원하며 `/init <stack>` 한 번으로 불필요한 파일을 제거하고 CLAUDE.md + settings.json을 설치합니다.

**핵심 설계 원칙:**
- 스택별 전문 subagent 분리 (generator / modifier / tester)
- `/improve`로 AI 실수를 CLAUDE.md 규칙에 누적 → 피드백 루프
- `memory/MEMORY.md`로 팀 지식 축적 → Second Brain

**관련 파일:** `.claude/commands/init.md`, `.claude/templates/`

---

## 2026-04-14: Second Brain 시스템 도입

**카테고리:** 결정

`memory/MEMORY.md`를 Second Brain으로 사용하기로 결정.

**개인 메모리 vs 팀 메모리 구분:**
- 개인 메모리: `~/.claude/projects/<project>/memory/` — 세션 간 AI 자동 학습 내용
- 팀 메모리: `memory/MEMORY.md` (이 파일) — git으로 공유되는 팀 지식

**`/memory` 커맨드**로 조회·추가·검색 가능.
파생 프로젝트는 `/init` 실행 시 `memory/MEMORY.md` 템플릿이 자동 생성됨.

---

## 2026-04-14: /init 스택 자동 감지 및 신규/기존 분기 추가

**카테고리:** 결정

`/init` 인수 생략 시 프로젝트 파일로 스택 자동 감지:
- `build.gradle.kts` / `pom.xml` → kotlin
- `package.json` (next 의존성) → nextjs
- `pubspec.yaml` → flutter

신규 프로젝트(빈 디렉토리)와 기존 프로젝트(코드 있음) 분기 처리:
- 기존 프로젝트는 CLAUDE.md 덮어쓰기 전 병합 여부 확인

**관련 파일:** `.claude/commands/init.md`

---

## 2026-04-14: /init 시 memory 인터뷰 자동 기록

**카테고리:** 결정

`/init`은 새 프로젝트 시작이므로 기존 memory 유무와 관계없이 항상 초기화.
초기화 후 4가지 질문 (목적, 핵심 기능, 제약사항, 외부 연동) → 자동 기록.

**이유:** 프로젝트 초기 컨텍스트가 이후 세션에서도 유지되도록.

---

## 2026-04-14: settings.json 템플릿 permissions.allow 추가

**카테고리:** 결정

기존 템플릿은 `permissions.allow`가 비어 있어 모든 Bash 명령마다 승인 요청 발생.
스택별 허용 명령어를 명시적으로 등록.

- Kotlin: `./gradlew`, `./mvnw`, `docker`, `docker-compose`, `git` + 파일 조작
- Next.js: `npm`, `npx`, `node`, `git` + 파일 조작
- Flutter: `flutter`, `dart`, `git` + 파일 조작

**관련 파일:** `.claude/templates/settings.{kotlin,nextjs,flutter}.json`

---

## 2026-04-14: Pre-push 커버리지 게이트 도입

**카테고리:** 결정

`git push` 전 라인 커버리지 90% 이상 강제.
`.claude/hooks/pre-push.sh`가 settings.json PreToolUse/Bash 훅으로 실행됨.

- Kotlin → `./gradlew test jacocoTestReport` → `build/reports/jacoco/test/jacocoTestReport.xml`
- Next.js → `npx jest --coverage --coverageReporters=json-summary` → `coverage/coverage-summary.json`
- Flutter → `flutter test --coverage` → `coverage/lcov.info`

**⚠️ 교훈:** Kotlin에서 Jacoco가 `build.gradle.kts`에 설정되지 않으면 게이트 자체가 실패함.
필수 설정:
```kotlin
plugins { jacoco }
tasks.jacocoTestReport { dependsOn(tasks.test); reports { xml.required = true } }
tasks.test { finalizedBy(tasks.jacocoTestReport) }
```

**관련 파일:** `.claude/hooks/pre-push.sh`, `.claude/templates/settings.*.json`, `CLAUDE.*.md`

---

## 2026-04-14: 스택별 플러그인 선정

**카테고리:** 결정

`anthropics/claude-plugins-official` 전체 목록 직접 조회 후 선정.

**공통 (전 스택):** `github`, `context7`, `feature-dev`, `code-review`, `pr-review-toolkit`, `security-guidance`, `hookify`, `commit-commands`, `claude-md-management`

**Kotlin 추가:** `kotlin-lsp`
**Next.js 추가:** `typescript-lsp`, `frontend-design`, `playwright`
**Flutter:** 공통만 (공식 Dart/Flutter LSP 없음)

**제외 판단:**
- `jdtls-lsp`: Java 전용, Kotlin 미지원 확인
- `superpowers`, `atomic-agents`: 공식 레포에 없는 구 플러그인 (이전 템플릿 잔재)
- `greptile`: 외부 유료 서비스 의존

**관련 파일:** `.claude/templates/settings.{kotlin,nextjs,flutter}.json`

---

## 2026-04-14: ui-designer agent 추가

**카테고리:** 결정

DESIGN.md 기반 디자인 시스템 에이전트. awesome-design-md(VoltAgent) 66개 브랜드 참조 가능.

**Flutter 포함 결정 근거:**
- 컬러·타이포·스페이싱·엘리베이션 토큰 → Flutter ThemeData 변환 가능 ✅
- CSS/Tailwind 컴포넌트 스펙 → Flutter 직접 적용 불가 ❌
- 결론: 포함하되 디자인 토큰 추출 전담으로 제한. CSS 스펙 자동 무시.

**Kotlin:** 백엔드 전용이면 불필요. 풀스택이면 유지.

**생성 파일 (Flutter 모드):** `lib/core/theme/app_theme.dart`, `app_colors.dart`, `app_text_styles.dart`, `app_spacing.dart`, `app_radius.dart`

**관련 파일:** `.claude/agents/ui-designer.md`

---

## 2026-04-14: GitHub 레포 이름 변경

**카테고리:** 참고

- **구 URL:** https://github.com/nogamsung/claude
- **현재 URL:** https://github.com/nogamsung/claude-code-starter
- **bootstrap.sh 및 README URL 수정 완료**

git push 시 "This repository moved" 경고가 발생했으나 리다이렉트로 push는 성공.
이후 `git remote set-url origin https://github.com/nogamsung/claude-code-starter.git` 실행.

---

## 2026-04-14: v1.2.0 — 대규모 기능 추가

**카테고리:** 결정

### Git Worktree 병렬 작업 전략
- 모든 파생 프로젝트에 `.worktrees/feature-{n}` 구조 강제
- `superpowers:using-git-worktrees` 스킬 원칙 적용:
  - `.worktrees/` gitignore 미등록 시 즉시 추가·커밋 (안전 검증 필수)
  - worktree 생성 후 스택별 의존성 자동 설치
- `/new-feature` 커맨드를 worktree 기반으로 전면 개편

### 브랜치 전략
- `main ← dev ← dev/feature-{number}` 3단계 구조
- `main` / `dev` 모두 PR + CI 통과 보호
- `/init` 실행 시 `dev` 브랜치 자동 생성

### Docker → GitHub Container Registry 배포
- Kotlin/Go/Next.js 스택별 멀티스테이지 Dockerfile 패턴 확립
- Flutter는 Docker 배포 미지원으로 명시 제외
- `publish.yml`: semver 태그 자동 생성 + 멀티플랫폼(`linux/amd64,linux/arm64`)

### Swagger 필수화
- Kotlin: SpringDoc OpenAPI — Controller에 `@Tag/@Operation/@ApiResponse`, DTO에 `@Schema` 필수
- Go: swaggo/swag — Handler에 godoc 주석 필수, DTO에 `example` 태그 필수

### 쿼리 레이어 표준화
- Kotlin: JPA + QueryDSL (동적 쿼리) + jOOQ (복잡 집계, 선택)
- Go: GORM (단순 CRUD) + sqlc (동적/페이징) + golangci-lint 필수

**관련 파일:** 대부분의 `.claude/**/*.md`, `CHANGELOG.md`, `VERSION`

---

## 2026-04-14: bootstrap.sh 도입

**카테고리:** 결정

새 프로젝트에서 `.claude` 폴더를 curl 한 줄로 설치:
```bash
curl -fsSL https://raw.githubusercontent.com/nogamsung/claude-code-starter/main/bootstrap.sh | bash
```

sparse checkout으로 `.claude` 폴더만 가져오는 방식 채택 (전체 클론 대비 빠름).

**관련 파일:** `bootstrap.sh`
