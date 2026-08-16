#!/usr/bin/env bash
# 자동으로 고칠 수 있는 지적을 고친다. 이 스크립트는 파일을 바꾼다.
#
# 대상:
#   1. 문서 인덱스   AGENTS.md 의 인덱스를 저장소 상태로 다시 만든다
#
# 형식 정리는 여기가 아니라 scripts/fmt.sh 다. 형식은 도구가 통째로 다시 쓰고,
# 이쪽은 검사 결과를 근거로 고친다. 나누는 기준이 다르므로 명령도 나눈다.
#
# 고친 뒤에는 반드시 diff 를 확인한다. 자동 수정은 의도를 바꿀 수 있다.
#
# 도구가 없으면 로컬에서는 SKIP, CI(환경변수 CI=true)에서는 FAIL 이다.
#
# 이 스크립트는 모든 단계를 돌려 결과를 모으므로 set -e 를 쓰지 않는다.
# 예외 근거는 docs/standards/shell.md 에 있다.
#
# 사용법:
#   bash scripts/fix.sh
#
# 종료 코드: FAIL 이 하나라도 있으면 1, 알 수 없는 옵션이면 2, 아니면 0

set -uo pipefail

# cd 뒤에는 상대 경로인 BASH_SOURCE 가 안 풀린다. --help 가 자기 파일을 읽으므로 먼저 절대 경로로 잡는다.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SELF="$SCRIPT_DIR/$(basename "${BASH_SOURCE[0]}")"

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

REPO_ROOT="$(git rev-parse --show-toplevel 2> /dev/null)" || {
    echo "FAIL: git 저장소가 아니다" >&2
    exit 1
}
cd "$REPO_ROOT" || exit 1

INDEX_SCRIPT="scripts/gen-doc-index.sh"

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

echo "[1/1] 문서 인덱스"

if [ ! -f "$INDEX_SCRIPT" ]; then
    report SKIP "$INDEX_SCRIPT" "없다. 생성할 인덱스가 없다"
elif out="$(bash "$INDEX_SCRIPT" 2>&1)"; then
    printf '%s\n' "$out"
    report PASS "$INDEX_SCRIPT" "인덱스 반영"
else
    printf '%s\n' "$out"
    report FAIL "$INDEX_SCRIPT" "인덱스를 만들지 못했다"
fi

echo
echo "결과: PASS $pass_count, FAIL $fail_count, SKIP $skip_count"

if [ "$fail_count" -gt 0 ]; then
    exit 1
fi

echo
echo "바뀐 내용을 git diff 로 확인한다"
exit 0
