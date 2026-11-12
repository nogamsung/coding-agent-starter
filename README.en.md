<div align="center">

# Coding Agent Starter

**Set up a Claude Code · Codex harness in 10 seconds — use both, or just one**

[**🇰🇷 한국어**](README.md) · [**🇬🇧 English**](README.en.md)

<br/>

[![Claude](https://img.shields.io/badge/Claude-Code-FF6B35?logo=anthropic&logoColor=white)](https://claude.ai/code)
[![Codex](https://img.shields.io/badge/OpenAI-Codex-412991?logo=openai&logoColor=white)](https://developers.openai.com/codex)
[![Version](https://img.shields.io/badge/version-2.0.0-blue)](CHANGELOG.md)
[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)

<br/>

![Kotlin](https://img.shields.io/badge/Kotlin-Spring_Boot-7F52FF?logo=kotlin&logoColor=white)
![Next.js](https://img.shields.io/badge/Next.js-000000?logo=next.js&logoColor=white)
![Flutter](https://img.shields.io/badge/Flutter-02569B?logo=flutter&logoColor=white)
![Go](https://img.shields.io/badge/Go-Gin-00ADD8?logo=go&logoColor=white)
![Python](https://img.shields.io/badge/Python-FastAPI-009688?logo=fastapi&logoColor=white)

</div>

---

## Overview

A starter that pre-configures **skills, agents, hooks, and templates** so you can immediately use coding agents (Claude Code · Codex) in a project. (formerly `claude-code-starter`)

- **Shared by Claude Code and Codex** — one instruction file `AGENTS.md`, one skill set `.agents/skills/`, one hook set `.claude/hooks/`. Install with `--platform claude|codex|both`
- **Agent-agnostic gates** — git hooks (`.claude/githooks`) enforce build → test → coverage before push, gitleaks secret scanning and hub-checkout commit blocking from Claude, Codex, or a plain terminal. CI re-checks with the same scripts
- **Worktree-first + safety guards** — the main checkout is a hub (source edits blocked), deleting dev/main and force pushes are blocked, deleting finished work branches needs no prompt
- **Cross review** — `/pr` asks the *other* platform's model to review (Claude's work → Codex, and vice versa). `/handoff` passes work between agents

- One-shot `/init` configures the harness for the detected stack
- Specialized stack-specific subagents split generation, modification, and testing
- **Dispatcher commands** — `/new`, `/plan`, `/review` consolidate all create / plan / review workflows
- A `/rule` feedback loop accumulates rules into `AGENTS.md` whenever the AI slips, sharpening the harness over time
- `memory/MEMORY.md` is auto-loaded at session start — past decisions and lessons are always in context
- **Parallel work via Git Worktrees** — `/new worktree` lets you develop multiple features simultaneously
- **Multi-module support** — Gradle multi-module / Turborepo / Go Workspace
- **DB design automation** — `/plan db` produces MySQL schema → Flyway / golang-migrate SQL
- **API design automation** — `/plan api` produces REST API design → OpenAPI 3.0 YAML → code generation
- **Monorepo mode** — auto-detects `backend/` + `frontend/` + `mobile/` cohabitation → role-specific AGENTS.md + path guard hooks
- **`/start` single entry point** — start a new feature in one shot: worktree + PRD + role-specific prompts + auto-implementation. Single stack runs without confirmation, monorepo asks once.
- **Planner agent** — `/plan` (or `/start`) turns a request into PRD + role-specific implementation prompts. Optional Agent Teams for parallel implementation.
- **`/commit` → `/pr` → `/merge` chain** — each step proposes the next (executes upon acceptance). Not full automation but a "continuous confirmation" chain.

**Supported stacks:** Kotlin Spring Boot · Next.js · Flutter · Go Gin · Python FastAPI

> **v2.0.0 Breaking Change** — `CLAUDE.md` → `AGENTS.md`, commands → `.agents/skills/`. See the [v2 migration guide](#v2-migration-v1x--v200).

---

## Quick start

### 1. Install the harness (new or existing project)

**Option A — Bootstrap script (recommended)**

```bash
curl -fsSL https://raw.githubusercontent.com/nogamsung/coding-agent-starter/main/bootstrap.sh | bash
```

- If `.claude/` does **not exist** → install mode — fresh install
- If `.claude/` **exists** → update mode — **user custom assets are preserved by default** (v1.19.0+)

**Options (pass arguments through curl | bash):**

```bash
curl -fsSL ...bootstrap.sh | bash -s -- --platform codex      # claude | codex | both (default: auto-detect installed CLIs)
curl -fsSL ...bootstrap.sh | bash -s -- --version v2.0.0      # pin a version
curl -fsSL ...bootstrap.sh | bash -s -- --no-preserve         # replace user assets too
```

| Platform | Installs |
|----------|----------|
| common | `.agents/skills/` (skill source) · `.claude/{agents,hooks,githooks,scripts,templates}` |
| `claude` | `.claude/settings.json` · `.claude/skills → ../.agents/skills` |
| `codex` | `.codex/{config.toml,hooks.json,rules/,agents/}` (agents generated from `.claude/agents`) |

Preserved on update: `.agents/skills/<your-skill>/` (names the starter does not ship), `.claude/{agents,commands,hooks}/custom/`, `.claude/settings.local.json`, `.codex/config.toml`, your `.codex/rules/*`, `memory/`, `AGENTS.md`.

**Option B — Plugin marketplace** (Claude only, experimental)

```
/plugin marketplace add nogamsung/coding-agent-starter
/plugin install coding-agent-starter@coding-agent-starter
```

> ⚠️ **Limitation**: the plugin path installs only `commands` · `agents` · `skills`. `hooks` · `templates` · `settings.json` · `memory/` are outside the plugin system, so **`bootstrap.sh` remains the primary entry point**. Use the plugin path when you only want a subset of assets.

**Option C — Update / rollback from inside the agent** (already-installed projects; in Codex use `$starter`)

```
/starter check                      # Show current · latest · previous version
/starter update                     # Update everything (custom assets preserved)
/starter update --version v1.18.0   # Pin a specific tag
/starter rollback                   # Revert to the previous version

/upgrade                            # Show category-by-category change stats (dry-run)
/upgrade apply skills,hooks         # Selectively update some categories
/upgrade --version v1.18.0          # Compare against a specific version

/release patch                      # Bump VERSION + CHANGELOG + commit + auto /pr
/release minor --dry-run            # Preview only
```

> `/starter` does all-or-nothing updates; `/upgrade` updates partially by category (`agents` / `commands` / `skills` / `templates` / `hooks` / `settings`). Both preserve `custom/` + `settings.local.json`. `/release` is for maintainers cutting a new version of their own project (or the starter itself).

### 2. Initialize a stack (Claude Code or Codex)

```
/init                # Auto-detect
/init kotlin         # Kotlin Spring Boot (single module)
/init kotlin-multi   # Kotlin (Gradle multi-module: api/domain/infra)
/init nextjs         # Next.js (single app)
/init nextjs-multi   # Next.js (Turborepo: apps/web + packages/ui,lib,config)
/init flutter        # Flutter mobile
/init go             # Go Gin (single service)
/init go-multi       # Go (Workspace: services/api,worker + pkg/shared)
/init python         # Python FastAPI (single service)
/init python-multi   # Python (uv Workspace: services/api,worker + packages/shared)
/init infra          # DevOps / IaC mode (Terraform · Kubernetes · Helm)
/init marketing      # Code-free marketing mode (landing copy · SEO · content · ads)
/init sales          # Code-free sales mode (decks · cold email · objections · pricing)
/init product        # Code-free Product Management mode (Discovery · Strategy · PRD · OKR · GTM · Analytics)
```

> **marketing / sales** modes use the `marketing-skills@marketingskills` plugin. If not installed, run `/plugin install marketing-skills@marketingskills`.
>
> **product** mode uses 8 plugins from the `phuryn/pm-skills` marketplace (pm-toolkit, pm-product-discovery, pm-product-strategy, pm-execution, pm-go-to-market, pm-market-research, pm-data-analytics, pm-marketing-growth). If not installed, run `/plugin marketplace add phuryn/pm-skills` then each `/plugin install pm-*@pm-skills`.

<details>
<summary>What <code>/init</code> does</summary>

1. Auto-detect stack (when no argument given)
2. Remove agents/templates/skills unrelated to the chosen stack (commands stay — dispatchers branch internally)
3. Install `AGENTS.md` — architecture rules, conventions
4. Install `.claude/settings.json` — stack-specific allowed commands + auto lint/test hooks
5. Initialize `memory/MEMORY.md` — record after a project info interview
6. Create the `dev` branch + register `.worktrees/` in gitignore

</details>

### 3. Start a feature

```bash
# Recommended — single entry point (worktree + PRD + auto-implementation in one step)
/start login feature              # worktree(feature/login) + PRD + role prompts + auto generator
/start cancel payment --gtm       # + marketing/sales GTM docs

/pr                               # After work is done, create the PR (→ /merge auto-suggested)
/merge                            # GitHub merge + main sync + tag + worktree cleanup

# Or step-by-step — finer control
/new feature-login                # worktree only
/plan login feature               # PRD + role prompts only (no execution)
/plan login feature --teams       # PRD then run generators immediately
/new User                         # Single-resource scaffolding (stack auto-detected)
```

---

## Workflow

```
/start <feature description>      # 1. Start a feature in one shot: worktree + PRD + auto-impl
/commit                           # 2. Commit → on a feature branch, /pr is auto-suggested
/pr                               # 3. (Accept) Create PR → /merge auto-suggested
/merge                            # 4. (Accept) Execute merge + tag + cleanup

# When you need finer control:
/new feature-login                # worktree only
/plan <feature>                   # PRD + role prompts (no execution)
/plan <feature> --teams           # PRD then run generators
/plan <feature> --light           # Lightweight single-change plan
/plan api Order                   # API design (OpenAPI 3.0 YAML)
/plan db "..."                    # DB design (Migration SQL)
/new User                         # Single-resource scaffolding (stack auto-detected)
/test <file>                      # Auto-generate tests
/review staged                    # Standalone review
/rule <slip description>          # Register an AI slip as a AGENTS.md rule
/memory add <content>             # Manually record decisions/lessons (lookups auto-load)
```

---

## Branch strategy

```
main  ←──── dev  ←──── feature/{name}
(prod)      (integ)    fix/{name}
                       hotfix/{name}
                       refactor/{name}
                       chore/{name}
```

Each branch is created in `.worktrees/{type}-{name}/` as an isolated workspace.
Types: `feature` · `fix` · `hotfix` · `refactor` · `chore` · `docs` · `test` · `perf`
**Parallel work** across multiple terminals / Claude Code instances is supported.

> ⚠️ **Git branch naming constraint**: `dev` and `dev/feature-*` cannot coexist due to refs structure. Feature branches use independent prefixes (`feature/`, `fix/`, etc.) instead of `dev/`.

---

## Skills (formerly commands)

> v2.0.0 — commands moved to `.agents/skills/<name>/SKILL.md`. Call them as `/name` in Claude Code and `$name` in Codex. New: `/handoff`.

> v1.18.0 — `/planner` was absorbed into `/plan` and a new single entry point `/start` was added.
> v1.20.0~1.21.0 — `/upgrade` (selective diff) and `/release` (SemVer + CHANGELOG sync) added.

### Dispatchers (subcommands)

| Command | Args | Description |
|---------|------|-------------|
| `/new` | `<Name>` | **Auto-detect** — branch by stack (go/kotlin→api, nextjs→component, flutter→screen) or name pattern (`feature-*`→worktree, `ci\|release\|publish`→workflow) |
| | `<sub> <Name>` (override) | Explicit `api` / `component` / `screen` / `module` / `workflow` / `worktree` |
| | `<role> <sub> <Name>` (monorepo) | Role prefix — `backend` / `frontend` / `mobile` to target a stack path |
| `/start` | `<feature>` | **Single entry point** — worktree + PRD + role prompts + auto-implementation |
| | `<feature> --no-worktree` | When already inside a worktree |
| | `<feature> --output-only` | Generate files only, no auto-execution |
| | `<feature> --marketing\|--sales\|--gtm` | + GTM docs |
| `/plan` | `<feature>` | PRD + role-specific implementation prompts (no execution) |
| | `<feature> --teams` | PRD then run generators in parallel |
| | `<feature> --light` | Lightweight single-change plan (no PRD) |
| | `api <Resource>` | REST API design → OpenAPI 3.0 YAML |
| | `db <domain>` | MySQL schema → Migration SQL |
| | `<feature> --marketing\|--sales\|--gtm` | + GTM docs |
| | `<role> ...` (monorepo) | Role prefix — `/plan backend api User`, `/plan backend db order` |
| `/review` | (none) / `<file>` / `staged` / `diff` | General code review |
| | `api` | REST conventions · security · OpenAPI review |

### Single commands

| Command | Description |
|---------|-------------|
| `/init [stack]` | Stack detection + harness configuration |
| `/test [file]` | Auto-generate tests |
| `/commit [hint]` | Conventional Commits + auto `/pr` suggestion (feature branches) |
| `/pr` | Create PR + auto `/merge` suggestion |
| `/merge [auto]` | GitHub merge + main sync + version tag + worktree cleanup |
| `/rule <description>` | Register an AI slip as a AGENTS.md rule |
| `/memory [add\|search]` | Second Brain entry/search (full content auto-loads) |
| `/marketing [category task\|natural language]` | Marketing router — branches 35 `marketing-skills:*` skills into 6 categories |
| `/starter [check\|update\|rollback]` | Check / install / rollback the starter |
| `/upgrade [diff\|apply <cat>]` | Category-level selective update vs latest starter (or `--version`) |
| `/release [patch\|minor\|major]` | SemVer bump + CHANGELOG sync + commit + auto `/pr` |
| `/harness [check\|doctor\|dry-run\|size\|lint-settings]` | Validate / dry-run / suggest fixes for the harness (settings.json, hooks, agents) |

---

## Agents

| Agent | Role |
|-------|------|
| `code-reviewer` | Correctness · security · performance · maintainability review (all stacks) |
| `ui-designer` | DESIGN.md-based design system (Next.js: Tailwind tokens, Flutter: ThemeData) |
| `github-actions-designer` | CI/CD · release · Docker deploy workflow design |
| `kotlin-{generator\|modifier\|tester}` | Kotlin Spring Boot generation/modification/testing |
| `nextjs-{generator\|modifier\|tester}` | Next.js generation/modification/testing |
| `flutter-{generator\|modifier\|tester}` | Flutter generation/modification/testing |
| `go-{generator\|modifier\|tester}` | Go Gin generation/modification/testing |
| `python-{generator\|modifier\|tester}` | Python FastAPI generation/modification/testing |
| `ai-{researcher\|generator\|modifier\|tester}` | AI/ML — research · code · tuning · testing (Python only) |
| `infra-generator` | Terraform / Kubernetes / Helm generation (single agent — no modifier/tester split) |
| `api-designer` | REST API design (OpenAPI 3.0 YAML) — Kotlin · Go · Python only |
| `planner` | Planner — request → PRD + role-specific implementation prompts (no code). Invoked by `/start` or `/plan` |
| `gtm-planner` | Go-To-Market — drafts `marketing.md` + `sales.md` from PRD, snapshot history in `docs/gtm/`. Invoked by `/start` or `/plan --marketing\|--sales\|--gtm` |
| `security-reviewer` | OWASP Top 10 + secret leak + dependency CVE review. Auto-invoked at `/pr` Step 1.5 → blocks PR on critical findings |

---

## Stack technical standards

| Item | Kotlin Spring Boot | Go Gin | Python FastAPI | Next.js | Flutter |
|------|-------------------|--------|----------------|---------|---------|
| ORM / Query | JPA + **QueryDSL** | GORM + **sqlc** | **SQLAlchemy 2.0 (async)** | — | — |
| Migration | Flyway | golang-migrate | **Alembic** | — | — |
| API docs | **SpringDoc OpenAPI** | **swaggo/swag** | **FastAPI built-in OpenAPI** | — | — |
| Lint / Format | ktlint | **golangci-lint** | **ruff** | ESLint | dart analyze |
| Type check | kotlinc | `go vet` | **mypy (strict)** | tsc | — |
| Package manager | Gradle | Go modules | **uv** | npm | pub |
| Docker deploy | ✅ GHCR | ✅ GHCR | ✅ GHCR | ✅ GHCR | ❌ |

---

## Plugins (auto-installed by stack)

### Common (all stacks)

| Plugin | Description |
|--------|-------------|
| `github` | GitHub repo · PR · issue management |
| `context7` | Auto-inject latest official docs context |
| `feature-dev` | 7-step Explore→Design→Implement→Review |
| `code-review` | Parallel 4-agent automated PR review |
| `security-guidance` | Security warnings before risky commands |
| `hookify` | Auto-register repeat slips as preventive hooks |
| `commit-commands` | One-step commit · push · PR creation |

### Per-stack

| Plugin | Stack | Description |
|--------|-------|-------------|
| `kotlin-lsp` | Kotlin | Real-time type errors · symbol references |
| `typescript-lsp` | Next.js | TypeScript code intelligence |
| `frontend-design` | Next.js | UI patterns · accessibility guide |
| `playwright` | Next.js | E2E browser test automation |

---

## Auto hooks

One set of hook scripts in `.claude/hooks/` — Claude calls them from `settings.json`, Codex from `.codex/hooks.json`. Every hook exits silently without `.claude/stacks.json`; options live in its `harness` block.

| Hook | Event | What it does | Option (default) |
|------|-------|--------------|------------------|
| `session-start.sh` | session start | git/stack summary · pending `/handoff` note | — |
| `safety-guard.sh` | before Bash | blocks force push, dev/main deletion, `rm -rf /`, DROP; allows finished-branch deletion without prompt | always |
| `worktree-guard.sh` | before edit | blocks source edits in the main checkout (hub) | `worktreeGuard` (true) |
| `post-edit-lint.sh` | after edit | per-extension lint · AGENTS.md 300-line cap | — |
| `stop-tests.sh` | turn end (Claude) | tests changed stacks only, skips if unchanged, never blocks | `stopTests` (true) |
| `pre-push.sh` + `build-gate.sh` | git push | build → scoped tests → coverage (`coverage-gate.py`, same as CI) | `buildGate` (true) · `coverage` (90) |
| `memory-sync.sh` | session start/end | repo `memory/` as the source of truth, linked & committed | `memorySync` (off) |
| `model-router.sh` | subagent spawn | picks a model tier by task difficulty (TypeSafe key) | `modelRouter` (off) |
| `codex-adapter.sh` | Codex only | turns `apply_patch` into per-file inputs for the hooks above | — |

Git hooks: `bash .claude/scripts/setup-git-hooks.sh` (`core.hooksPath=.claude/githooks`).

---

## v2 migration (v1.x → v2.0.0)

```bash
curl -fsSL https://raw.githubusercontent.com/nogamsung/coding-agent-starter/main/bootstrap.sh | bash   # or /starter update
bash .claude/scripts/migrate-agents-md.sh --apply    # CLAUDE.md → AGENTS.md (root + role dirs)
/init                                                # writes .claude/stacks.json (v2 hooks need it)
```

| v1 | v2 |
|----|----|
| `CLAUDE.md` · `templates/CLAUDE.{stack}.md` | `AGENTS.md` · `templates/AGENTS.{stack}.md` — if a CLAUDE.md remains, Claude Code ignores AGENTS.md |
| `.claude/commands/*.md` | `.agents/skills/<name>/SKILL.md` (same names: `/commit`, `/pr`, …; `$commit` in Codex) |
| `.claude/skills/*.md` | `.agents/skills/<name>/SKILL.md` · `.claude/skills` is a symlink |
| `.claude/skills/custom/*.md` | migrated automatically on update |
| no stacks.json for single stack | `.claude/stacks.json` in every mode (+ `harness` options) |

Claude Code ≥ 2.1.277 reads AGENTS.md.

---

## Directory structure

```
coding-agent-starter/
├── AGENTS.md                      # this repo's instructions (Claude · Codex)
├── .agents/skills/<name>/SKILL.md # skill source — workflow skills + pattern skills
├── .claude/
│   ├── agents/                    # subagent source
│   ├── skills -> ../.agents/skills
│   ├── hooks/                     # shared hooks (lib.sh · guards · pre-push · build-gate · stop-tests · memory-sync · …)
│   ├── githooks/                  # pre-commit · pre-push (core.hooksPath)
│   ├── scripts/                   # init-cleanup · gen-codex-agents · coverage-gate · cross-review · setup-git-hooks · tests/
│   ├── templates/                 # AGENTS.{stack}.md · settings.{stack}.json · cicd/ · gitleaks.toml · optional-skills.json
│   └── .starter-{version,platform,skills}
├── .codex/                        # config.toml · hooks.json · rules/ · agents/*.toml (generated)
├── .github/workflows/             # auto-tag · install-matrix · harness-ci
├── memory/MEMORY.md               # this repo's Second Brain
├── bootstrap.sh                   # install/update (--platform · --version · --no-preserve)
├── CHANGELOG.md
└── VERSION
```

---

## Documentation

- **한국어 문서**: [README.md](README.md) (default)
- **English**: [README.en.md](README.en.md) (this file)
- **Changelog**: [CHANGELOG.md](CHANGELOG.md)

Translations track the Korean source. If they ever drift, the Korean README is authoritative.
