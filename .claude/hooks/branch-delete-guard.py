#!/usr/bin/env python3
"""safety-guard.sh 가 부르는 브랜치 삭제 판정. 명령은 환경변수 CMD 로 받는다.

출력: "protected" = dev·main(·master) 를 지우거나 덮어쓰거나 이름을 바꾸려는 명령(무조건 차단)
      "work"      = 끝난 작업 브랜치 삭제만 하는 명령(묻지 않고 허용)
      ""          = 해당 없음(평소 판정)

보호 판정은 셸 단어로 나눈 뒤(따옴표·역슬래시 제거, 대소문자 무시 — macOS 는 ref 파일 이름이
대소문자를 가리지 않는다) 본다. 허용 판정은 반대로 좁게 — 원문 그대로 정해진 모양일 때만.
"""
import os
import re
import shlex

c = os.environ.get("CMD", "")

PROTECTED = re.compile(r"(?:refs/)?(?:heads/)?(?:dev|main|master)", re.I)


def words(segment):
    try:
        return shlex.split(segment, posix=True)
    except ValueError:
        return segment.replace('"', " ").replace("'", " ").split()


def git_args(ws):
    """git [전역 옵션] <하위명령> <인자...> → (하위명령, 인자). git 이 아니면 None."""
    for i, w in enumerate(ws):
        if os.path.basename(w) == "git":
            rest = ws[i + 1:]
            j = 0
            while j < len(rest) and rest[j].startswith("-"):
                j += 2 if rest[j] in ("-C", "-c", "--git-dir", "--work-tree", "--namespace") else 1
            if j < len(rest):
                return rest[j].lower(), rest[j + 1:]
            return None
    return None


def is_protected(tok):
    return bool(PROTECTED.fullmatch(tok))


def protected_segment(ws):
    low = [w.lower() for w in ws]
    if "gh" in low and "api" in low:
        delete = any(
            w in ("-xdelete", "--method=delete") or (w in ("-x", "--method") and k + 1 < len(low) and low[k + 1] == "delete")
            for k, w in enumerate(low)
        )
        if delete and any(re.search(r"(?:git/refs/heads/|branches/)(?:dev|main|master)(?:$|[^\w.-])", w) for w in low):
            return True
    parsed = git_args(ws)
    if not parsed:
        return False
    sub, args = parsed
    flags = [a for a in args if a.startswith("-")]
    pos = [a for a in args if not a.startswith("-")]
    if sub == "push":
        if any(f in ("--mirror", "--prune") or f.startswith("--mirror") for f in flags):
            return True
        if any(f in ("--delete", "-d") for f in flags) and any(is_protected(p) for p in pos):
            return True
        for p in pos:
            if ":" in p:
                src, dst = p.split(":", 1)
                # :dev(삭제) 또는 +x:dev(강제 덮어쓰기)
                if is_protected(dst) and (src.lstrip("+") == "" or src.startswith("+")):
                    return True
        return False
    if sub == "branch":
        destructive = any(f in ("--delete", "--move", "--force") or
                          (not f.startswith("--") and re.search(r"[dDmM]", f[1:])) for f in flags)
        return destructive and any(is_protected(p) for p in pos)
    if sub == "update-ref":
        return "-d" in flags and any(is_protected(p) for p in pos)
    return False


segments = re.split(r"[;&|\n\r]+", c)
if any(protected_segment(words(s)) for s in segments if s.strip()):
    print("protected")
    raise SystemExit

# 허용: 공백(스페이스)으로만 나뉜 원문이 정확히 이 모양일 때만. 탭·개행·따옴표·치환·리다이렉트·단독 & 는 평소 판정으로.
W = r"(?:feature|fix|hotfix|refactor|chore)/[A-Za-z0-9._/-]+"
ONE = (rf"git (?:branch (?:-d|-D|--delete)|push origin (?:--delete|-d))(?: {W})+"
       rf"|git push (?:--delete|-d) origin(?: {W})+")
if re.search(r"[^\x20-\x7e]|[|`$<>()\\'\"]", c):
    raise SystemExit
parts = [p.strip() for p in re.split(r" *(?:&&|;) *", c.strip())]
if parts and all(p and "&" not in p and re.fullmatch(ONE, p) for p in parts):
    print("work")
