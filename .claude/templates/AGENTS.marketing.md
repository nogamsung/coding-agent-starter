# [프로젝트명] — Marketing

## Mode
**코드 스택 없는 마케팅 전담 프로젝트.** 랜딩페이지 카피, SEO, 런치 전략, 콘텐츠, 광고, 이메일 시퀀스, 리텐션 등 마케팅 산출물만 관리합니다. 엔지니어링 구현은 별도 저장소에서 진행.

## Agents & Commands
| 목적 | Agent / Command |
|------|----------------|
| 기획 → PRD + 마케팅 전략 | `/plan <기능> --marketing` |
| 마케팅 작업 라우팅 | `/marketing [카테고리] [작업]` |
| GTM 문서 전담 agent | `gtm-planner` |
| 문서 리뷰 | `code-reviewer` · `/review` |
| 커밋/PR/머지 | `/commit` · `/pr` · `/merge` |
| Second Brain | `/memory [add\|search]` |
| 규칙 추가 | `/rule` |

## 필수 플러그인
`marketing-skills@marketingskills` — 없으면 `/marketing` · `/plan --marketing` · `gtm-planner` 가 동작하지 않습니다. 미설치 상태면 설치:
```
/plugin install marketing-skills@marketingskills
```

## Git 전략
`main` / `dev` / `{feature|fix|chore|docs}/{name}`. Worktree `.worktrees/{type}-{name}/`. `main` 직접 push 금지, PR 필수.

## 디렉토리 구조
```
docs/
├── specs/              # PRD + 기능별 marketing.md (살아있는 문서)
│   └── {feature}/
│       └── marketing.md
└── gtm/                # 릴리스 스냅샷 (날짜 기반)
    ├── history.md
    └── {YYYY-MM-DD}-{feature}/
        ├── marketing.md
        └── meta.yaml

assets/                 # 이미지, 스크린샷, 로고, 프레스 키트
campaigns/              # 캠페인별 산출물 (선택)
memory/
└── MEMORY.md           # Second Brain — 결정/학습/레퍼런스
```

## 작업 흐름
1. `/plan <기능> --marketing` — PRD + `docs/specs/{feature}/marketing.md` 생성
2. `/marketing copywriting` — 랜딩페이지 · 헤드라인 · CTA 초안
3. `/marketing seo-audit` — SEO 진단
4. `/marketing launch-strategy` — 런치 체크리스트
5. `/merge` — 릴리스 시 `docs/gtm/{날짜}-{feature}/` 에 스냅샷 자동 freeze

## MUST
- **모든 산출물은 `docs/` 또는 `assets/` · `campaigns/` 하위**
- **살아있는 문서는 `docs/specs/{feature}/marketing.md` 에서만 편집** — `docs/gtm/` 스냅샷은 읽기 전용 (`/merge` 가 관리)
- **재기획은 새 날짜 디렉토리로** — 기존 스냅샷 덮어쓰기 금지
- **중요한 의사결정 · 캠페인 결과는 `/memory add`** 로 기록
- **포지셔닝 · 타겟 · 경쟁 분석이 반복되면 `.agents/product-marketing-context.md` 생성** (`/marketing` → product-marketing-context)

## NEVER
- **코드 작성 금지** (`.ts`, `.tsx`, `.kt`, `.go`, `.dart`, `.sql` 등) — 이 프로젝트는 마케팅 전담
- `docs/gtm/` 스냅샷 직접 수정 — `/merge` 를 통해서만 갱신
- 기존 `history.md` 의 릴리스 행 편집 (재기획은 새 행 추가)
- 캠페인 결과 · 벤치마크를 기억에 남기지 않은 채 다음 캠페인으로 이동

## 명령어
```bash
git status / log / diff
gh pr list / view / create
```

## 학습된 규칙
<!-- /rule 로 여기에 추가됩니다 -->

## Memory
세션 시작 시 `memory/MEMORY.md` 자동 로드. 캠페인 성과 · 포지셔닝 변경 · 주요 인사이트는 `/memory add` 로 기록.

> **AGENTS.md ≤ 300줄 캡** — 초과 시 상세는 `.agents/skills/` 또는 `docs/` 로 이관, 본문은 인덱스 한 줄로.
