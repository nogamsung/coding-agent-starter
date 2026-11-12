#!/usr/bin/env python3
"""Accept a completed review; only confirmed platform usage exhaustion returns 3."""

import argparse
import json
from pathlib import Path
import re
import sys


VERDICT = re.compile(r"VERDICT: (PASS|REVIEW|BLOCK)")
USAGE = re.compile(
    r"^(?:(?:error|api error):\s*)?(?:"
    r"you(?:['’]ve| have) hit your (?:usage )?limit\b|"
    r"you (?:have )?(?:exceeded|reached) your (?:usage|weekly|monthly|session) limit\b|"
    r"(?:usage limit|usage quota) (?:has been )?(?:exceeded|reached|exhausted)\b)", re.I,
)


def normalize_review(text):
    lines = text.strip().splitlines()
    if not lines:
        return ""
    last = lines[-1].strip()
    for decoration in ("**", "__", "`"):
        if last.startswith(decoration) and last.endswith(decoration):
            last = last[len(decoration):-len(decoration)].strip()
            break
    if not VERDICT.fullmatch(last):
        return ""
    return "\n".join([*lines[:-1], last]) + "\n"


def classify(reviewer, status, stdout, stderr):
    if status in {124, 137, 143}:
        return 1, "", "Reviewer timed out or was interrupted; repair and rerun"
    if reviewer == "claude":
        try:
            result = json.loads(stdout)
        except (ValueError, TypeError):
            return 1, "", "Claude did not return a valid JSON result; repair and rerun"
        if not isinstance(result, dict) or result.get("type") != "result":
            return 1, "", "Claude result envelope is missing"
        if result.get("permission_denials"):
            return 1, "", "Review contains denied tool access; resolve it and rerun"
        text = result.get("result", "")
        if not isinstance(text, str):
            return 1, "", "Claude result text is invalid"
        if result.get("is_error") is True:
            errors = result.get("errors", [])
            if isinstance(errors, list):
                messages = [text, *(e for e in errors if isinstance(e, str))]
                # Limit/budget/turn errors imposed by the caller are not platform usage exhaustion.
                if (result.get("subtype") in {"success", "error_during_execution"}
                        and any(USAGE.match(m.strip()) for m in messages)):
                    return 3, "", "Confirmed Claude platform usage limit"
            return 1, "", "Claude reported an execution error; repair and rerun"
        review = normalize_review(text)
        if status == 0 and result.get("is_error") is False and result.get("subtype") == "success" and review:
            return 0, review, ""
        return 1, "", "Claude review did not finish with a valid verdict"
    if reviewer == "codex":
        # `codex review` enforces its own report shape and can discard a requested VERDICT.
        # `codex exec --output-schema` supplies an explicit verdict separately from the prose.
        if status == 0:
            try:
                result = json.loads(stdout)
            except (ValueError, TypeError):
                result = None
            if (isinstance(result, dict) and isinstance(result.get("review"), str)
                    and result["review"].strip() and result.get("verdict") in ("PASS", "REVIEW", "BLOCK")):
                return 0, result["review"].strip() + "\n\nVERDICT: " + result["verdict"] + "\n", ""
        # Codex progress may quote source code: accept only its explicit terminal ERROR line,
        # after a failed process without a review result. Bare quota mentions are not evidence.
        lines = stderr.strip().splitlines()
        last = lines[-1].strip() if lines else ""
        if status != 0 and not stdout.strip() and last.startswith("ERROR:") and USAGE.match(last[6:].strip()):
            return 3, "", "Confirmed Codex platform usage limit"
        return 1, "", "Codex review failed or has no valid verdict; repair and rerun"
    return 1, "", "Unknown reviewer"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("reviewer", choices=("claude", "codex"))
    parser.add_argument("status", type=int)
    parser.add_argument("stdout", type=Path)
    parser.add_argument("stderr", type=Path)
    args = parser.parse_args()
    code, review, reason = classify(args.reviewer, args.status, args.stdout.read_text(), args.stderr.read_text())
    if review:
        print(review, end="")
    if reason:
        print(reason, file=sys.stderr)
    return code


if __name__ == "__main__":
    raise SystemExit(main())
