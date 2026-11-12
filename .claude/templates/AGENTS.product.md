# [프로젝트명] — Product Management

## Mode
**코드 스택 없는 Product Management 전담 프로젝트.** Discovery / Strategy / 실행 (PRD/OKR/Roadmap) / GTM / 리서치 / 분석 등 PM 산출물만 관리. 엔지니어링 구현은 별도 저장소.

기반 프레임워크: **Teresa Torres** (Continuous Discovery), **Marty Cagan** (Inspired/Empowered), **Alberto Savoia** (The Right It).

## Agents & Commands
| 목적 | Agent / Command |
|------|----------------|
| 신규 기능 시작 | `/start <기능>` |
| 설계만 / 추가 PRD | `/plan <기능>` |
| GTM 전략 (마케팅+세일즈) | `/plan <기능> --gtm` · `gtm-planner` |
| 마케팅 작업 라우팅 | `/marketing [카테고리]` |
| 문서 리뷰 | `code-reviewer` · `/review` |
| 커밋/PR/머지 | `/commit` · `/pr` · `/merge` |
| Second Brain | `/memory [add\|search]` |
| 규칙 추가 | `/rule` |

> **PM 명령**(`/discover`, `/strategy`, `/write-prd`, `/plan-launch` 등)은 **pm-skills 마켓플레이스 8개 플러그인**이 제공. Claude Code 가 plugin command 를 자동 인식하므로 여기 다시 나열하지 않음. 설치는 README 참고.

## Git 전략
`main` / `dev` / `{feature|fix|chore|docs}/{name}`. Worktree `.worktrees/{type}-{name}/`. `main` 직접 push 금지, PR 필수. 모든 PM 산출물은 PR 리뷰 후 병합.

## 디렉토리 구조
```
docs/
├── discovery/        # 인터뷰·가설·실험 (pm-product-discovery)
├── strategy/         # 비전·포지셔닝·BM (pm-product-strategy)
├── prd/              # PRD (pm-execution:write-prd)
├── stories/          # User stories
├── okrs/             # OKR — {quarter}.md
├── roadmap/          # 로드맵
├── launch/           # GTM + 배틀카드 (pm-go-to-market)
├── research/         # 유저·경쟁 리서치 (pm-market-research)
├── analytics/        # 코호트·A/B·쿼리 (pm-data-analytics)
├── specs/{feature}/  # 살아있는 marketing.md / sales.md
└── gtm/              # 릴리스 스냅샷 (/merge 가 freeze)

memory/MEMORY.md      # 결정·학습·리서치 인사이트
```

## MUST
- **모든 산출물 `docs/` 하위** — 루트에 문서 흩뿌리기 금지
- **PM 프레임워크 기반 의사결정** — Teresa Torres Opportunity Solution Tree, Alberto Savoia Pretotyping 등
- **가설·증거 명시** — discovery 산출물은 "가정 → 증거 → 결론" 구조
- **PRD 는 `/write-prd` 스킬로만** — 임의 포맷 금지, 팀 일관성
- **OKR 은 분기별 파일** — `docs/okrs/2026-Q2.md` 식 명명
- **인터뷰 녹취록 익명화** — Persona1, UserA 식 (실명·이메일·회사명 금지)
- **중요한 결정·학습은 `/memory add`** — 다음 iteration 재활용

## NEVER
- **코드 작성 금지** — 이 프로젝트는 PM 전담 (구현은 별도 저장소)
- **실제 유저 PII 커밋 금지** — 인터뷰 로그 익명화 필수
- **경쟁사 내부 정보 무단 기록 금지** — 공개 자료 기반만
- **전략 문서 덮어쓰기 금지** — 변경 시 새 파일 (`vision.md` → `vision-2026.md`)
- **"그냥 감" 의사결정 금지** — 최소 하나의 프레임워크 인용 (RICE, ICE, JTBD, MoSCoW 등)
- **`docs/gtm/` 스냅샷 직접 수정** — `/merge` 를 통해서만 갱신

## 명령어
```bash
git status / log / diff
gh pr list / view / create
```

## 학습된 규칙
<!-- /rule 로 여기에 추가됩니다 -->

## Memory
세션 시작 시 `memory/MEMORY.md` 자동 로드. 리서치 인사이트·실패한 가설·전략 피벗·경쟁 동향은 `/memory add` 로 기록.

> **AGENTS.md ≤ 300줄 캡** — 초과 시 상세는 `.agents/skills/` 또는 `docs/` 로 이관, 본문은 인덱스 한 줄로.
