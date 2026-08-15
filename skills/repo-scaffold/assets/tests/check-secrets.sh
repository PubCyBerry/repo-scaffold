#!/usr/bin/env bash
# 커밋 대상에 자격 증명이 섞였는지 검사한다.
#
# 지웠다고 사라지지 않는다. 커밋에 한 번 들어간 토큰은 이력에 영구히 남으므로
# 커밋 전에 막는 것이 유일한 방어선이다. 규약: SECURITY.md
#
# 이 스크립트는 값을 절대 출력하지 않는다. 파일명, 줄 번호, 패턴 이름만 보고한다.
#
# 검사 대상:
#   staged 모드 (기본)  git index 에 올라간 내용. pre-commit 훅이 쓴다
#   --all               추적 중인 모든 파일
#
# 예외 처리:
#   *.example, *.sample, *.lock 은 검사하지 않는다
#   줄 끝에 `secret-scan: allow` 주석이 있으면 그 줄은 넘어간다
#
# 사용법:
#   bash tests/check-secrets.sh
#   bash tests/check-secrets.sh --all
#
# 종료 코드: 걸린 게 있으면 1, 아니면 0

set -uo pipefail

# cd 뒤에는 상대 경로인 BASH_SOURCE 가 안 풀린다. --help 가 자기 파일을 읽으므로 먼저 절대 경로로 잡는다.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SELF="$SCRIPT_DIR/$(basename "${BASH_SOURCE[0]}")"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT" || exit 1

MODE="staged"
case "${1:-}" in
    --all) MODE="all" ;;
    -h | --help)
        sed -n '2,/^$/p' "$SELF"
        exit 0
        ;;
    "") ;;
    *)
        echo "알 수 없는 옵션: $1" >&2
        exit 2
        ;;
esac

# 패턴 이름|정규식. 이름만 보고에 쓴다.
PATTERNS=(
    'GitLab PAT|glpat-[A-Za-z0-9_-]{16,}'
    'GitHub token|gh[pousr]_[A-Za-z0-9]{16,}'
    'GitHub fine-grained|github_pat_[A-Za-z0-9_]{20,}'
    'Atlassian token|ATATT[A-Za-z0-9_.=-]{20,}'
    'OpenAI key|sk-[A-Za-z0-9_-]{20,}'
    'AWS access key|AKIA[0-9A-Z]{16}'
    'Slack token|xox[baprs]-[A-Za-z0-9-]{10,}'
    'private key block|-----BEGIN [A-Z ]*PRIVATE KEY-----'
    'JWT|eyJ[A-Za-z0-9_-]{10,}\.eyJ[A-Za-z0-9_-]{10,}\.'
    'hardcoded credential|(password|passwd|secret|api_?key|access_?token)[[:space:]]*[:=][[:space:]]*["'"'"'][^"'"'"']{8,}'
)

fail_count=0
scan_count=0

report_hit() {
    # $1: 파일, $2: 줄 번호 목록, $3: 패턴 이름
    fail_count=$((fail_count + 1))
    printf 'FAIL %-48s %s (line %s)\n' "$1" "$3" "$2"
}

if [ "$MODE" = "staged" ]; then
    FILE_LIST_COMMAND=(git diff --cached --name-only --diff-filter=ACMR)
else
    FILE_LIST_COMMAND=(git ls-files)
fi

FILES=()
while IFS= read -r f; do
    FILES[${#FILES[@]}]="$f"
done < <("${FILE_LIST_COMMAND[@]}")

if [ "${#FILES[@]}" -eq 0 ]; then
    echo "SKIP 검사할 파일이 없다"
    exit 0
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
BODY="$TMP_DIR/body"

for f in "${FILES[@]}"; do
    case "$f" in
        *.example | *.sample | *.lock | *.min.js | *.map) continue ;;
    esac

    if [ "$MODE" = "staged" ]; then
        git show ":$f" > "$BODY" 2> /dev/null || continue
    else
        [ -f "$f" ] || continue
        cp "$f" "$BODY" 2> /dev/null || continue
    fi

    scan_count=$((scan_count + 1))

    for entry in "${PATTERNS[@]}"; do
        pname="${entry%%|*}"
        regex="${entry#*|}"

        # -I 로 바이너리를 건너뛴다. 줄 번호만 남기고 매칭된 내용은 버린다.
        lines="$(grep -InE "$regex" "$BODY" 2> /dev/null \
            | grep -v 'secret-scan: allow' \
            | cut -d: -f1 | tr '\n' ',' | sed 's/,$//')"

        [ -n "$lines" ] && report_hit "$f" "$lines" "$pname"
    done
done

echo "검사 파일: ${scan_count}개"

if [ "$fail_count" -gt 0 ]; then
    cat >&2 << 'EOF'

자격 증명으로 보이는 값이 커밋 대상에 있다. 값은 출력하지 않았다.

  1. 해당 줄을 확인하고 값을 .env 로 옮긴다
  2. 이미 어딘가로 나간 값이면 먼저 폐기하고 재발급한다
  3. 오탐이면 그 줄 끝에 주석으로 secret-scan: allow 를 붙인다

규약: SECURITY.md
EOF
    exit 1
fi

echo "PASS 자격 증명 패턴 없음"
exit 0
