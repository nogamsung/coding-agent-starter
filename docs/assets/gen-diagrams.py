#!/usr/bin/env python3
"""README 애니메이션 다이어그램 생성기.

    python3 docs/assets/gen-diagrams.py

docs/assets/{name}-{ko|en}-{light|dark}.svg 를 만든다. README 는 <picture> 로
GitHub 테마에 맞는 파일을 고른다. 다이어그램 문구를 바꿀 땐 이 파일만 고치고 다시 돌린다.
docs/ 는 bootstrap.sh 가 복사하지 않으므로 사용자 프로젝트에 배포되지 않는다.
"""
from pathlib import Path
from xml.sax.saxutils import escape

OUT = Path(__file__).resolve().parent

THEMES = {
    "light": dict(
        bg="#ffffff", card="#f6f8fa", line="#d0d7de", text="#1f2328", muted="#59636e",
        claude="#c15f3c", codex="#6e56cf", green="#1a7f37", red="#cf222e", blue="#0969da",
        tint_claude="#fbeee8", tint_codex="#f0edfc", tint_green="#e6f4ea", tint_blue="#e7f0fb",
    ),
    "dark": dict(
        bg="#0d1117", card="#161b22", line="#30363d", text="#e6edf3", muted="#9198a1",
        claude="#e8916f", codex="#a08bff", green="#3fb950", red="#f85149", blue="#4493f8",
        tint_claude="#3a2219", tint_codex="#251f3d", tint_green="#11291a", tint_blue="#0f2340",
    ),
}

SANS = "-apple-system,BlinkMacSystemFont,'Segoe UI','Apple SD Gothic Neo','Noto Sans KR',sans-serif"
MONO = "ui-monospace,SFMono-Regular,Menlo,Consolas,monospace"


def t(x, y, s, size=13, fill="text", weight=400, anchor="start", mono=False, cls=""):
    fam = MONO if mono else SANS
    c = f' class="{cls}"' if cls else ""
    return (f'<text x="{x}" y="{y}" font-family="{fam}" font-size="{size}" font-weight="{weight}" '
            f'fill="var(--{fill})" text-anchor="{anchor}"{c}>{escape(s)}</text>')


def rect(x, y, w, h, fill="card", stroke="line", r=10, sw=1, extra=""):
    return (f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{r}" fill="var(--{fill})" '
            f'stroke="var(--{stroke})" stroke-width="{sw}" {extra}/>')


def svg(w, h, title, body, css):
    def vars_(p):
        return ";".join(f"--{k}:{v}" for k, v in p.items())
    return f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {w} {h}" width="{w}" height="{h}" role="img" aria-label="{escape(title)}">
<title>{escape(title)}</title>
<style>
svg{{{{VARS}}}}
{css}
@media (prefers-reduced-motion: reduce){{ *{{animation:none !important}} .motion{{display:none}} }}
</style>
<rect width="{w}" height="{h}" rx="14" fill="var(--bg)" stroke="var(--line)"/>
{body}
</svg>
""", vars_


def seq_keyframes(name, i, n, hold=0.8):
    """i 번째(0-base) 단계가 n 단계 사이클 중 자기 구간에만 켜지는 keyframes."""
    seg = 100 / n
    a = i * seg
    b = a + seg * hold
    pts = [(0, 0)]
    if a > 0:
        pts.append((max(a - 0.01, 0), 0))
    pts += [(a + 2, 1), (b, 1), (min(b + 3, 100), 0), (100, 0)]
    if a == 0:
        pts[0] = (0, 0)
    body = " ".join(f"{p:.2f}%{{opacity:{o}}}" for p, o in pts)
    return f"@keyframes {name}{{{body}}}"


def accum_keyframes(name, i, n, end=88):
    """i 번째 단계부터 켜져서 사이클 끝(end%)까지 유지."""
    a = (i + 1) * end / (n + 1)
    return (f"@keyframes {name}{{0%{{opacity:0}} {a:.2f}%{{opacity:0}} {a + 2:.2f}%{{opacity:1}} "
            f"{end}%{{opacity:1}} {end + 4}%{{opacity:0}} 100%{{opacity:0}}}}")


# ---------------------------------------------------------------- 1. architecture
def architecture(L):
    W, H = 880, 452
    ko = L == "ko"
    sources = [
        ("AGENTS.md", "지침 한 파일" if ko else "one instruction file"),
        (".agents/skills/", "skill 원본" if ko else "skill sources"),
        (".claude/agents/*.md", "subagent 원본" if ko else "subagent sources"),
        (".claude/hooks/", "훅 스크립트 한 벌" if ko else "one set of hook scripts"),
    ]
    claude_rows = [
        ("AGENTS.md", "직접 읽음" if ko else "read directly"),
        (".claude/skills →", "심볼릭 링크" if ko else "symlink"),
        (".claude/agents/*.md", "그대로" if ko else "as is"),
        ("settings.json", "→ 훅 호출" if ko else "→ calls hooks"),
    ]
    codex_rows = [
        ("AGENTS.md", "직접 읽음" if ko else "read directly"),
        (".agents/skills/", "직접 읽음" if ko else "read directly"),
        (".codex/agents/*.toml", "생성물" if ko else "generated"),
        ("hooks.json", "→ adapter → 훅" if ko else "→ adapter → hooks"),
    ]
    b = []
    b.append(t(30, 38, "규칙은 한 벌, 배선만 플랫폼별" if ko else "One set of rules, per-platform wiring",
               17, weight=650))
    # source column
    b.append(rect(30, 60, 300, 280, sw=1.5))
    b.append(t(48, 86, "원본 (여기만 고친다)" if ko else "Source (edit only here)", 13, "muted", 600))
    for i, (path, desc) in enumerate(sources):
        y = 100 + i * 58
        b.append(rect(46, y, 268, 48, fill="bg"))
        b.append(t(60, y + 21, path, 13, mono=True, weight=600))
        b.append(t(60, y + 38, desc, 12, "muted"))
    # platform cards
    for (name, color, tint, rows, y, k) in [
        ("Claude Code", "claude", "tint_claude", claude_rows, 60, 0),
        ("Codex", "codex", "tint_codex", codex_rows, 212, 1),
    ]:
        b.append(rect(510, y, 340, 136, fill=tint, stroke=color, sw=1.5))
        b.append(t(528, y + 26, name, 15, color, 700))
        for j, (p, d) in enumerate(rows):
            yy = y + 50 + j * 22
            b.append(t(528, yy, p, 12, mono=True))
            b.append(t(700, yy, d, 12, "muted"))
        # flow arrow from source to card
        ay = y + 68
        b.append(f'<path d="M330 {ay} H500" stroke="var(--line)" stroke-width="2" fill="none"/>')
        b.append(f'<path d="M330 {ay} H500" stroke="var(--{color})" stroke-width="2.5" fill="none" '
                 f'stroke-dasharray="10 160" class="flow motion" style="animation-delay:{k * 0.6}s"/>')
        b.append(f'<path d="M494 {ay - 5} L502 {ay} L494 {ay + 5}" stroke="var(--{color})" '
                 f'stroke-width="2" fill="none"/>')
    # gen arrow label
    b.append(t(415, 270, "gen-codex-agents.py", 11, "muted", anchor="middle", mono=True))
    # git hooks band
    b.append(rect(30, 372, 820, 58, fill="tint_green", stroke="green", sw=1.5))
    b.append(t(48, 397, ".claude/githooks/", 13, "green", 700, mono=True))
    b.append(t(48, 417, "pre-commit · pre-push — Claude · Codex · 터미널 어디서 커밋·push 해도 같은 게이트" if ko else
               "pre-commit · pre-push — the same gate whether you commit/push from Claude, Codex, or a terminal",
               12, "text"))
    for x, color in [(600, "claude"), (760, "codex")]:
        b.append(f'<path d="M{x} 340 V366" stroke="var(--{color})" stroke-width="2" fill="none" '
                 f'stroke-dasharray="4 4"/>')
    css = (".flow{animation:flow 2.4s linear infinite}"
           "@keyframes flow{from{stroke-dashoffset:170}to{stroke-dashoffset:0}}")
    return W, H, ("규칙 한 벌을 Claude Code 와 Codex 가 함께 읽는 구조" if ko else
                  "One rule set read by both Claude Code and Codex"), "\n".join(b), css


# ---------------------------------------------------------------- 2. workflow
def workflow(L):
    W, H = 880, 270
    ko = L == "ko"
    steps = [
        ("/start", ["worktree + PRD", "+ 자동 구현" if ko else "+ auto-implement"], "blue"),
        ("/commit", ["Conventional", "Commits"], "blue"),
        ("/pr", ["보안 리뷰" if ko else "security review", "+ 교차 리뷰" if ko else "+ cross review"], "codex"),
        ("CI", ["같은 판정으로" if ko else "same verdict", "재검증" if ko else "re-checked"], "green"),
        ("/merge", ["squash 머지" if ko else "squash merge", "+ 버전 태그" if ko else "+ version tag"], "claude"),
        ("정리" if ko else "cleanup", ["worktree 정리" if ko else "worktree removed", "브랜치 삭제" if ko else "branches deleted"], "green"),
    ]
    n = len(steps)
    w, gap, x0, y = 124, 16, 30, 92
    T = 9
    b = [t(30, 38, "기능 하나의 흐름" if ko else "One feature, end to end", 17, weight=650),
         t(30, 60, "각 단계가 다음 단계를 제안 — 수락하면 이어서 실행" if ko else
           "Each step proposes the next — accept to continue", 12, "muted")]
    cx = [x0 + i * (w + gap) + w / 2 for i in range(n)]
    b.append(f'<path d="M{cx[0]} {y + 50} H{cx[-1]}" stroke="var(--line)" stroke-width="2"/>')
    css = [".lit{opacity:0}"]
    for i, (cmd, lines, color) in enumerate(steps):
        x = x0 + i * (w + gap)
        b.append(rect(x, y, w, 100, fill="card"))
        b.append(rect(x, y, w, 100, fill="bg", stroke=color, sw=2.5,
                      extra=f'class="lit motion" style="animation:s{i} {T}s infinite"'))
        b.append(t(x + w / 2, y + 30, cmd, 15, color, 700, "middle", mono=True))
        for j, ln in enumerate(lines):
            b.append(t(x + w / 2, y + 56 + j * 18, ln, 12, "muted", anchor="middle"))
        css.append(seq_keyframes(f"s{i}", i, n))
    # moving dot
    kf = []
    for i in range(n):
        p = i * 100 / n
        kf.append(f"{p + 1:.2f}%{{transform:translateX({cx[i] - cx[0]}px)}}")
        kf.append(f"{p + 100 / n * 0.8:.2f}%{{transform:translateX({cx[i] - cx[0]}px)}}")
    css.append("@keyframes dot{" + " ".join(kf) + "}")
    css.append(f".dot{{animation:dot {T}s infinite ease-in-out}}")
    b.append(f'<g class="dot motion"><circle cx="{cx[0]}" cy="{y + 112}" r="5" fill="var(--blue)"/></g>')
    b.append(t(30, 248, "PR 머지가 끝나면 원격·로컬 작업 브랜치와 worktree 까지 정리됩니다." if ko else
               "After the merge, remote and local work branches and the worktree are cleaned up.", 12, "muted"))
    return W, H, ("기능 하나의 흐름: /start → /commit → /pr → CI → /merge → 정리" if ko else
                  "Feature flow: /start → /commit → /pr → CI → /merge → cleanup"), "\n".join(b), "\n".join(css)


# ---------------------------------------------------------------- 3. hooks timeline
def hooks(L):
    W, H = 880, 330
    ko = L == "ko"
    stages = [
        ("세션 시작" if ko else "Session start", [("session-start", "blue"), ("memory-sync*", "muted")]),
        ("도구 호출 전" if ko else "Before a tool", [("safety-guard", "red"), ("worktree-guard", "red"),
                                                    ("pre-push", "red")]),
        ("도구 호출 후" if ko else "After a tool", [("post-edit-lint", "blue"), ("usage-counter*", "muted")]),
        ("턴 종료" if ko else "Turn end", [("stop-tests", "green"), ("memory-sync*", "muted")]),
    ]
    n = len(stages)
    T = 8
    x0, w, gap = 30, 194, 14
    b = [t(30, 38, "한 턴 동안 훅이 도는 시점" if ko else "When hooks run during a turn", 17, weight=650),
         t(30, 60, "빨강 = 위험하면 막음 · 초록 = 결과만 알림 · * = 기본 off (stacks.json harness 로 켬)" if ko else
           "red = blocks when risky · green = reports only · * = off by default (enable in stacks.json harness)",
           12, "muted")]
    ly = 112
    b.append(f'<path d="M{x0} {ly} H{W - 30}" stroke="var(--line)" stroke-width="2"/>')
    css = []
    for i, (name, chips) in enumerate(stages):
        x = x0 + i * (w + gap)
        b.append(f'<circle cx="{x + 12}" cy="{ly}" r="6" fill="var(--bg)" stroke="var(--muted)" stroke-width="2"/>')
        b.append(t(x + 2, ly - 14, name, 13, weight=650))
        for j, (chip, color) in enumerate(chips):
            yy = ly + 28 + j * 44
            b.append(rect(x, yy, w, 34, fill="card", r=8))
            b.append(rect(x, yy, w, 34, fill="bg", stroke=color, r=8, sw=2,
                          extra=f'class="motion" style="opacity:0;animation:h{i} {T}s infinite"'))
            b.append(t(x + 14, yy + 22, chip + ".sh" if not chip.endswith("*") else chip[:-1] + ".sh *",
                       12, color if color != "muted" else "muted", 600, mono=True))
        css.append(seq_keyframes(f"h{i}", i, n, hold=0.85))
    # playhead
    kf = []
    for i in range(n):
        x = i * (w + gap)
        p = i * 100 / n
        kf.append(f"{p + 1:.2f}%{{transform:translateX({x}px)}}")
        kf.append(f"{p + 100 / n * 0.85:.2f}%{{transform:translateX({x}px)}}")
    css.append("@keyframes ph{" + " ".join(kf) + "}")
    css.append(f".ph{{animation:ph {T}s infinite ease-in-out}}")
    b.append(f'<g class="ph motion"><circle cx="{x0 + 12}" cy="{ly}" r="6" fill="var(--blue)"/></g>')
    b.append(t(30, 300, "Codex 에는 턴 종료 이벤트가 없어 stop-tests 는 Claude 에서만 돕니다. push 게이트는 git 훅이라 둘 다 적용됩니다." if ko else
               "Codex has no turn-end event, so stop-tests runs in Claude only. The push gate is a git hook, so it applies to both.",
               12, "muted"))
    return W, H, ("한 턴 동안 훅이 도는 시점" if ko else "When hooks run during a turn"), "\n".join(b), "\n".join(css)


# ---------------------------------------------------------------- 4. push gate
def push_gate(L):
    W, H = 880, 250
    ko = L == "ko"
    stages = [
        ("git push", None),
        ("빌드" if ko else "Build", "build-gate.sh"),
        ("변경 범위 테스트" if ko else "Scoped tests", "build-gate.sh"),
        ("커버리지 ≥ 90%" if ko else "Coverage ≥ 90%", "coverage-gate.py"),
        ("push 통과" if ko else "Push allowed", None),
    ]
    n = len(stages)
    T = 7
    w, gap, x0, y = 150, 17, 30, 82
    b = [t(30, 38, "push 게이트" if ko else "The push gate", 17, weight=650),
         t(30, 60, "하나라도 실패하면 push 를 막습니다 (exit 2). CI 는 같은 스크립트로 다시 판정합니다." if ko else
           "Any failure blocks the push (exit 2). CI re-runs the same script for the same verdict.", 12, "muted")]
    css = []
    for i, (name, script) in enumerate(stages):
        x = x0 + i * (w + gap)
        last = i == n - 1
        color = "green" if last else ("text" if i == 0 else "blue")
        b.append(rect(x, y, w, 76, fill="tint_green" if last else "card",
                      stroke="green" if last else "line", sw=1.5 if last else 1))
        b.append(t(x + w / 2, y + (32 if script else 43), name, 14, color, 700, "middle", mono=(i == 0)))
        if script:
            b.append(t(x + w / 2, y + 54, script, 11, "muted", anchor="middle", mono=True))
        if 0 < i < n - 1:
            b.append(f'<g class="motion" style="opacity:0;animation:c{i} {T}s infinite">'
                     f'<circle cx="{x + w - 14}" cy="{y + 14}" r="9" fill="var(--green)"/>'
                     f'<path d="M{x + w - 18} {y + 14} l3 3 l6 -6" stroke="var(--bg)" stroke-width="2" fill="none"/></g>')
            css.append(accum_keyframes(f"c{i}", i - 1, n - 2))
        if i < n - 1:
            ax = x + w
            b.append(f'<path d="M{ax + 2} {y + 38} H{ax + gap - 3}" stroke="var(--muted)" stroke-width="2"/>')
        if 0 < i < n - 1:
            # fail path
            fx = x + w / 2
            b.append(f'<path d="M{fx} {y + 76} V{y + 104}" stroke="var(--red)" stroke-width="1.5" stroke-dasharray="3 3"/>')
    b.append(rect(x0 + w + gap, y + 104, 2 * w + 3 * gap + w - gap, 34, fill="bg", stroke="red", r=8,
                  extra='stroke-dasharray="4 3"'))
    b.append(t(x0 + w + gap + 14, y + 126, "✕ 실패 → push 차단, 원인 출력 (tail)" if ko else
               "✕ failure → push blocked, cause printed (tail)", 12, "red", 600))
    b.append(f'<rect x="{x0 + (n - 1) * (w + gap)}" y="{y}" width="{w}" height="76" rx="10" fill="none" '
             f'stroke="var(--green)" stroke-width="3" class="motion" style="opacity:0;animation:okp {T}s infinite"/>')
    css.append("@keyframes okp{0%{opacity:0} 70%{opacity:0} 73%{opacity:1} 88%{opacity:1} 92%{opacity:0} 100%{opacity:0}}")
    return W, H, ("push 게이트: 빌드 → 테스트 → 커버리지" if ko else
                  "Push gate: build → tests → coverage"), "\n".join(b), "\n".join(css)


def main():
    for name, fn in [("architecture", architecture), ("workflow", workflow), ("hooks", hooks),
                     ("push-gate", push_gate)]:
        for lang in ("ko", "en"):
            W, H, title, body, css = fn(lang)
            for theme, pal in THEMES.items():
                doc, vars_ = svg(W, H, title, body, css)
                doc = doc.replace("{VARS}", vars_(pal))
                (OUT / f"{name}-{lang}-{theme}.svg").write_text(doc, encoding="utf-8")
    print("ok:", len(list(OUT.glob("*.svg"))), "svg files in", OUT)


if __name__ == "__main__":
    main()
