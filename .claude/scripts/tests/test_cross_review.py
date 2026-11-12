import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[3]
SCRIPTS = ROOT / ".claude/scripts"
spec = importlib.util.spec_from_file_location("review_result", SCRIPTS / "cross-review-result.py")
result = importlib.util.module_from_spec(spec)
spec.loader.exec_module(result)


def claude_response(text="검토 완료\nVERDICT: PASS", **overrides):
    return json.dumps({"type": "result", "subtype": "success", "is_error": False,
                       "result": text, **overrides})


def codex_response(text="검토 완료", verdict="PASS"):
    return json.dumps({"review": text, "verdict": verdict})


class ResultTests(unittest.TestCase):
    def test_claude_real_verdicts_are_preserved(self):
        for verdict in ("PASS", "REVIEW", "BLOCK"):
            with self.subTest(verdict=verdict):
                code, review, _ = result.classify("claude", 0, claude_response(f"결과\nVERDICT: {verdict}"), "")
                self.assertEqual(code, 0)
                self.assertEqual(review, f"결과\nVERDICT: {verdict}\n")

    def test_claude_markdown_verdict_is_normalized_without_inventing_one(self):
        for decoration in ("**", "__", "`"):
            payload = claude_response(f"결과\n{decoration}VERDICT: BLOCK{decoration}")
            code, review, _ = result.classify("claude", 0, payload, "")
            self.assertEqual(code, 0)
            self.assertEqual(review, "결과\nVERDICT: BLOCK\n")

    def test_codex_structured_verdicts_and_invalid_results(self):
        for verdict in ("PASS", "REVIEW", "BLOCK"):
            code, review, _ = result.classify("codex", 0, codex_response("실제 리뷰", verdict), "")
            self.assertEqual(code, 0)
            self.assertEqual(review, f"실제 리뷰\n\nVERDICT: {verdict}\n")
        for payload in ("", "null", "[]", "{}", "VERDICT: PASS", codex_response(""),
                        codex_response(None), codex_response(verdict="UNKNOWN")):
            self.assertEqual(result.classify("codex", 0, payload, "")[0], 1)
        self.assertEqual(result.classify("codex", 1, codex_response(), "")[0], 1)

    def test_claude_confirmed_usage_limit_is_the_only_fallback(self):
        for status in (0, 1):
            for payload in (
                claude_response("You've hit your limit · resets 5pm", is_error=True),
                claude_response("", subtype="error_during_execution", is_error=True,
                                errors=["Usage limit exceeded. Try again later."]),
            ):
                with self.subTest(status=status, payload=payload):
                    self.assertEqual(result.classify("claude", status, payload, "")[0], 3)

    def test_claude_auth_network_billing_and_generic_throttle_are_errors(self):
        for message in ("Not logged in", "Unauthorized", "Subscription expired", "Credit balance is too low",
                        "Rate limit exceeded", "HTTP 429 Too Many Requests", "Connection timed out",
                        "Permission denied", "Something exceeded its size"):
            with self.subTest(message=message):
                payload = claude_response(message, is_error=True, subtype="error_during_execution")
                self.assertEqual(result.classify("claude", 1, payload, "")[0], 1)

    def test_usage_words_in_normal_review_do_not_trigger_fallback(self):
        for reviewer, output in (
            ("claude", claude_response("Usage limit exceeded is a string in the code\nVERDICT: REVIEW")),
            ("codex", codex_response("Usage limit exceeded is a string in the code", "REVIEW")),
        ):
            self.assertEqual(result.classify(reviewer, 0, output, "ERROR: You've hit your usage limit")[0], 0)
        self.assertEqual(result.classify("claude", 0, claude_response("You've hit your limit"), "")[0], 1)

    def test_timeout_and_local_budget_are_not_platform_usage_limits(self):
        quota = claude_response("You've hit your limit", is_error=True)
        for status in (124, 137, 143):
            self.assertEqual(result.classify("claude", status, quota, "")[0], 1)
        for subtype in ("error_max_turns", "error_max_budget_usd", "error_max_structured_output_retries"):
            payload = claude_response("You've hit your limit", is_error=True, subtype=subtype)
            self.assertEqual(result.classify("claude", 1, payload, "")[0], 1)

    def test_incomplete_malformed_or_denied_claude_review_never_passes(self):
        for payload in ("", "VERDICT: PASS", "null", "[]", "{}", claude_response("done"),
                        claude_response("VERDICT: PASS\nunfinished"), claude_response(None),
                        claude_response(permission_denials=[{"tool_name": "Read"}])):
            with self.subTest(payload=payload):
                self.assertEqual(result.classify("claude", 0, payload, "")[0], 1)
        self.assertEqual(result.classify("claude", 1, claude_response(), "")[0], 1)

    def test_codex_only_accepts_terminal_explicit_usage_error_without_result(self):
        message = "ERROR: You've hit your usage limit. Try again later."
        self.assertEqual(result.classify("codex", 1, "", message)[0], 3)
        self.assertEqual(result.classify("codex", 0, "", message)[0], 1)
        self.assertEqual(result.classify("codex", 1, "VERDICT: PASS", message)[0], 1)
        self.assertEqual(result.classify("codex", 1, "", message + "\nERROR: network failure")[0], 1)
        self.assertEqual(result.classify("codex", 1, "", message + "\nError: connection closed")[0], 1)

    def test_codex_progress_and_ordinary_failures_do_not_authorize_fallback(self):
        for message in ("quoted source: usage limit exceeded", "You've hit your usage limit",
                        "ERROR: Not logged in", "ERROR: Rate limit exceeded", "ERROR: approval rejected",
                        "ERROR: insufficient_quota: check billing details",
                        "ERROR: You exceeded your current quota, please check your billing details"):
            with self.subTest(message=message):
                self.assertEqual(result.classify("codex", 1, "", message)[0], 1)
        self.assertEqual(result.classify("codex", 0, "", "VERDICT: PASS")[0], 1)


class WrapperTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.repo = Path(temporary.name)
        self.bin = self.repo / "bin"
        self.bin.mkdir()
        # No real reviewer or network executable can be reached by these offline tests.
        for executable in ("git", "bash", "grep", "python3", "head", "tail", "date", "mktemp", "rm", "cat", "env", "wc", "tr", "dirname"):
            target = sys.executable if executable == "python3" else shutil.which(executable)
            self.assertIsNotNone(target, executable)
            (self.bin / executable).symlink_to(target)
        for name in ("cross-review.sh", "cross-review-result.py"):
            self.write(".claude/scripts/" + name, (SCRIPTS / name).read_text())
        self.write(".claude/hooks/timing.sh", "timing_log() { :; }\n")
        self.git("init", "-q")
        self.git("config", "user.email", "review-test@example.invalid")
        self.git("config", "user.name", "Review fixture")
        self.git("config", "core.hooksPath", "/dev/null")
        self.git("config", "gc.auto", "0")
        self.git("add", ".claude")
        self.git("commit", "-qm", "base")
        self.git("update-ref", "refs/remotes/origin/dev", "HEAD")
        self.write("code.txt", "changed")
        self.git("add", "code.txt")
        self.git("commit", "-qm", "change")
        self.report = self.repo / ".git/cross-review.md"
        self.report.write_text("old report\nVERDICT: PASS\n")
        self.error = self.repo / ".git/cross-review-error.log"
        self.error.write_text("old error")
        for reviewer in ("claude", "codex"):
            self.write("bin/" + reviewer, f"#!{sys.executable}\n" +
                       "import os,sys,json\nfrom pathlib import Path\n"
                       "Path('called.json').write_text(json.dumps(sys.argv[1:]))\n"
                       "if '--output-last-message' in sys.argv:\n"
                       "    Path(sys.argv[sys.argv.index('--output-last-message')+1]).write_text(os.environ.get('FAKE_STDOUT',''))\n"
                       "sys.stdout.write(os.environ.get('FAKE_STDOUT',''))\n"
                       "sys.stderr.write(os.environ.get('FAKE_STDERR',''))\n"
                       "sys.exit(int(os.environ.get('FAKE_EXIT','0')))\n")
            (self.bin / reviewer).chmod(0o755)

    def write(self, name, text):
        path = self.repo / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text)

    def git(self, *args):
        return subprocess.check_output(["git", "-C", str(self.repo), *args], input="", text=True, stderr=subprocess.PIPE)

    def run_review(self, reviewer="claude", stdout=None, stderr="", status=0):
        env = {**os.environ, "PATH": str(self.bin), "MODEL_ROUTER": "off",
               "FAKE_STDOUT": claude_response() if stdout is None else stdout,
               "FAKE_STDERR": stderr, "FAKE_EXIT": str(status)}
        return subprocess.run([str(self.bin / "bash"), ".claude/scripts/cross-review.sh", "--base", "dev",
                               "--reviewer", reviewer], cwd=self.repo, env=env, text=True,
                              capture_output=True, timeout=20)

    def test_claude_success_writes_real_report_and_read_only_arguments(self):
        process = self.run_review()
        self.assertEqual(process.returncode, 0, process.stderr)
        self.assertIn("VERDICT: PASS", self.report.read_text())
        self.assertNotIn("old report", self.report.read_text())
        self.assertFalse(self.error.exists())
        args = json.loads((self.repo / "called.json").read_text())
        self.assertEqual(args[args.index("--tools") + 1], "Read,Grep,Glob")
        self.assertEqual(args[args.index("--allowedTools") + 1], "Read,Grep,Glob")
        self.assertEqual(args[args.index("--output-format") + 1], "json")
        self.assertTrue(args[args.index("--add-dir") + 1])
        self.assertIn("AGENTS.md", args[args.index("-p") + 1])
        self.assertNotIn("--dangerously-skip-permissions", args)

    def test_usage_limit_removes_old_report_and_records_private_diagnostics(self):
        process = self.run_review(stdout=claude_response("You've hit your limit", is_error=True), status=1)
        self.assertEqual(process.returncode, 3, process.stderr)
        self.assertFalse(self.report.exists())
        self.assertEqual(self.error.stat().st_mode & 0o777, 0o600)

    def test_login_failure_and_missing_verdict_are_errors_not_fallback(self):
        for payload in (claude_response("Please log in", is_error=True), claude_response("Unfinished review")):
            process = self.run_review(stdout=payload, status=1)
            self.assertEqual(process.returncode, 1, process.stderr)
            self.assertFalse(self.report.exists())
            self.assertNotIn("VERDICT:", process.stdout)

    def test_missing_binary_is_not_usage_limit(self):
        (self.bin / "claude").unlink()
        process = self.run_review()
        self.assertEqual(process.returncode, 1, process.stderr)
        self.assertFalse(self.report.exists())
        self.assertFalse((self.repo / "called.json").exists())

    def test_timeout_is_not_usage_limit(self):
        self.write("bin/timeout", "#!/bin/bash\nexit 124\n")
        (self.bin / "timeout").chmod(0o755)
        process = self.run_review()
        self.assertEqual(process.returncode, 1, process.stderr)
        self.assertFalse(self.report.exists())

    def test_codex_success_keeps_read_only_sandbox(self):
        process = self.run_review("codex", stdout=codex_response("리뷰", "BLOCK"))
        self.assertEqual(process.returncode, 0, process.stderr)
        self.assertTrue(self.report.read_text().endswith("VERDICT: BLOCK\n"))
        args = json.loads((self.repo / "called.json").read_text())
        self.assertEqual(args[0], "exec")
        self.assertEqual(args[args.index("--sandbox") + 1], "read-only")
        self.assertIn("--output-schema", args)

    def test_diff_failure_does_not_claim_no_changes_pass(self):
        # An unrelated commit exists but cannot have a three-dot merge base with HEAD.
        tree = self.git("mktree").strip()
        unrelated = self.git("commit-tree", tree, "-m", "unrelated").strip()
        self.git("update-ref", "refs/remotes/origin/dev", unrelated)
        process = self.run_review()
        self.assertEqual(process.returncode, 1, process.stderr)
        self.assertNotIn("VERDICT: PASS", process.stdout)
        self.assertFalse((self.repo / "called.json").exists())

    def test_codex_usage_limit_and_approval_error_are_distinct(self):
        self.assertEqual(self.run_review("codex", stdout="", stderr="ERROR: You've hit your usage limit", status=1).returncode, 3)
        self.assertEqual(self.run_review("codex", stdout="", stderr="ERROR: approval rejected", status=1).returncode, 1)
        self.assertFalse(self.report.exists())


if __name__ == "__main__":
    unittest.main()
