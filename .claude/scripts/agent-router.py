#!/usr/bin/env python3
""".claude/scripts/agent-router.py — Claude(Agent/Task)·Codex(spawn_agent) 공용 PreToolUse 모델 라우터.

실행 권한은 절대 주지 않는다. 기본은 꺼짐(opt-in):
  .claude/stacks.json  {"harness": {"modelRouter": "off" | "log" | "apply"}}   (env MODEL_ROUTER 가 우선)
  log   = 판단만 <git-common-dir>/agent-model-router.jsonl 에 기록
  apply = 판단한 모델·강도로 subagent 호출을 바꾼다
판단은 model-tier.py(TypeSafe, TYPESAFE_API_KEY 필요). 키가 없거나 오류면 원래 호출을 그대로 둔다.

Known gap (codex 0.164.0, verified 2026-10-27): Codex fires PreToolUse for shell/apply_patch but not for
spawn_agent, so the codex branch below is inert until Codex hooks cover that tool. Role models for Codex
come from .codex/agents/*.toml (.claude/scripts/gen-codex-agents.py) in the meantime.
"""
import json
import os
import pathlib
import re
import subprocess
import sys
import time

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import codex_models  # noqa: E402

FLOORS = {"code-reviewer", "security-reviewer", "planner", "api-designer"}
# Codex entries are families; codex_models.newest() resolves them to the account's newest slug.
MODELS = {
    "claude": {"low": "haiku", "mid": "sonnet", "high": "opus"},
    "codex": {"low": "luna", "mid": "terra", "high": "sol"},
}


def effort_for(judged, role):
    # Risk raises model capability; reasoning depth follows task difficulty independently.
    difficulty = judged.get("difficulty", 1)
    effort = "high" if difficulty >= 2 else "low" if difficulty <= 0.7 else "medium"
    if role in FLOORS and effort == "low":
        effort = "medium"
    if judged.get("risk", 0) >= 0.5:
        effort = "high"
    return effort


def claude_effort_supported():
    try:
        version = subprocess.run(["claude", "--version"], capture_output=True, text=True, timeout=2)
        match = re.search(r"(\d+)\.(\d+)\.(\d+)", version.stdout)
        return bool(match and tuple(map(int, match.groups())) >= (2, 1, 292))
    except (OSError, subprocess.TimeoutExpired):
        return False


def route(data, client, root, judge, supports_effort=claude_effort_supported):
    ti = dict(data.get("tool_input") or {})
    role = ti.get("agent_type" if client == "codex" else "subagent_type") or "default"
    record = {"client": client, "agent": role, "applied": False}
    # Resume/forks retain their original configuration and conversation.
    if ti.get("resume") or ti.get("fork_context") or ti.get("fork_turns", "none") != "none":
        return None, dict(record, reason="resume-or-fork")
    if ti.get("model"):
        record.update(reason="explicit-model", chosen_model=ti["model"])
        # Codex role files pin a model that beats spawn arguments; honor the explicit one via the unpinned variant.
        if client == "codex" and role not in {"default", "worker", "explorer"} \
                and (root / ".codex" / "agents" / f"{role}-routed.toml").is_file():
            ti["agent_type"] = f"{role}-routed"
            return ti, dict(record, redirected=True)
        return None, record
    state = {"role": role, "task": ti.get("description", ""),
             "detail": ti.get("message") or ti.get("prompt", "")}
    judged = judge(state)
    record.update(judged)
    tier = judged.get("tier")
    if tier not in MODELS[client]:
        return None, record
    if role in FLOORS and tier == "low":
        tier = "mid"
    model = MODELS[client][tier]
    if client == "codex":
        model = codex_models.newest(model)
    effort_key = "reasoning_effort" if client == "codex" else "effort"
    effort = ti.get(effort_key) or effort_for(judged, role)
    record.update(chosen_model=model, chosen_effort=effort)
    if client == "codex" and role not in {"default", "worker", "explorer"}:
        # Original role TOML has a fixed model/effort and takes precedence over spawn arguments.
        variant = root / ".codex" / "agents" / f"{role}-routed.toml"
        if not variant.is_file():
            return None, dict(record, reason="missing-routed-role")
        ti["agent_type"] = f"{role}-routed"
    ti["model"] = model
    if client == "codex":
        ti["fork_turns"] = "none"
        ti[effort_key] = effort
    elif supports_effort():
        ti[effort_key] = effort
        if os.environ.get("CLAUDE_CODE_EFFORT_LEVEL"):
            record["effort_override"] = "CLAUDE_CODE_EFFORT_LEVEL"
    else:
        record["effort_applied"] = False
        record["effort_reason"] = "requires-claude-2.1.292"
    return ti, record


def router_mode(root):
    """env MODEL_ROUTER > stacks.json .harness.modelRouter > "off"."""
    mode = os.environ.get("MODEL_ROUTER")
    if not mode:
        try:
            data = json.loads((root / ".claude" / "stacks.json").read_text(encoding="utf-8"))
            mode = (data.get("harness") or {}).get("modelRouter")
        except (OSError, ValueError, AttributeError):
            mode = None
    return mode if mode in {"log", "apply"} else "off"


def main():
    root = pathlib.Path(__file__).resolve().parents[2]  # .claude/scripts → 저장소 루트
    mode = router_mode(root)
    if mode == "off":
        return
    data = json.load(sys.stdin)
    client = sys.argv[1] if len(sys.argv) > 1 else "claude"

    def judge(state):
        try:
            result = subprocess.run([sys.executable, str(root / ".claude/scripts/model-tier.py")],
                                    input=json.dumps(state), text=True, capture_output=True, timeout=6)
            return json.loads(result.stdout)
        except (OSError, ValueError, subprocess.SubprocessError) as error:
            return {"tier": None, "source": f"error: {type(error).__name__}"}

    updated, record = route(data, client, root, judge)
    record.update(mode=mode, ts=time.strftime("%Y-%m-%dT%H:%M:%S"))
    record["applied"] = mode == "apply" and updated is not None
    # Logging failure must not prevent applying a successful selection.
    try:
        common = subprocess.run(["git", "rev-parse", "--git-common-dir"], cwd=root,
                                capture_output=True, text=True, check=True).stdout.strip()
        with (root / common / "agent-model-router.jsonl").open("a", encoding="utf-8") as log:
            log.write(json.dumps(record, ensure_ascii=False) + "\n")
    except (OSError, subprocess.SubprocessError):
        pass
    if record["applied"]:
        out = {"hookEventName": "PreToolUse", "updatedInput": updated}
        if client == "codex":
            # Codex reports updatedInput without permissionDecision as a hook error. spawn_agent is not a
            # shell command, so "allow" skips no sandbox/approval check. Claude applies it without (keep it so).
            out["permissionDecision"] = "allow"
        print(json.dumps({"hookSpecificOutput": out}))


if __name__ == "__main__":
    try:
        main()
    except Exception:
        # Missing key, invalid input, timeout or provider failure: keep the original call.
        pass
