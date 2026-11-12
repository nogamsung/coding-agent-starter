#!/usr/bin/env python3
"""커버리지 게이트 — 로컬 pre-push 와 CI 가 같은 규칙·같은 스크립트로 판정한다.

규칙: 이번 변경에서 손댄 스택은 각각 라인 커버리지가 기준(.claude/stacks.json 의 harness.coverage, 기본 90) 이상.
  손대지 않은 스택은 판정하지 않는다 — 기존 미달 스택이 다른 PR 을 막지 않고, 건드리는 순간 기준을 맞춰야 한다.
  테스트는 호출한 쪽(pre-push.sh·CI)이 먼저 돌려 리포트를 만든다. 이 스크립트는 리포트만 읽는다.

지원 리포트 (스택 경로 기준, node_modules·.venv 등 제외하고 하위 전체 탐색):
  kotlin|kotlin-multi  JaCoCo XML      **/build/reports/jacoco/**/*.xml   (모듈 합산)
  go|go-multi          cover profile   **/coverage.out                     (문 단위, 모듈 합산)
  python|python-multi  coverage.py     coverage.xml (line-rate) · coverage.json
  nextjs|nextjs-multi  istanbul        **/coverage/coverage-summary.json · **/coverage/lcov.info
  flutter|flutter-multi lcov           **/coverage/lcov.info

사용
  python3 .claude/scripts/coverage-gate.py threshold                         # 기준값
  python3 .claude/scripts/coverage-gate.py percent kotlin backend            # 한 스택 커버리지(%) — 리포트 없으면 exit 2
  git diff --name-only origin/dev...HEAD | python3 .claude/scripts/coverage-gate.py changed-stacks
  python3 .claude/scripts/coverage-gate.py check --base-ref origin/dev       # 바뀐 스택만 판정 (CI·pre-push 공통)
  python3 .claude/scripts/coverage-gate.py check --all                       # 전체 스택
  python3 .claude/scripts/coverage-gate.py check --stack go:. --threshold 80 # 명시
종료 코드: 0 통과 · 1 미달/리포트 없음 · 2 사용법 오류
"""
import argparse
import glob
import json
import os
import subprocess
import sys
import xml.etree.ElementTree as ET

DEFAULT_THRESHOLD = 90
SKIP_DIRS = {"node_modules", ".venv", "venv", ".git", ".dart_tool", ".gradle", ".next", "dist", ".worktrees"}
DOC_SUFFIXES = (".md",)


def load_stacks(repo):
    p = os.path.join(repo, ".claude", "stacks.json")
    try:
        d = json.load(open(p))
    except Exception:
        return {}, []
    stacks = d.get("stacks") or []
    if not stacks and d.get("type"):
        stacks = [{"type": d["type"], "path": d.get("path", ".")}]
    out = []
    for s in stacks:
        if s.get("type"):
            out.append((s["type"], (s.get("path") or ".").rstrip("/") or "."))
    return d.get("harness") or {}, out


def threshold(repo):
    h, _ = load_stacks(repo)
    try:
        return float(h.get("coverage", DEFAULT_THRESHOLD))
    except (TypeError, ValueError):
        return float(DEFAULT_THRESHOLD)


def find(base, patterns):
    hits = []
    for pat in patterns:
        for f in glob.glob(os.path.join(base, pat), recursive=True):
            parts = set(os.path.relpath(f, base).split(os.sep))
            if not parts & SKIP_DIRS and os.path.isfile(f):
                hits.append(f)
    return sorted(set(hits))


# ── 리포트 파서: (covered, total) 라인 수 ─────────────────────────────
def jacoco_lines(path):
    root = ET.parse(path).getroot()
    for c in root.findall("counter"):  # report 직속 counter = 전체 합계 (하위까지 세면 중복)
        if c.get("type") == "LINE":
            return int(c.get("covered", 0)), int(c.get("covered", 0)) + int(c.get("missed", 0))
    return 0, 0


def lcov_lines(path):
    lf = lh = 0
    with open(path) as f:
        for line in f:
            if line.startswith("LF:"):
                lf += int(line.strip()[3:] or 0)
            elif line.startswith("LH:"):
                lh += int(line.strip()[3:] or 0)
    return lh, lf


def istanbul_lines(path):
    t = json.load(open(path))["total"]["lines"]
    return int(t.get("covered", 0)), int(t.get("total", 0))


def goprofile_lines(path):
    blocks = {}
    with open(path) as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("mode:"):
                continue
            try:
                loc, stmts, count = line.rsplit(" ", 2)
                stmts, count = int(stmts), int(count)
            except ValueError:
                continue
            prev = blocks.get(loc, (stmts, 0))
            blocks[loc] = (stmts, max(prev[1], count))
    total = sum(s for s, _ in blocks.values())
    covered = sum(s for s, c in blocks.values() if c > 0)
    return covered, total


def coveragepy_xml_lines(path):
    root = ET.parse(path).getroot()
    if root.get("lines-valid") is not None:
        return int(root.get("lines-covered", 0)), int(root.get("lines-valid", 0))
    rate = float(root.get("line-rate", 0))
    return rate * 1000, 1000


def coveragepy_json_lines(path):
    t = json.load(open(path))["totals"]
    return int(t.get("covered_lines", 0)), int(t.get("num_statements", 0))


def family(stack_type):
    return stack_type.split("-")[0]


def measure(stack_type, path):
    """스택 경로의 리포트를 모아 (covered, total, 리포트 목록). 리포트 없으면 total=None."""
    fam = family(stack_type)
    pairs = []
    if fam == "kotlin":
        reps = find(path, ["**/build/reports/jacoco/**/*.xml"])
        pairs = [(r, jacoco_lines) for r in reps]
    elif fam == "go":
        pairs = [(r, goprofile_lines) for r in find(path, ["coverage.out", "**/coverage.out"])]  # go.work 모듈별 합산
    elif fam == "python":
        xml = find(path, ["coverage.xml"])
        js = find(path, ["coverage.json"])
        pairs = [(xml[0], coveragepy_xml_lines)] if xml else ([(js[0], coveragepy_json_lines)] if js else [])
    elif fam == "nextjs":
        summ = find(path, ["coverage/coverage-summary.json", "**/coverage/coverage-summary.json"])
        if summ:
            pairs = [(r, istanbul_lines) for r in summ]
        else:
            pairs = [(r, lcov_lines) for r in find(path, ["coverage/lcov.info", "**/coverage/lcov.info"])]
    elif fam == "flutter":
        pairs = [(r, lcov_lines) for r in find(path, ["coverage/lcov.info", "**/coverage/lcov.info"])]
    else:
        return None, None, []
    if not pairs:
        return 0, None, []
    cov = tot = 0
    used = []
    for rep, fn in pairs:
        try:
            c, t = fn(rep)
        except Exception:
            continue
        cov += c
        tot += t
        used.append(rep)
    if not used:
        return 0, None, []
    return cov, tot, used


def percent(stack_type, path):
    cov, tot, _ = measure(stack_type, path)
    if tot is None:
        return None
    return 100.0 if tot == 0 else round(cov / tot * 100, 1)


def stacks_for_changes(stacks, changed):
    """바뀐 파일 → 손댄 스택. 문서(.md)만 바뀐 스택은 제외. path '.' 스택은 다른 스택에 안 속한 파일을 받는다."""
    hit = []
    named = [s for s in stacks if s[1] != "."]
    root = [s for s in stacks if s[1] == "."]
    for f in changed:
        if not f or f.endswith(DOC_SUFFIXES):
            continue
        owner = None
        for s in sorted(named, key=lambda s: -len(s[1])):
            if f.startswith(s[1] + "/"):
                owner = s
                break
        if owner is None and root:
            first = f.split("/")[0]
            if first.startswith((".claude", ".codex", ".agents", ".github", ".githooks", "docs", "memory")):
                continue
            owner = root[0]
        if owner and owner not in hit:
            hit.append(owner)
    return [s for s in stacks if s in hit]


def git_changed(repo, ref):
    out = subprocess.run(["git", "-C", repo, "diff", "--name-only", ref], capture_output=True, text=True)
    if out.returncode != 0:
        print(f"[coverage] git diff {ref} 실패 — 전체 스택으로 판정", file=sys.stderr)
        return None
    return [l for l in out.stdout.splitlines() if l]


def parse_stack_arg(v):
    if ":" not in v:
        raise argparse.ArgumentTypeError("--stack 은 type:path 형식")
    t, p = v.split(":", 1)
    return t, (p.rstrip("/") or ".")


def cmd_check(args):
    repo = args.repo
    thr = args.threshold if args.threshold is not None else threshold(repo)
    if thr <= 0:
        print("[coverage] 기준 0 — 게이트 꺼짐")
        return 0
    _, stacks = load_stacks(repo)
    if args.stack:
        targets = args.stack
    elif args.all:
        targets = stacks
    elif args.base_ref:
        changed = git_changed(repo, args.base_ref)
        targets = stacks if changed is None else stacks_for_changes(stacks, changed)
    elif not sys.stdin.isatty():
        targets = stacks_for_changes(stacks, [l.strip() for l in sys.stdin if l.strip()])
    else:
        targets = stacks
    if not targets:
        print("[coverage] 판정할 스택 없음 (손댄 스택 없음)")
        return 0
    failed = 0
    for t, p in targets:
        cov, tot, reps = measure(t, os.path.join(repo, p))
        label = f"[{p}] ({t})"
        if cov is None:
            print(f"[coverage] {label} 지원하지 않는 타입 — 건너뜀")
            continue
        if tot is None:
            print(f"[coverage] ❌ {label} 커버리지 리포트 없음 — 테스트를 먼저 돌렸는지 확인")
            failed = 1
            continue
        pct = 100.0 if tot == 0 else round(cov / tot * 100, 1)
        ok = pct >= thr
        print(f"[coverage] {'✅' if ok else '❌'} {label} {pct}% (기준 {thr:g}%, 리포트 {len(reps)}개)")
        failed |= 0 if ok else 1
    return failed


def main(argv=None):
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--repo", default=".")
    sub = p.add_subparsers(dest="cmd", required=True)
    sub.add_parser("threshold")
    pc = sub.add_parser("percent")
    pc.add_argument("type")
    pc.add_argument("path")
    sub.add_parser("changed-stacks")
    ck = sub.add_parser("check")
    ck.add_argument("--threshold", type=float)
    ck.add_argument("--base-ref")
    ck.add_argument("--all", action="store_true")
    ck.add_argument("--stack", action="append", type=parse_stack_arg)
    args = p.parse_args(argv)

    if args.cmd == "threshold":
        print(f"{threshold(args.repo):g}")
        return 0
    if args.cmd == "percent":
        v = percent(args.type, os.path.join(args.repo, args.path))
        if v is None:
            print("none")
            return 2
        print(v)
        return 0
    if args.cmd == "changed-stacks":
        _, stacks = load_stacks(args.repo)
        for t, sp in stacks_for_changes(stacks, [l.strip() for l in sys.stdin if l.strip()]):
            print(f"{t}\t{sp}")
        return 0
    return cmd_check(args)


if __name__ == "__main__":
    sys.exit(main())
