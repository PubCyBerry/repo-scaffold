#!/usr/bin/env bash
# 셸 스크립트 정적 분석과 형식 검사.
#
# 대상: 추적 중인 *.sh, *.bash 전부
#   1. shellcheck  정적 분석
#   2. shfmt       형식
#
# shfmt 에 형식 플래그를 주지 않는다. 플래그를 하나라도 주면 shfmt 가 .editorconfig 를
# 통째로 무시해서 훅, CI, 손으로 돌릴 때 기준이 갈린다. 형식 기준은 .editorconfig 하나다.
#
# 도구가 없으면 로컬에서는 SKIP, CI(환경변수 CI=true)에서는 FAIL 이다.
# 로컬에서 커밋을 막으면 --no-verify 가 습관이 되므로 막지 않고, CI 에서 잡는다.
#
# 이 스크립트는 모든 검사를 돌려 결과를 모으므로 set -e 를 쓰지 않는다.
# 예외 근거는 docs/standards/shell.md 에 있다.
#
# 사용법:
#   bash tests/check-shell.sh
#
# 종료 코드: FAIL 이 하나라도 있으면 1, 아니면 0

set -uo pipefail

# cd 뒤에는 상대 경로인 BASH_SOURCE 가 안 풀린다. --help 가 자기 파일을 읽으므로 먼저 절대 경로로 잡는다.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SELF="$SCRIPT_DIR/$(basename "${BASH_SOURCE[0]}")"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT" || exit 1

case "${1:-}" in
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

pass_count=0
fail_count=0
skip_count=0

report() {
    # $1: 판정, $2: 대상, $3: 사유
    case "$1" in
        PASS) pass_count=$((pass_count + 1)) ;;
        FAIL) fail_count=$((fail_count + 1)) ;;
        SKIP) skip_count=$((skip_count + 1)) ;;
    esac
    printf '%-4s %-16s %s\n' "$1" "$2" "${3:-}"
}

# 도구가 있으면 0, 없으면 판정을 남기고 1. CI 에서는 없는 것이 FAIL 이다.
require_tool() {
    # $1: 명령, $2: 설치 명령
    command -v "$1" > /dev/null 2>&1 && return 0
    if [ "${CI:-}" = "true" ]; then
        report FAIL "$1" "미설치. CI 에서는 필수다. 설치: $2"
    else
        report SKIP "$1" "미설치. 설치: $2"
    fi
    return 1
}

FILES=()
while IFS= read -r f; do
    FILES[${#FILES[@]}]="$f"
done < <(git ls-files -- '*.sh' '*.bash' | sort)

if [ "${#FILES[@]}" -eq 0 ]; then
    echo "SKIP 추적 중인 셸 스크립트가 없다"
    exit 0
fi

echo "대상 스크립트: ${#FILES[@]}개"

echo
echo "[1/2] shellcheck"
if require_tool shellcheck "uv tool install shellcheck-py"; then
    if out="$(shellcheck --format=gcc "${FILES[@]}" 2>&1)"; then
        report PASS shellcheck "지적 없음"
    else
        printf '%s\n' "$out"
        report FAIL shellcheck "지적을 전부 고친다. 예외는 사유 주석과 함께 disable 한다"
    fi
fi

echo
echo "[2/2] shfmt"
if require_tool shfmt "uv tool install shfmt-py"; then
    # -l 은 모드 플래그라 .editorconfig 를 무시하지 않는다. 형식 플래그를 주면 안 된다.
    if out="$(shfmt -l "${FILES[@]}" 2>&1)" && [ -z "$out" ]; then
        report PASS shfmt "형식 일치"
    else
        printf '%s\n' "$out"
        report FAIL shfmt "형식 불일치. shfmt -w 로 고친다"
    fi
fi

echo
echo "결과: PASS $pass_count, FAIL $fail_count, SKIP $skip_count"

if [ "$fail_count" -gt 0 ]; then
    echo
    echo "규약: docs/standards/shell.md" >&2
    exit 1
fi
exit 0
