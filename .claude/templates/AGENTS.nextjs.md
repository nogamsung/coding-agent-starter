# [프로젝트명] — Next.js

## Stack
Next.js 14+ (App Router) · TypeScript strict · Tailwind + shadcn/ui · TanStack Query v5 · Zustand · React Hook Form + Zod · Axios (`lib/api-client.ts`)

## Agents & Commands
| 목적 | Agent / Command |
|------|----------------|
| 새 파일 생성 | `nextjs-generator` |
| 기존 코드 수정 | `nextjs-modifier` |
| 테스트 작성 | `nextjs-tester` |
| 디자인 시스템 | `ui-designer` |
| 코드 리뷰 | `code-reviewer` · `/review` |
| 컴포넌트 생성 | `/new <Name> [--page\|--feature\|--ui]` |
| 커밋/PR/머지 | `/commit` · `/pr` · `/merge` |
| 신규 기능 시작 | `/start <기능>` (worktree + PRD + 자동 구현) |
| 설계만 / 추가 PRD | `/plan <기능>` |
| Second Brain | `/memory [add\|search]` |

## Git 전략
`main` / `dev` / `{feature|fix|hotfix|refactor|chore}/{name}`. Worktree `.worktrees/{type}-{name}/` (독립 `node_modules`, `npm ci` 자동). `main` 직접 push 금지.

## 디렉토리 구조
```
src/
├── app/              # App Router — 라우팅만
├── components/{ui,features}/
├── hooks/
├── lib/              # API 클라이언트, 유틸
├── stores/           # Zustand
└── types/
```

## Server vs Client
- **Server (기본)**: 데이터 fetch, async/await, 민감 API 키
- **Client** (`"use client"`): hooks, 이벤트 핸들러, 브라우저 API

## MUST
- **Named export** 만 — `default` 는 라우팅 `page.tsx` 제외 금지
- **TypeScript**: 명시적 타입, `any` 금지 (`unknown` + narrowing)
- **데이터 페칭**: TanStack Query — `useEffect + fetch` 금지
- **폼**: React Hook Form + Zod — 수동 state+validation 금지
- **스타일**: Tailwind — 인라인 `style={...}` 금지
- **이미지**: `next/image` 필수
- **라우트**: `loading.tsx`, `error.tsx` 필수
- **목록 key**: 고유 id — `index` 금지
- **접근성**: 인터랙티브 요소에 `aria-label` 또는 visible text, `<img alt>`, `<button>` vs `<a>` 시맨틱

## NEVER
- `any` 타입
- Server Component 에서 `useState`
- `useEffect` 안에서 직접 fetching
- `NEXT_PUBLIC_` 아닌 env 를 클라이언트에서 참조
- API Route 없이 클라이언트에서 DB 직접 접근
- 프로덕션에 `console.log`
- 컴포넌트 파일 안에 비즈니스 로직 (hooks 로 분리)
- 테스트 없이 컴포넌트/훅 추가

## 명령어
```bash
npm run dev / build / lint / test
npx tsc --noEmit
npx jest --coverage
```

**상세 패턴**: `.agents/skills/nextjs-patterns/SKILL.md` · 디자인 토큰: `.agents/skills/ui-design-impl/SKILL.md`.

**커버리지 게이트**: git push 전 Jest 라인 커버리지 ≥90% (`.claude/hooks/pre-push.sh`). `jest.config.ts` 에 `coverageThreshold.global.lines: 90` + `coverageReporters: ['json-summary', 'text', 'lcov']`.

## 학습된 규칙
<!-- /rule 로 여기에 추가됩니다 -->

## Memory
세션 시작 시 `memory/MEMORY.md` 자동 로드. `/plan`, `/rule`, 버그 해결, 라이브러리 도입, 아키텍처·성능 변경 → 자동 기록.

> **AGENTS.md ≤ 300줄 캡** — 초과 시 상세는 `.agents/skills/` 또는 `docs/` 로 이관, 본문은 인덱스 한 줄로.
