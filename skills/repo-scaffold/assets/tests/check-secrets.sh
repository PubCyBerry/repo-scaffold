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
# 검사 층은 둘이다.
#   1. 패턴 스캔   git 과 grep 만 쓴다. 의존성이 없으므로 항상 돈다
#   2. gitleaks    PATH 에 있을 때만 한 층 더 얹는다. 규칙은 .gitleaks.toml 이다
#
# gitleaks 는 CI 전용 도구다. tools.txt 에 없고 없어도 FAIL 로 올리지 않는다.
# CI 에서도 마찬가지다. 권위 있는 전체 이력 스캔은 CI 의 전용 잡이 따로 돌리고,
# 이 스크립트는 그 잡을 대신하지 않는다. 없다고 커밋을 막으면 --no-verify 가 습관이 된다.
#
# 도구가 없는 것과 .gitleaks.toml 이 없는 것은 다르다. 앞은 기계의 성질이고 뒤는 저장소의
# 결함이다. 설정 파일이 사라지면 검사는 계속 초록 불이므로 CI 에서는 FAIL 로 올린다.
#
# 예외 처리:
#   *.example, *.sample, *.lock 은 검사하지 않는다
#   줄 끝에 `secret-scan: allow` 주석이 있으면 그 줄은 넘어간다
#   gitleaks 의 같은 장치는 `#gitleaks:allow` 다. 예외 목록은 .gitleaks.toml 에 있다
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

# 스크립트 위치가 아니라 git 이 루트를 정한다. tests/ 를 옮겨도 따라온다.
REPO_ROOT="$(git rev-parse --show-toplevel 2> /dev/null)" || {
    echo "FAIL: git 저장소가 아니다" >&2
    exit 1
}
cd "$REPO_ROOT" || exit 1

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

report_fail() {
    # $1: 대상, $2: 사유
    fail_count=$((fail_count + 1))
    printf 'FAIL %-48s %s\n' "$1" "$2"
}

report_hit() {
    # $1: 파일, $2: 줄 번호 목록, $3: 패턴 이름
    report_fail "$1" "$(printf '%s (line %s)' "$3" "$2")"
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

# --- gitleaks -----------------------------------------------------------------
# 있으면 한 층 더 얹는다. 없으면 넘어간다. 규칙 수백 종과 엔트로피 판정은 위 패턴 10종이
# 못 잡는 것을 잡는다. 설정은 .gitleaks.toml 이고 CI 도 같은 파일을 쓴다.
# staged 모드는 index 만, --all 은 작업 트리를 본다. 둘 다 gitignore 대상은 건너뛴다.

GITLEAKS_CONFIG=".gitleaks.toml"

# 설정 파일 검사가 먼저다. 도구가 있는지부터 물으면, 도구가 없는 기계에서는 설정이
# 사라진 사실을 영영 알아채지 못한다. CI 에서 이 스크립트는 gitleaks 를 깔기 전에 도는
# 잡에서도 불리므로, 순서가 반대면 이 판정은 어디서도 못 나온다.
# 도구가 없는 것은 기계의 성질이고 설정 파일이 없는 것은 저장소의 결함이다.
if [ ! -f "$GITLEAKS_CONFIG" ]; then
    if [ "${CI:-}" = "true" ]; then
        report_fail gitleaks "$GITLEAKS_CONFIG 가 없다. 규칙이 저장소에 있어야 한다"
    else
        echo "SKIP gitleaks $GITLEAKS_CONFIG 가 없다"
    fi
elif ! command -v gitleaks > /dev/null 2>&1; then
    echo "SKIP gitleaks 미설치. CI 전용 도구다. 패턴 스캔만 돌았다"
    bash scripts/tool-help.sh gitleaks
else
    if [ "$MODE" = "staged" ]; then
        GITLEAKS_ARGS=(git --staged)
    else
        GITLEAKS_ARGS=(dir)
    fi
    # -v 가 없으면 gitleaks 는 "leaks found: 1" 한 줄만 낸다. 규칙도 파일도 줄도 없어서
    # 무엇을 고쳐야 하는지 알 수 없다. --redact 가 값을 가리므로 -v 를 켜도 값은 안 나온다.
    if out="$(gitleaks "${GITLEAKS_ARGS[@]}" --no-banner -v --redact \
        --config "$GITLEAKS_CONFIG" . 2>&1)"; then
        echo "PASS gitleaks 지적 없음"
    else
        printf '%s\n' "$out"
        report_fail gitleaks "위 지적에 규칙 이름과 파일과 줄이 있다. 값은 가려져 있다"
    fi
fi

if [ "$fail_count" -gt 0 ]; then
    cat >&2 << 'EOF'

자격 증명으로 보이는 값이 커밋 대상에 있다. 값은 출력하지 않았다.

  1. 해당 줄을 확인하고 값을 .env 로 옮긴다
  2. 이미 어딘가로 나간 값이면 먼저 폐기하고 재발급한다
  3. 오탐이면 그 줄 끝에 주석으로 secret-scan: allow 를 붙인다.
     gitleaks 지적이면 같은 줄에 #gitleaks:allow 도 붙인다

규약: SECURITY.md
EOF
    exit 1
fi

echo "PASS 자격 증명 패턴 없음"
exit 0
