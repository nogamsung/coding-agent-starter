#!/bin/bash
# .claude/hooks/safety-guard.sh
# PreToolUse(Bash) hook — 위험한 명령 차단·확인 (Claude·Codex 공통)
#
# stacks.json 이 없어도 항상 동작한다(안전 규칙은 스택과 무관).
#
# 차단 대상:
#   - main/master 브랜치에서 git push --force*, git reset --hard, git commit --amend
#   - rm -rf 루트/홈 디렉토리
#   - DROP TABLE, TRUNCATE (모든 상황)
#
#   - dev·main(·master) 브랜치 삭제 — 로컬·GitHub 원격 모두, 묻지도 않고 무조건 차단 (branch-delete-guard.py)
#
# 묻지 않고 허용 (자동 모드 분류기도 건너뜀):
#   - 끝난 작업 브랜치(feature|fix|hotfix|refactor|chore/*) 삭제만 하는 명령 — git branch -d/-D, git push origin --delete
#
# 반드시 사람에게 묻는 대상 (자동 모드·allow 규칙이 있어도):
#   - DB 클라이언트로 데이터·스키마 변경(DELETE·UPDATE·INSERT·ALTER 등, SQL 파일 주입 포함)
#   - redis 키 삭제·변경, flyway clean·repair, 도커 볼륨 삭제·compose down -v
#   - S3·AWS 리소스 삭제, 원격 API DELETE·PUT·PATCH, ssh 원격 명령, force push
#   - GitHub 쓰기: gh secret·variable set/delete, gh workflow run/enable/disable, gh repo·release 변경·run 재실행·취소, gh alias set, gh auth token, gh pr merge --admin,
#     gh api 쓰기(-X DELETE·PUT·PATCH·POST, -f/-F/--input, graphql mutation)
#   Claude 는 permissionDecision "ask" 로 확인 창을 띄운다. Codex 는 PreToolUse ask 를 지원하지 않아
#   차단하고 사용자에게 넘긴다(사용자가 직접 실행).
#
# exit 2 로 차단 메시지 출력 (Claude Code·Codex hook spec 공통).

INPUT=$(cat 2>/dev/null || echo '{}')

CMD=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('tool_input', {}).get('command', ''))
except Exception:
    print('')
" 2>/dev/null || echo '')

# Codex 입력에만 turn_id 가 있다
IS_CODEX=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    print('1' if 'turn_id' in json.load(sys.stdin) else '')
except Exception:
    print('')
" 2>/dev/null || echo '')

[ -z "$CMD" ] && exit 0

# 무조건 차단
case "$CMD" in
  *"rm -rf /"*|*"rm -rf ~"*)
    echo "[SafetyGuard] 차단: rm -rf 루트/홈 디렉토리" >&2
    exit 2
    ;;
  *"DROP TABLE"*|*"TRUNCATE "*|*"DROP DATABASE"*)
    echo "[SafetyGuard] 차단: 파괴적 SQL (DROP TABLE/TRUNCATE/DROP DATABASE)" >&2
    exit 2
    ;;
esac

# 브랜치 삭제 — dev·main 은 무조건 차단, 끝난 작업 브랜치만 지우는 명령은 묻지 않고 허용
BRANCH_DELETE=$(CMD="$CMD" python3 "$(dirname "${BASH_SOURCE[0]}")/branch-delete-guard.py" 2>/dev/null || echo "")
if [ "$BRANCH_DELETE" = "protected" ]; then
  echo "[SafetyGuard] 차단: dev·main 브랜치 삭제는 절대 하지 않는다(로컬·원격 모두). 끝난 작업 브랜치 이름만 지정하라" >&2
  exit 2
fi
if [ "$BRANCH_DELETE" = "work" ] && [ -z "$IS_CODEX" ]; then
  echo '{"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "allow", "permissionDecisionReason": "[SafetyGuard] 끝난 작업 브랜치 삭제 허용(dev·main 아님)"}}'
  exit 0
fi

# Secret 파일 commit 차단 (모든 브랜치) — git commit 시점에 staged 파일 검사
case "$CMD" in
  *"git commit"*)
    if git rev-parse --git-dir &>/dev/null; then
      while IFS= read -r f; do
        [ -z "$f" ] && continue
        BN=$(basename "$f")
        case "$BN" in
          .env|.env.local|.env.production|.env.development|.env.staging|*.pem|*.key|id_rsa|id_dsa|id_ecdsa|id_ed25519|*.p12|*.pfx|credentials.json|.npmrc|.pypirc)
            echo "[SafetyGuard] 차단: secret 파일 commit 시도 ($f)" >&2
            echo "  → echo '$f' >> .gitignore && git rm --cached '$f'" >&2
            echo "  → .env.example / *.pub 같은 예시·공개 파일은 OK" >&2
            exit 2
            ;;
        esac
      done < <(git diff --cached --name-only 2>/dev/null)
    fi
    ;;
esac

# 보호 브랜치 감지
if git rev-parse --git-dir &>/dev/null; then
  BRANCH=$(git branch --show-current 2>/dev/null || echo "")
  case "$BRANCH" in
    main|master|production|release/*)
      case "$CMD" in
        *"git push --force"*|*"git push -f "*|*"git push -f"*)
          echo "[SafetyGuard] 차단: 보호 브랜치($BRANCH)에서 force push" >&2
          exit 2
          ;;
        *"git reset --hard"*)
          echo "[SafetyGuard] 차단: 보호 브랜치($BRANCH)에서 reset --hard — backup 브랜치 먼저 만들어주세요" >&2
          exit 2
          ;;
        *"git commit --amend"*)
          echo "[SafetyGuard] 차단: 보호 브랜치($BRANCH)에서 --amend — 새 커밋으로 대체하세요" >&2
          exit 2
          ;;
        *"git branch -D"*)
          echo "[SafetyGuard] 차단: 보호 브랜치($BRANCH)에서 branch -D" >&2
          exit 2
          ;;
      esac
      ;;
  esac
fi

# 데이터를 지우거나 바꾸는 명령은 사람에게 묻는다
REASON=$(CMD="$CMD" python3 - <<'EOF'
import os, re, shlex

# gh 쓰기 판정 — 명령을 ; && | 단위로 쪼개 gh 호출마다 인자를 해석한다(전역 옵션 -R·붙여 쓴 -XDELETE·-ftitle=x 포함).
GH_WRITES = {
    "secret": {"set", "delete", "remove"}, "variable": {"set", "delete", "remove"},
    "workflow": {"run", "enable", "disable"}, "repo": {"delete", "edit", "rename", "archive", "unarchive"},
    "release": {"create", "edit", "upload", "delete", "delete-asset"}, "cache": {"delete"},
    "run": {"delete", "rerun", "cancel"}, "label": {"delete"}, "alias": {"set", "import"},
    "auth": {"token"},  # 토큰을 꺼내 curl 로 쓰면 위 규칙을 다 비켜 간다
}
# 하위 명령 뒤 인자까지 봐야 하는 쓰기
GH_WRITE_ARGS = [("repo", "deploy-key", {"add", "delete"}), ("pr", "merge", {"--admin"})]
GH_VALUE_FLAGS = {"-R", "--repo", "-H", "--header", "-q", "--jq", "-t", "--template", "--hostname", "-p", "--preview", "--cache"}
FIELD_FLAGS = ("-f", "-F", "--field", "--raw-field", "--input")

def _api_write(args):
    method, fields, field_values, endpoint, i = None, False, [], None, 0
    while i < len(args):
        a = args[i]
        nxt = args[i + 1] if i + 1 < len(args) else ""
        if a in ("-X", "--method"):
            method, i = nxt, i + 2; continue
        if a.startswith("--method="):
            method = a.split("=", 1)[1]
        elif a.startswith("-X") and len(a) > 2:
            method = a[2:]
        elif a in FIELD_FLAGS:
            fields = True; field_values.append("@" if a == "--input" else nxt); i += 2; continue
        elif re.match(r"^(--field|--raw-field|--input)=", a):
            fields = True; field_values.append("@" if a.startswith("--input") else a.split("=", 1)[1])
        elif re.match(r"^-[A-Za-z]*X.", a):  # -XDELETE · -iXDELETE(짧은 옵션 묶음)
            method = a[a.index("X") + 1:]
        elif re.match(r"^-[A-Za-z]*[fF].", a):
            fields = True; field_values.append(a[re.search(r"[fF]", a[1:]).start() + 2:])
        elif a in GH_VALUE_FLAGS:
            i += 2; continue
        elif not a.startswith("-") and endpoint is None:
            endpoint = a
        i += 1
    if endpoint == "graphql":
        # 조회도 -f query= 로 보낸다 — mutation 이거나 파일 입력(@·--input, 내용을 볼 수 없다)이면 쓰기로 본다.
        return any(re.search(r"\bmutation\b", v, re.I) or "=@" in v or v.startswith("@") for v in field_values)
    if method:
        return method.upper() not in ("GET", "HEAD")
    return fields

def gh_write(c):
    try:
        lex = shlex.shlex(c, posix=True, punctuation_chars=";&|")
        lex.whitespace_split = True
        tokens = list(lex)
    except ValueError:
        return bool(re.search(r"\bgh\s", c))
    segments, cur = [], []
    for t in tokens:
        if t and set(t) <= set(";&|"):
            segments.append(cur); cur = []
        else:
            cur.append(t)
    segments.append(cur)
    for seg in segments:
        while seg and (re.match(r"^\w+=", seg[0]) or seg[0] in ("env", "command", "sudo", "exec")):
            seg = seg[1:]
        if not seg or os.path.basename(seg[0]) != "gh":
            continue
        args, rest, i = seg[1:], [], 0
        while i < len(args):  # 전역 옵션 건너뛰기
            if args[i] in ("-R", "--repo"):
                i += 2; continue
            if args[i].startswith("--repo=") or (args[i].startswith("-R") and len(args[i]) > 2):
                i += 1; continue
            rest = args[i:]; break
        if not rest:
            continue
        group = rest[0]
        if group == "api" and _api_write(rest[1:]):
            return True
        if group in GH_WRITES:
            # 하위 명령 앞의 옵션(-R x)을 건너뛴 첫 단어
            tail, j = rest[1:], 0
            while j < len(tail) and tail[j].startswith("-"):
                j += 2 if tail[j] in ("-R", "--repo") else 1
            if j < len(tail) and tail[j] in GH_WRITES[group]:
                return True
        for g, sub, needles in GH_WRITE_ARGS:
            if group == g and sub in rest[1:] and needles & set(rest[rest.index(sub) + 1:]):
                return True
    return False
c = os.environ.get("CMD", "")
I = re.I
db_client = re.search(r"\b(mysql|mariadb|mysqlsh|psql|sqlite3)\b", c, I)
sql_write = re.search(r"\b(DELETE\s+FROM|UPDATE\s+[\x60\w.]+\s+SET|INSERT\s+(IGNORE\s+)?INTO|REPLACE\s+INTO|ALTER\s+TABLE|"
                      r"DROP\s+(INDEX|VIEW|COLUMN|SCHEMA|USER|PROCEDURE|TRIGGER)|RENAME\s+TABLE|CREATE\s+(TABLE|DATABASE|SCHEMA)|GRANT|REVOKE)\b", c, I)
checks = [
    (db_client and (sql_write or re.search(r"(<\s*\S+\.sql|\bsource\s)", c, I)), "DB 데이터·스키마 변경"),
    (re.search(r"\bredis-cli\b.*\b(FLUSHALL|FLUSHDB|DEL|UNLINK|SET|MSET|HSET|HDEL|EXPIRE|RENAME|SREM|ZREM|LPUSH|RPUSH)\b", c, I),
     "redis 키 삭제·변경"),
    (re.search(r"\bflyway\w*\s+(clean|repair)\b|flyway(Clean|Repair)\b", c, I), "flyway clean·repair"),
    (re.search(r"\bdocker\s+(volume\s+(rm|prune)|system\s+prune)|\bdocker[- ]compose\b.*\bdown\b.*(\s-v\b|--volumes)", c),
     "도커 볼륨(데이터) 삭제"),
    (re.search(r"\baws\s+s3\s+(rm|rb)\b|\baws\s+s3\s+sync\b.*--delete|\baws\s+\S+\s+delete-", c), "AWS 리소스·S3 삭제"),
    (re.search(r"\bcurl\b.*(-X\s*|--request\s+)(DELETE|PUT|PATCH)\b", c) and not re.search(r"(localhost|127\.0\.0\.1)", c),
     "원격 API 데이터 변경(DELETE·PUT·PATCH)"),
    (re.search(r"\bcurl\b.*api\.github\.com", c) and re.search(r"(-X\s*|--request\s+)POST\b|\s(-d|--data\S*|-F|--form)[\s=]", c),
     "GitHub API 쓰기(curl POST)"),
    (re.search(r"(^|[;&|(]\s*)ssh\s", c), "ssh 원격 명령"),
    (re.search(r"\bgit\s+push\b.*(\s--force(-with-lease)?\b|\s-f\b)", c), "force push"),
    (gh_write(c), "GitHub 쓰기(시크릿·변수·워크플로 실행·저장소 설정·API 변경)"),
]
for hit, why in checks:
    if hit:
        print(why)
        break
EOF
)

if [ -n "$REASON" ]; then
  if [ -n "$IS_CODEX" ]; then
    echo "[SafetyGuard] 사용자 확인 필요: $REASON — 실행하지 말고 명령과 영향을 사용자에게 보여준 뒤 사용자가 직접 실행하게 하라" >&2
    exit 2
  fi
  REASON="$REASON" python3 -c "
import json, os
print(json.dumps({'hookSpecificOutput': {'hookEventName': 'PreToolUse', 'permissionDecision': 'ask',
  'permissionDecisionReason': '[SafetyGuard] 사용자 확인 필요: ' + os.environ['REASON']}}, ensure_ascii=False))"
fi

exit 0
