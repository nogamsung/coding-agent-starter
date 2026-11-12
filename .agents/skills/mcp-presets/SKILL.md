---
name: mcp-presets
description: 스택별 권장 MCP 서버 구성 — settings.json 의 mcpServers 에 직접 복사. 자동 활성화 X (사용자 명시 선택).
---

# MCP Server Presets

Claude Code 의 `mcpServers` 는 `.claude/settings.json` 또는 `.claude/settings.local.json` 의 `mcpServers` 키에 추가하면 활성화됩니다. 이 문서는 **스택별 권장 구성**을 JSON snippet 으로 제공합니다.

## 정책

- **자동 활성화 안 함** — 사용자가 직접 settings 에 추가해야 활성. 잘못된 MCP 구성이 세션을 깰 수 있어 안전 디폴트.
- **개인 설정은 `settings.local.json` 권장** — 팀에 공유할 필요 없는 토큰·credential 이 들어가는 경우.
- **팀 공유 MCP 는 `settings.json`** — 모두 같은 DB / GitHub repo 를 보는 경우만.

## 환경변수 컨벤션

각 MCP 서버는 secret 이 필요한 경우 환경변수로 주입. shell rc (`.zshrc`) 또는 `.envrc` (direnv) 에 export.

| 환경변수 | 용도 |
|----------|------|
| `DATABASE_URL` | postgres MCP |
| `GITHUB_PERSONAL_ACCESS_TOKEN` | github MCP (repo / read:org scope) |
| `SLACK_BOT_TOKEN` | slack MCP (bot 토큰) |

---

## 스택별 권장 프리셋

### Kotlin Spring Boot / Go Gin / Python FastAPI (백엔드)

```json
{
  "mcpServers": {
    "postgres": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-postgres", "${DATABASE_URL}"]
    },
    "filesystem": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-filesystem", "${PWD}"]
    },
    "github": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-github"],
      "env": { "GITHUB_PERSONAL_ACCESS_TOKEN": "${GITHUB_PERSONAL_ACCESS_TOKEN}" }
    }
  }
}
```

- `postgres` — 마이그레이션·스키마 검토·쿼리 디버깅 (claude 가 직접 SELECT 가능)
- `filesystem` — 프로젝트 외부 파일 접근 필요 시 (대시보드 export 등)
- `github` — Issue/PR 코멘트 자동화, repo 검색

### Next.js (프론트엔드)

```json
{
  "mcpServers": {
    "filesystem": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-filesystem", "${PWD}"]
    },
    "github": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-github"],
      "env": { "GITHUB_PERSONAL_ACCESS_TOKEN": "${GITHUB_PERSONAL_ACCESS_TOKEN}" }
    },
    "puppeteer": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-puppeteer"]
    }
  }
}
```

- `puppeteer` — 빌드된 페이지 시각 검증 (스크린샷, console error 캡처)
- DB 가 직접 필요하면 위 백엔드 프리셋의 `postgres` 추가

### Flutter (모바일)

```json
{
  "mcpServers": {
    "filesystem": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-filesystem", "${PWD}"]
    },
    "github": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-github"],
      "env": { "GITHUB_PERSONAL_ACCESS_TOKEN": "${GITHUB_PERSONAL_ACCESS_TOKEN}" }
    }
  }
}
```

- 모바일 백엔드는 보통 별도 repo — DB MCP 는 백엔드 repo 에서만.

### Marketing / Sales / Product (코드 없음)

```json
{
  "mcpServers": {
    "filesystem": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-filesystem", "${PWD}"]
    },
    "fetch": {
      "command": "uvx",
      "args": ["mcp-server-fetch"]
    }
  }
}
```

- `fetch` — 경쟁사 사이트 스크랩, 공개 API 호출 (SEO/카피 작업에 유용)
- `slack`, `notion`, `linear` 등 워크플로 MCP 추가 권장 (개인 토큰 → `settings.local.json`)

---

## 적용 방법

### 1. 개인 사용 (`settings.local.json` — gitignore)

```bash
# 위 snippet 을 settings.local.json 에 복사
```

이 파일은 팀 공유 안 됨. credential 안전.

### 2. 팀 공유 (`settings.json`)

같은 DB / GitHub repo 를 모두가 보는 경우. 단, `${DATABASE_URL}` 같은 환경변수 placeholder 만 두고, 실제 값은 각자 shell 에서 export.

### 3. 검증

```bash
# Claude Code 재시작 후
/mcp     # 활성 MCP 서버 목록 확인
```

각 MCP 서버 상태가 ✅ 면 정상. ❌ 또는 시작 실패면 설치 누락 (`npx -y` 가 처음 호출 시 자동 설치하므로 인터넷 + npm 필요).

---

## 잘 알려진 함정

- **`${PWD}` 는 Claude Code 시작 시점의 cwd 로 고정** — 세션 중 다른 디렉토리로 이동해도 filesystem MCP 는 처음 cwd 만 봄.
- **`postgres` MCP 는 read-only 가 아님** — `claude` 가 잘못된 UPDATE/DELETE 를 칠 수 있음. 운영 DB 에 절대 직접 연결 금지. 로컬 dev DB 만.
- **`github` MCP 의 PAT 권한 최소화** — `repo` (read 만) + `read:org`. write 권한이 필요한 작업은 `gh` CLI 권장.
- **`npx -y` 캐시** — 첫 호출 후 `~/.npm/_npx/` 에 캐시. 버전 고정하려면 `@latest` 대신 명시 버전.
