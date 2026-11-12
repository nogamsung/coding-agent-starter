# [프로젝트명] — Next.js Turborepo (멀티 패키지)

## Stack
Next.js 14+ · TypeScript strict · **Turborepo** (`turbo.json` + npm/pnpm workspaces) · Tailwind + shadcn/ui · TanStack Query v5 · Zustand · RHF + Zod · Axios (`packages/lib/src/api/`)

## Agents & Commands
`nextjs-generator` / `nextjs-modifier` / `nextjs-tester` / `ui-designer` / `code-reviewer`. `/new module <name>` 로 패키지 추가. 공통 커맨드는 단일 모듈과 동일.

## Turborepo 구조
```
turbo.json · package.json (workspaces)
apps/
  web/                   # 메인 Next.js — src/{app,components/{ui,features},hooks,lib,stores,types}/
packages/
  ui/                    # 공유 shadcn/ui 컴포넌트
  lib/                   # 공유 types, utils, api-client
  config/                # eslint, tailwind, tsconfig
```

## 패키지 의존 규칙
| 패키지 | 의존 가능 | 의존 불가 |
|--------|----------|----------|
| `packages/config` | (없음) | apps/*, 다른 packages |
| `packages/lib` | `packages/config` | apps/*, `packages/ui` |
| `packages/ui` | `packages/config`, `packages/lib` | apps/* |
| `apps/web` | 모든 packages | 다른 apps |

## 공통 규칙
**레이어별 세부 규칙은 `AGENTS.nextjs.md` 와 동일** — MUST/NEVER 섹션 그대로 적용.

## 멀티 패키지 추가 규칙
- 공유 컴포넌트·타입·유틸은 `packages/*` 에만 — 앱 간 중복 금지
- `apps/` 간 직접 import 금지
- `packages/` 에 특정 앱 전용 코드 추가 금지
- 공유 패키지는 `@project/{name}` 경로로 import

## 명령어
```bash
turbo run dev / build / test / lint
turbo run test --filter=web             # apps/web
turbo run test --filter=@project/ui     # ui 패키지
turbo run test --filter=web...          # web + 의존 패키지
```

**상세 패턴**: `.agents/skills/nextjs-patterns/SKILL.md`.

**커버리지 게이트**: git push 전 Jest 라인 커버리지 ≥90% (`.claude/hooks/pre-push.sh`). 각 패키지 `jest.config.ts` 에 `coverageThreshold.global.lines: 90` + `coverageReporters: ['json-summary', 'text', 'lcov']`.

## 학습된 규칙
<!-- /rule 로 여기에 추가됩니다 -->

## Memory
세션 시작 시 `memory/MEMORY.md` 자동 로드.

> **AGENTS.md ≤ 300줄 캡** — 초과 시 상세는 `.agents/skills/` 또는 `docs/` 로 이관, 본문은 인덱스 한 줄로.
