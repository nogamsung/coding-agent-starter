# [프로젝트명] — Sales

## Mode
**코드 스택 없는 세일즈 전담 프로젝트.** 세일즈 덱, 콜드 이메일, 객관 처리, 데모 스크립트, 경쟁 비교, 가격 전략, 플레이북, 리비뉴 오퍼레이션 산출물만 관리합니다. 엔지니어링 구현은 별도 저장소에서 진행.

## Agents & Commands
| 목적 | Agent / Command |
|------|----------------|
| 기획 → PRD + 세일즈 전략 | `/plan <기능> --sales` |
| 세일즈 작업 라우팅 | `/marketing sales-enablement` · `/marketing cold-email` · `/marketing pricing-strategy` |
| GTM 문서 전담 agent | `gtm-planner` |
| 문서 리뷰 | `code-reviewer` · `/review` |
| 커밋/PR/머지 | `/commit` · `/pr` · `/merge` |
| Second Brain | `/memory [add\|search]` |
| 규칙 추가 | `/rule` |

## 필수 플러그인
`marketing-skills@marketingskills` — sales-enablement · cold-email · pricing-strategy · competitor-alternatives · revops 스킬 모두 이 플러그인에 포함. 미설치 상태면:
```
/plugin install marketing-skills@marketingskills
```

## Git 전략
`main` / `dev` / `{feature|fix|chore|docs}/{name}`. Worktree `.worktrees/{type}-{name}/`. `main` 직접 push 금지, PR 필수.

## 디렉토리 구조
```
docs/
├── specs/              # PRD + 기능별 sales.md (살아있는 문서)
│   └── {feature}/
│       └── sales.md
└── gtm/                # 릴리스 스냅샷 (날짜 기반)
    ├── history.md
    └── {YYYY-MM-DD}-{feature}/
        ├── sales.md
        └── meta.yaml

playbooks/              # 세일즈 플레이북, 프로세스 문서
decks/                  # 피치 덱, 원페이저, 리브비하인드
outreach/               # 콜드 이메일 시퀀스, LinkedIn 메시지 템플릿
battlecards/            # 경쟁 비교 카드
memory/
└── MEMORY.md           # Second Brain — 객관 · 딜 인사이트 · 프로세스 결정
```

## 작업 흐름
1. `/plan <기능> --sales` — PRD + `docs/specs/{feature}/sales.md` 생성
2. `/marketing sales-enablement` — 세일즈 덱 · 객관 처리 · 데모 스크립트
3. `/marketing competitor-alternatives` — 배틀카드 · 비교 문서
4. `/marketing pricing-strategy` — 가격 플랜 · 할인 정책
5. `/marketing cold-email` — 아웃바운드 시퀀스
6. `/merge` — 릴리스 시 `docs/gtm/{날짜}-{feature}/` 에 스냅샷 자동 freeze

## MUST
- **모든 산출물은 `docs/` · `playbooks/` · `decks/` · `outreach/` · `battlecards/` 하위**
- **살아있는 문서는 `docs/specs/{feature}/sales.md` 에서만 편집** — `docs/gtm/` 스냅샷은 읽기 전용 (`/merge` 가 관리)
- **재기획은 새 날짜 디렉토리로** — 기존 스냅샷 덮어쓰기 금지
- **딜 데이터 · 객관 패턴 · 승률은 `/memory add`** 로 기록 — 다음 딜에 재활용
- **ICP · 페르소나 · 포지셔닝이 반복되면 `.agents/product-marketing-context.md` 생성** (`/marketing` → product-marketing-context)
- **가격 · NDA · 할인 정책은 별도 private 저장소** — 이 리포에는 템플릿/프로세스만

## NEVER
- **코드 작성 금지** — 이 프로젝트는 세일즈 전담
- **실제 고객 개인정보 · 계약 조건 커밋 금지** — 익명화된 사례만 `docs/` 에
- `docs/gtm/` 스냅샷 직접 수정
- 기존 `history.md` 의 릴리스 행 편집
- 객관 처리 · 경쟁 대응 패턴을 기억에 남기지 않은 채 다음 딜로 이동

## 명령어
```bash
git status / log / diff
gh pr list / view / create
```

## 학습된 규칙
<!-- /rule 로 여기에 추가됩니다 -->

## Memory
세션 시작 시 `memory/MEMORY.md` 자동 로드. 승리/패배 요인 · 객관 패턴 · 경쟁 인사이트 · 프로세스 변경은 `/memory add` 로 기록.

> **AGENTS.md ≤ 300줄 캡** — 초과 시 상세는 `.agents/skills/` 또는 `docs/` 로 이관, 본문은 인덱스 한 줄로.
