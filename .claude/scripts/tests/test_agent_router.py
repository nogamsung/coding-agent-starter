import importlib.util
import json
import os
import re
from pathlib import Path
import subprocess
import tempfile
import unittest
try:
    import tomllib  # 3.11+
except ImportError:  # 사용자 환경 python3 가 3.9·3.10 일 수 있다 — TOML 파싱 검사만 건너뛴다
    tomllib = None
needs_toml = unittest.skipUnless(tomllib, "tomllib requires Python 3.11+")
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[3]  # .claude/scripts/tests → 저장소 루트
SCRIPTS = ROOT / ".claude/scripts"
spec = importlib.util.spec_from_file_location("router", SCRIPTS / "agent-router.py")
router = importlib.util.module_from_spec(spec)
spec.loader.exec_module(router)
codex_models = router.codex_models
spec = importlib.util.spec_from_file_location("gen", SCRIPTS / "gen-codex-agents.py")
gen = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gen)

CATALOG = ["gpt-6-luna", "gpt-7-luna", "gpt-6.1-terra", "gpt-6.1-sol", "gpt-5.6-sol", "gpt-6-astra"]


def real_catalog():
    return codex_models.catalog.__wrapped__() if hasattr(codex_models.catalog, "__wrapped__") else REAL_CATALOG()


REAL_CATALOG = codex_models.catalog


class RoutingTests(unittest.TestCase):
    def setUp(self):
        patcher = patch.object(codex_models, "catalog", return_value=CATALOG)
        patcher.start()
        self.addCleanup(patcher.stop)

    def route(self, ti=None, client="codex", judged=None, supported=True):
        result = judged if judged is not None else {"tier": "mid", "difficulty": 1, "risk": 0}
        return router.route({"tool_input": ti or {"message": "test"}}, client, ROOT,
                            lambda _: result, lambda: supported)

    def test_claude_version_boundary(self):
        for version, expected in [('2.1.291', False), ('2.1.292', True), ('2.1.311 (Claude Code)', True), ('unknown', False)]:
            with self.subTest(version=version), patch.object(router.subprocess, 'run', return_value=subprocess.CompletedProcess([], 0, stdout=version)):
                self.assertEqual(router.claude_effort_supported(), expected)
        with patch.object(router.subprocess, 'run', side_effect=FileNotFoundError):
            self.assertFalse(router.claude_effort_supported())

    def test_codex_model_and_effort(self):
        ti, _ = self.route()
        self.assertEqual((ti["model"], ti["reasoning_effort"], ti["fork_turns"]),
                         ("gpt-6.1-terra", "medium", "none"))

    def test_capability_and_depth_are_independent(self):
        ti, _ = self.route(judged={"tier": "high", "difficulty": 1, "risk": 0})
        self.assertEqual((ti["model"], ti["reasoning_effort"]), ("gpt-6.1-sol", "medium"))

    def test_risk_raises_effort(self):
        ti, _ = self.route(judged={"tier": "high", "difficulty": 0, "risk": 0.9})
        self.assertEqual(ti["reasoning_effort"], "high")

    @needs_toml
    def test_reviewer_floor_and_role_instructions(self):
        ti, _ = self.route({"agent_type": "code-reviewer"}, judged={"tier": "low", "difficulty": 0})
        self.assertEqual((ti["agent_type"], ti["reasoning_effort"], ti["model"]),
                         ("code-reviewer-routed", "medium", "gpt-6.1-terra"))
        original = tomllib.loads((ROOT / '.codex/agents/code-reviewer.toml').read_text())
        routed = tomllib.loads((ROOT / '.codex/agents/code-reviewer-routed.toml').read_text())
        self.assertEqual(original['developer_instructions'], routed['developer_instructions'])
        self.assertEqual((codex_models.family_of(original['model']), original['model_reasoning_effort']), ('terra', 'high'))  # frontmatter effort
        self.assertNotIn('model', routed)
        self.assertNotIn('model_reasoning_effort', routed)

    def test_missing_custom_role_preserves_call(self):
        ti, record = self.route({"agent_type": "unknown"})
        self.assertIsNone(ti)
        self.assertEqual(record['reason'], 'missing-routed-role')

    def test_explicit_model_preserves_call(self):
        ti, _ = self.route({"model": "user-model"})  # built-in role: nothing to redirect
        self.assertIsNone(ti)
        ti, _ = self.route({"subagent_type": "kotlin-tester", "model": "user-model"}, client="claude")
        self.assertIsNone(ti)

    def test_explicit_model_redirects_to_unpinned_role(self):
        ti, record = self.route({"agent_type": "kotlin-tester", "model": "user-model", "reasoning_effort": "high"})
        self.assertEqual((ti["agent_type"], ti["model"], ti["reasoning_effort"]), ("kotlin-tester-routed", "user-model", "high"))
        self.assertEqual((record["reason"], record["redirected"]), ("explicit-model", True))

    def test_explicit_effort_is_preserved(self):
        ti, _ = self.route({"reasoning_effort": "high"})
        self.assertEqual(ti['reasoning_effort'], 'high')

    def test_fork_and_resume_preserved(self):
        for field, value in [('resume', 'id'), ('fork_turns', 'all'), ('fork_turns', '3'), ('fork_context', True)]:
            with self.subTest(field=field):
                ti, _ = self.route({field: value})
                self.assertIsNone(ti)

    def test_failed_judgment_preserves_call(self):
        ti, _ = self.route(judged={"tier": None, "source": "no-key"})
        self.assertIsNone(ti)

    def test_claude_effort_version_guard(self):
        for supported in (True, False):
            ti, _ = self.route(client='claude', supported=supported)
            self.assertEqual(ti['model'], 'sonnet')
            self.assertEqual('effort' in ti, supported)
            self.assertNotIn('reasoning_effort', ti)

    def test_claude_explicit_effort_preserved(self):
        ti, _ = self.route({'effort': 'high'}, client='claude')
        self.assertEqual(ti['effort'], 'high')

    def test_model_override(self):
        with patch.dict(os.environ, {'CODEX_MODEL_TERRA': 'account-model'}):
            ti, _ = self.route()
        self.assertEqual(ti['model'], 'account-model')

    # --- codex_models: alias → family → newest slug ---
    def test_newest_picks_highest_version_of_family(self):
        self.assertEqual(codex_models.newest("luna", CATALOG), "gpt-7-luna")
        self.assertEqual(codex_models.newest("sol", CATALOG), "gpt-6.1-sol")
        self.assertEqual(codex_models.newest("sol", ["gpt-6.1-sol", "gpt-6.10-sol", "gpt-6.9-sol"]), "gpt-6.10-sol")

    def test_newest_without_catalog_keeps_current_then_fallback(self):
        self.assertEqual(codex_models.newest("terra", [], current="gpt-8-terra"), "gpt-8-terra")
        self.assertEqual(codex_models.newest("terra", [], current="gpt-8-luna"), codex_models.FALLBACK["terra"])
        self.assertEqual(codex_models.newest("terra", []), codex_models.FALLBACK["terra"])

    def test_catalog_reads_codex_home_cache(self):
        with tempfile.TemporaryDirectory() as home, patch.dict(os.environ, {"CODEX_HOME": home}):
            self.assertEqual(real_catalog(), [])
            (Path(home) / "models_cache.json").write_text(json.dumps({"models": [
                {"slug": "gpt-8-terra", "visibility": "list"}, {"slug": "gpt-9-terra", "visibility": "hide"},
                {"nested": [{"slug": "gpt-8-luna"}]}]}))
            self.assertEqual(sorted(real_catalog()), ["gpt-8-luna", "gpt-8-terra"])

    def test_tables_cover_the_same_ladder(self):
        for tier, alias in router.MODELS["claude"].items():
            self.assertEqual(router.MODELS["codex"][tier], codex_models.FAMILIES[alias], tier)
        self.assertEqual(set(codex_models.FALLBACK), set(codex_models.FAMILIES.values()))

    def test_router_apply_overrides_frontmatter_effort_on_both_clients(self):
        # Claude: per-invocation effort beats frontmatter; Codex: -routed has no pinned effort, spawn arg applies.
        judged = {"tier": "high", "difficulty": 2.5, "risk": 0}
        ti, _ = self.route({"subagent_type": "kotlin-tester"}, client="claude", judged=judged)
        self.assertEqual((ti["model"], ti["effort"]), ("opus", "high"))
        ti, _ = self.route({"agent_type": "kotlin-tester"}, judged=judged)
        self.assertEqual((ti["agent_type"], ti["model"], ti["reasoning_effort"]), ("kotlin-tester-routed", "gpt-6.1-sol", "high"))

    def test_no_permission_fields_added(self):
        ti, _ = self.route()
        self.assertNotIn('permissionDecision', ti)
        self.assertNotIn('approval_policy', ti)

    def test_mode_defaults_off_and_reads_stacks(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            with patch.dict(os.environ, {}, clear=False):
                os.environ.pop("MODEL_ROUTER", None)
                self.assertEqual(router.router_mode(root), "off")  # stacks.json 없음
                (root / ".claude").mkdir()
                (root / ".claude/stacks.json").write_text('{"mode": "single"}')
                self.assertEqual(router.router_mode(root), "off")  # harness 미설정
                (root / ".claude/stacks.json").write_text('{"harness": {"modelRouter": "apply"}}')
                self.assertEqual(router.router_mode(root), "apply")
                (root / ".claude/stacks.json").write_text('{"harness": {"modelRouter": "bogus"}}')
                self.assertEqual(router.router_mode(root), "off")
                with patch.dict(os.environ, {"MODEL_ROUTER": "log"}):
                    self.assertEqual(router.router_mode(root), "log")  # env 가 우선

    def test_hook_modes_and_failure(self):
        # 실제 진입점 — 오프라인 판정기 + 격리된 git/로그 디렉토리
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            scripts = root / ".claude/scripts"
            scripts.mkdir(parents=True)
            for name in ("agent-router.py", "codex_models.py"):
                (scripts / name).write_text((SCRIPTS / name).read_text())
            (root / "codex-home").mkdir()
            (root / "codex-home/models_cache.json").write_text(json.dumps({"models": [{"slug": "gpt-7-luna"}]}))
            (scripts / "model-tier.py").write_text('print(\'{"tier":"low","difficulty":0,"risk":0}\')')
            subprocess.run(["git", "init", "-q", str(root)], check=True)
            for mode in ("log", "off", "apply", "invalid"):
                with self.subTest(mode=mode):
                    env = dict(os.environ, MODEL_ROUTER=mode, CODEX_HOME=str(root / "codex-home"))
                    result = subprocess.run(["python3", str(scripts / "agent-router.py"), "codex"],
                                            input='{"tool_input":{"message":"test"}}',
                                            text=True, capture_output=True, env=env, check=True)
                    if mode == "apply":
                        hook = json.loads(result.stdout)["hookSpecificOutput"]
                        self.assertEqual((hook["updatedInput"]["model"], hook["permissionDecision"]), ("gpt-7-luna", "allow"))
                    else:
                        self.assertEqual(result.stdout, "")
            records = [json.loads(line) for line in (root / ".git/agent-model-router.jsonl").read_text().splitlines()]
            self.assertEqual([r["applied"] for r in records], [False, True])
            # 기본(stacks.json·env 없음) = off → 기록도 출력도 없다
            env = {k: v for k, v in os.environ.items() if k != "MODEL_ROUTER"}
            result = subprocess.run(["python3", str(scripts / "agent-router.py"), "claude"],
                                    input='{"tool_input":{"prompt":"x"}}', text=True, capture_output=True, env=env, check=True)
            self.assertEqual(result.stdout, "")
            self.assertEqual(len((root / ".git/agent-model-router.jsonl").read_text().splitlines()), 2)
            for payload in ("invalid JSON", "{}"):
                (scripts / "model-tier.py").write_text('print("invalid")')
                result = subprocess.run(["python3", str(scripts / "agent-router.py"), "codex"],
                                        input=payload, text=True, capture_output=True,
                                        env=dict(os.environ, MODEL_ROUTER="apply"), check=True)
                self.assertEqual(result.stdout, "")

if __name__ == '__main__':
    unittest.main()
