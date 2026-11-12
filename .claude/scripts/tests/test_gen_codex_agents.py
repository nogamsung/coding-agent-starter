"""gen-codex-agents.py — .claude/agents/*.md → .codex/agents/*.toml 생성기 테스트."""
import importlib.util
import os
import re
import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch
try:
    import tomllib  # 3.11+
except ImportError:
    tomllib = None
needs_toml = unittest.skipUnless(tomllib, "tomllib requires Python 3.11+")

ROOT = Path(__file__).resolve().parents[3]
SCRIPTS = ROOT / ".claude/scripts"
spec = importlib.util.spec_from_file_location("gen", SCRIPTS / "gen-codex-agents.py")
gen = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gen)
codex_models = gen.codex_models
CATALOG = ["gpt-6-luna", "gpt-7-luna", "gpt-6.1-terra", "gpt-6.1-sol", "gpt-5.6-sol", "gpt-6-astra"]


class GeneratorTests(unittest.TestCase):
    def setUp(self):
        patcher = patch.object(codex_models, "catalog", return_value=CATALOG)
        patcher.start()
        self.addCleanup(patcher.stop)

    def test_every_agent_has_alias_and_effort(self):
        for md in (ROOT / ".claude/agents").glob("*.md"):
            head = md.read_text().split("\n---\n", 1)[0]
            alias = re.search(r"^model:\s*(\S+)", head, re.M)
            effort = re.search(r"^effort:\s*(\S+)", head, re.M)
            self.assertTrue(alias and alias.group(1) in codex_models.FAMILIES, md.name)
            self.assertTrue(effort and effort.group(1) in gen.EFFORTS, md.name)

    def test_check_passes_on_committed_tree(self):
        result = subprocess.run(["python3", str(SCRIPTS / "gen-codex-agents.py"), "--check"],
                                capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)

    @needs_toml
    def test_generated_toml_matches_alias_family(self):
        for md in (ROOT / ".claude/agents").glob("*.md"):
            head = md.read_text().split("\n---\n", 1)[0]
            alias = re.search(r"^model:\s*(\S+)", head, re.M).group(1)
            effort = re.search(r"^effort:\s*(\S+)", head, re.M).group(1)
            parsed = tomllib.loads((ROOT / f".codex/agents/{md.stem}.toml").read_text())
            self.assertEqual(codex_models.family_of(parsed["model"]), codex_models.FAMILIES[alias], md.name)
            self.assertEqual(parsed["model_reasoning_effort"], effort, md.name)  # Claude 와 Codex 가 같은 강도
            routed = tomllib.loads((ROOT / f".codex/agents/{md.stem}-routed.toml").read_text())
            self.assertEqual(set(routed), {"name", "description", "developer_instructions"}, md.name)

    def test_missing_effort_is_rejected(self):
        with tempfile.TemporaryDirectory() as temp:
            md = Path(temp) / "x.md"
            md.write_text("---\nname: x\nmodel: haiku\n---\nbody\n")
            with self.assertRaises(SystemExit):
                gen.render(md)
            md.write_text("---\nname: x\nmodel: haiku\neffort: turbo\n---\nbody\n")
            with self.assertRaises(SystemExit):
                gen.render(md)
            md.write_text("---\nname: x\nmodel: inherit\n---\nbody\n")  # 별칭 없으면 강도도 안 쓴다
            self.assertNotIn("model", gen.render(md)[1].split("developer_instructions")[0])

    def test_check_compares_family_not_version(self):
        a = 'name = "x"\nmodel = "gpt-6-luna"\nmodel_reasoning_effort = "low"\n'
        self.assertTrue(gen.same_family(a, a.replace("gpt-6-luna", "gpt-9-luna")))
        self.assertFalse(gen.same_family(a, a.replace("gpt-6-luna", "gpt-9-sol")))
        self.assertFalse(gen.same_family(a, a.replace('"low"', '"high"')))
        self.assertFalse(gen.same_family(None, a))

    @needs_toml
    def test_render_uses_catalog_then_current(self):
        md = ROOT / ".claude/agents/kotlin-tester.md"
        self.assertIn('model = "gpt-7-luna"', gen.render(md)[1])
        with patch.object(codex_models, "catalog", return_value=[]):
            self.assertIn('model = "gpt-8-luna"', gen.render(md, current="gpt-8-luna")[1])
            self.assertIn(f'model = "{codex_models.FALLBACK["luna"]}"', gen.render(md)[1])
        self.assertEqual(set(tomllib.loads(gen.render(md, routed=True)[1])), {"name", "description", "developer_instructions"})



if __name__ == "__main__":
    unittest.main()
