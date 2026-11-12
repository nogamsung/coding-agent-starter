"""coverage-gate.py 단위 테스트 — python3 -m unittest discover -s .claude/scripts/tests"""
import importlib.util
import json
import os
import pathlib
import tempfile
import unittest

SPEC = importlib.util.spec_from_file_location(
    "coverage_gate", pathlib.Path(__file__).resolve().parents[1] / "coverage-gate.py")
cg = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(cg)


def write(base, rel, text):
    p = pathlib.Path(base, rel)
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(text)
    return p


JACOCO = """<?xml version="1.0"?><report name="x">
<package name="a"><counter type="LINE" missed="100" covered="100"/></package>
<counter type="LINE" missed="{m}" covered="{c}"/></report>"""


class ParserTest(unittest.TestCase):
    def setUp(self):
        self.d = tempfile.mkdtemp()

    def test_jacoco_multi_module_sums_report_level_counters(self):
        write(self.d, "a/build/reports/jacoco/test/jacocoTestReport.xml", JACOCO.format(m=10, c=90))
        write(self.d, "b/build/reports/jacoco/test/jacocoTestReport.xml", JACOCO.format(m=30, c=70))
        self.assertEqual(cg.percent("kotlin-multi", self.d), 80.0)

    def test_go_profile_dedupes_blocks(self):
        write(self.d, "coverage.out", "mode: set\nx.go:1.1,2.2 3 1\nx.go:3.1,4.2 1 0\nx.go:1.1,2.2 3 0\n")
        self.assertEqual(cg.percent("go", self.d), 75.0)

    def test_python_xml_and_json(self):
        write(self.d, "coverage.xml", '<coverage line-rate="0.5" lines-valid="10" lines-covered="9"/>')
        self.assertEqual(cg.percent("python", self.d), 90.0)
        d2 = tempfile.mkdtemp()
        write(d2, "coverage.json", json.dumps({"totals": {"covered_lines": 1, "num_statements": 4}}))
        self.assertEqual(cg.percent("python-multi", d2), 25.0)

    def test_nextjs_summary_aggregates_apps_and_skips_node_modules(self):
        s = lambda c, t: json.dumps({"total": {"lines": {"covered": c, "total": t, "pct": 0}}})
        write(self.d, "apps/a/coverage/coverage-summary.json", s(9, 10))
        write(self.d, "apps/b/coverage/coverage-summary.json", s(1, 10))
        write(self.d, "node_modules/x/coverage/coverage-summary.json", s(0, 1000))
        self.assertEqual(cg.percent("nextjs-multi", self.d), 50.0)

    def test_flutter_lcov(self):
        write(self.d, "coverage/lcov.info", "SF:a\nLF:10\nLH:9\nend_of_record\nSF:b\nLF:10\nLH:10\n")
        self.assertEqual(cg.percent("flutter", self.d), 95.0)

    def test_missing_report_is_none(self):
        self.assertIsNone(cg.percent("go", self.d))


class SelectionTest(unittest.TestCase):
    STACKS = [("kotlin", "backend"), ("nextjs", "web"), ("go", ".")]

    def test_changed_files_map_to_owning_stack(self):
        got = cg.stacks_for_changes(self.STACKS, ["backend/src/A.kt", "README.md", "web/docs.md"])
        self.assertEqual(got, [("kotlin", "backend")])

    def test_root_stack_gets_unowned_files_but_not_meta(self):
        self.assertEqual(cg.stacks_for_changes(self.STACKS, ["main.go"]), [("go", ".")])
        self.assertEqual(cg.stacks_for_changes(self.STACKS, [".claude/hooks/x.sh", ".github/w.yml"]), [])

    def test_longest_path_wins(self):
        stacks = [("nextjs", "web"), ("nextjs", "web/admin")]
        self.assertEqual(cg.stacks_for_changes(stacks, ["web/admin/a.ts"]), [("nextjs", "web/admin")])


class CheckTest(unittest.TestCase):
    def setUp(self):
        self.d = tempfile.mkdtemp()
        write(self.d, ".claude/stacks.json", json.dumps({
            "mode": "monorepo", "harness": {"coverage": 80},
            "stacks": [{"type": "go", "path": "api"}, {"type": "flutter", "path": "app"}]}))

    def test_threshold_from_stacks_json(self):
        self.assertEqual(cg.threshold(self.d), 80.0)

    def test_check_pass_fail_and_missing(self):
        write(self.d, "api/coverage.out", "mode: set\na.go:1.1,2.2 9 1\na.go:3.1,4.2 1 0\n")
        self.assertEqual(cg.main(["--repo", self.d, "check", "--stack", "go:api"]), 0)
        self.assertEqual(cg.main(["--repo", self.d, "check", "--stack", "go:api", "--threshold", "95"]), 1)
        self.assertEqual(cg.main(["--repo", self.d, "check", "--all"]), 1)  # app 리포트 없음

    def test_threshold_zero_disables(self):
        self.assertEqual(cg.main(["--repo", self.d, "check", "--all", "--threshold", "0"]), 0)


if __name__ == "__main__":
    unittest.main()
