# .codex/ — Codex용 프로젝트 설정

Claude Code 쪽 `.claude/`와 같은 규칙과 훅을 씁니다. 손으로 고치는 파일과 생성되는 파일이 따로 있습니다.

| 파일 | 역할 | 편집 |
|---|---|---|
| `config.toml` | 샌드박스와 MCP 같은 프로젝트 설정 | 직접 편집 |
| `hooks.json` | `.claude/hooks/*.sh` 연결. 파일 편집은 `codex-adapter.sh`가 `apply_patch`를 Claude 형식으로 바꿔 넘김 | 직접 편집 |
| `rules/*.rules` | 명령 허용·확인·차단 규칙(execpolicy). Claude 쪽 짝은 `settings.json`의 `permissions` | 직접 편집. 확인: `codex execpolicy check -r .codex/rules/default.rules -- git push --force` |
| `agents/*.toml` | 서브에이전트. **생성물**이며 원본은 `.claude/agents/*.md` | `python3 .claude/scripts/gen-codex-agents.py`로 다시 생성 |

- 지침은 루트 `AGENTS.md`, skill은 `.agents/skills/`에 있고 Claude와 같이 씁니다.
- `agents/<role>-routed.toml`은 모델과 강도를 고정하지 않은 변형입니다. 모델을 직접 지정하거나 모델 라우터(`.claude/stacks.json` `harness.modelRouter`, 기본 off)를 쓸 때만 사용됩니다.
- 에이전트 모델 별칭은 Codex 계열로 옮겨 적습니다: `fable`→astra, `opus`→sol, `sonnet`→terra, `haiku`→luna. 버전은 생성할 때 `~/.codex/models_cache.json`에서 그 계열의 최신 버전을 고릅니다. 고정하려면 `CODEX_MODEL_<FAMILY>`를 지정합니다.
- `.claude/agents`를 고쳤으면 생성기를 다시 돌리고 `.codex/agents`도 함께 커밋합니다. pre-commit 훅과 CI가 `--check --index`로 어긋남을 막습니다.
