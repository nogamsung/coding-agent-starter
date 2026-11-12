#!/usr/bin/env python3
""".claude/scripts/gen-codex-agents.py — .claude/agents/*.md(원본) → .codex/agents/*.toml(Codex 서브에이전트)

서브에이전트 정의는 Claude 형식 하나만 손으로 고친다. Codex 용 TOML 은 이 스크립트가 만든다.
  python3 .claude/scripts/gen-codex-agents.py          # 생성·갱신 (원본에 없는 toml 은 지움) — 모델도 계정 카탈로그 최신으로
  python3 .claude/scripts/gen-codex-agents.py --check  # 어긋나면 exit 1 (모델은 계열만 비교 — 버전은 안 본다)
  python3 .claude/scripts/gen-codex-agents.py --check --index  # 스테이징된 내용끼리 비교 (pre-commit 이 쓴다)

model 별칭은 같은 등급의 Codex 계열로 옮긴다(fable→astra · opus→sol · sonnet→terra · haiku→luna, scripts/codex_models.py).
Codex 는 별칭을 못 받고 정확한 슬러그만 받으므로 TOML 에는 슬러그가 적히는데, 그 버전은 이 스크립트가 돌 때
계정 모델 카탈로그 캐시에서 계열의 최신을 골라 채운다 — 원본에는 버전이 없고, 재생성하면 최신으로 따라간다.
캐시가 없으면(CI 등) 지금 TOML 의 같은 계열 값을 두고, 그것도 없으면 FALLBACK. --check 는 계열만 본다.
추론 강도는 원본 frontmatter 의 `effort:` 를 그대로 옮긴다(Claude·Codex 같은 값, 별칭이 있으면 필수) — 파일에
모델만 있으면 부모 세션의 강도를 물려받는데, 계열마다 지원 범위가 달라(luna 는 ultra 불가) 실패한다(실측).
-routed.toml 은 같은 역할 지침에 모델·강도를 뺀 변형이다 — 파일 값이 spawn 인자보다 우선이라, 모델을 직접 지정해 spawn 할 때와 Jev 라우터가 쓴다.
tools 는 옮기지 않는다 — Codex 는 샌드박스로 권한을 제한한다.
"""
import json
import pathlib
import re
import subprocess
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import codex_models  # noqa: E402

ROOT = pathlib.Path(__file__).resolve().parents[2]  # .claude/scripts → 저장소 루트
SRC = ROOT / ".claude" / "agents"
DST = ROOT / ".codex" / "agents"
EFFORTS = {"low", "medium", "high", "xhigh", "max"}  # Claude frontmatter effort 값 — Codex 도 같은 이름
HEADER = "# 자동 생성 — 고치지 마라. 원본: .claude/agents/{name}.md → python3 .claude/scripts/gen-codex-agents.py\n"
MODEL_LINE = re.compile(r'^model = "([^"]*)"$', re.M)


def git_index(pattern: str) -> dict:
    """인덱스(스테이징 영역)의 파일 이름 → 내용. 실제로 커밋될 것끼리 비교하려고 쓴다."""
    names = subprocess.run(["git", "ls-files", "-z", "--", pattern], cwd=ROOT, capture_output=True, check=True).stdout
    out = {}
    for rel in filter(None, names.decode().split("\0")):
        blob = subprocess.run(["git", "show", ":" + rel], cwd=ROOT, capture_output=True, check=True).stdout
        out[pathlib.PurePosixPath(rel).name] = blob.decode("utf-8")
    return out


def parse(md: pathlib.Path, text: str = None):
    text = md.read_text(encoding="utf-8") if text is None else text
    if not text.startswith("---\n"):
        raise SystemExit(f"{md}: frontmatter 없음")
    head, body = text[4:].split("\n---\n", 1)
    meta = {}
    for line in head.splitlines():
        if ":" in line and not line.startswith(" "):
            k, v = line.split(":", 1)
            meta[k.strip()] = v.strip().strip('"').strip("'")
    return meta, body.strip() + "\n"


def toml_str(s: str) -> str:
    # 여러 줄 리터럴('''…''')이 읽기 좋다. 본문에 ''' 가 있으면 JSON 문자열(= 유효한 TOML 기본 문자열)로
    if "'''" not in s:
        return "'''\n" + s + "'''"
    return json.dumps(s, ensure_ascii=False)


def current_model(toml_text: str):
    match = MODEL_LINE.search(toml_text or "")
    return match.group(1) if match else None


def render(md: pathlib.Path, text: str = None, routed: bool = False, current: str = None) -> tuple:
    meta, body = parse(md, text)
    name = (meta.get("name") or md.stem) + ("-routed" if routed else "")
    if routed:
        meta["description"] = "Same role without a pinned model/effort — use only when spawning with an explicit model (or via the model router); otherwise select the original role. " + meta.get("description", "")
    out = [HEADER.format(name=md.stem), f"name = {json.dumps(name, ensure_ascii=False)}",
           f"description = {json.dumps(meta.get('description', ''), ensure_ascii=False)}"]
    alias = meta.get("model", "")
    family = codex_models.FAMILIES.get(alias)
    if family and not routed:
        effort = meta.get("effort", "")
        if effort not in EFFORTS:
            raise SystemExit(f"{md}: model 별칭이 있으면 effort 도 필수 ({'·'.join(sorted(EFFORTS))}), 지금 {effort!r}")
        out.append(f"model = {json.dumps(codex_models.newest(family, current=current))}")  # 환경변수 덮어쓰기 값도 이스케이프
        out.append(f'model_reasoning_effort = "{effort}"')
    out.append(f"developer_instructions = {toml_str(body)}")
    return f"{md.stem}{'-routed' if routed else ''}.toml", "\n".join(out) + "\n"


def same_family(a: str, b: str) -> bool:
    """모델 줄은 계열만 같으면 같은 것으로 본다 — 버전은 생성한 머신의 카탈로그에 따라 다르다."""
    norm = lambda t: MODEL_LINE.sub(lambda m: f'model = "{codex_models.family_of(m.group(1))}"', t or "")
    return norm(a) == norm(b)


def main() -> int:
    check = "--check" in sys.argv[1:]
    if "--index" in sys.argv[1:]:
        have = git_index(".codex/agents/*.toml")
        sources = sorted(git_index(".claude/agents/*.md").items())
        want = dict(render(pathlib.Path(n), t, routed, current_model(have.get(f"{pathlib.Path(n).stem}.toml")))
                    for n, t in sources for routed in (False, True))
    else:
        have = {p.name: p.read_text(encoding="utf-8") for p in DST.glob("*.toml")} if DST.exists() else {}
        want = dict(render(md, routed=routed, current=current_model(have.get(f"{md.stem}.toml")))
                    for md in sorted(SRC.glob("*.md")) for routed in (False, True))
    extra = sorted(n for n in have if n not in want)
    if check:
        stale = sorted(n for n in want if not same_family(have.get(n), want[n]))
        if stale or extra:
            print("[codex-agents] .codex/agents 가 .claude/agents 와 어긋남: " + ", ".join(stale + extra), file=sys.stderr)
            print("  → python3 .claude/scripts/gen-codex-agents.py 실행 후 .codex/agents 도 git add", file=sys.stderr)
            return 1
        return 0
    stale = sorted(n for n in want if have.get(n) != want[n])
    DST.mkdir(parents=True, exist_ok=True)
    for n in stale:
        (DST / n).write_text(want[n], encoding="utf-8")
    for n in extra:
        (DST / n).unlink()
    print(f"[codex-agents] 갱신 {len(stale)} · 삭제 {len(extra)} · 전체 {len(want)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
