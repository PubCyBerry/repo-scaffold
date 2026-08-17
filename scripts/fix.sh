#!/usr/bin/env bash
# 자동으로 고칠 수 있는 지적을 고친다. 이 스크립트는 파일을 바꾼다.
#
# 대상:
#   1. 문서 인덱스   AGENTS.md 의 인덱스를 저장소 상태로 다시 만든다
#   2. ruff         자동으로 고칠 수 있는 파이썬 지적을 고친다
#
# 형식 정리는 여기가 아니라 scripts/fmt.sh 다. 형식은 도구가 통째로 다시 쓰고,
# 이쪽은 검사 결과를 근거로 고친다. 나누는 기준이 다르므로 명령도 나눈다.
#
# ruff 는 --fix 만 준다. --unsafe-fixes 는 주지 않는다. 이름 그대로 의미를 바꿀 수
# 있는 수정이고, 그런 것은 사람이 판단할 일이다.
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
    printf '%-4s %-24s %s\n' "$1" "$2" "${3:-}"
}

# 파이썬 도구는 프로젝트 의존성이라 PATH 에 없다. pyproject.toml 과 uv.lock 과 uv 가
# 모두 있으면 잠긴 버전으로 부른다. tests/check-python.sh 와 같은 규칙이다.
# 빈 배열을 확장하면 set -u 에서 터지므로 PATH 쪽에는 무해한 command 를 둔다.
PY_RUNNER=(command)
if [ -f pyproject.toml ] && [ -f uv.lock ] && command -v uv > /dev/null 2>&1; then
    PY_RUNNER=(uv run --frozen)
fi

# 파이썬 도구가 있으면 0, 없으면 판정을 남기고 1. CI 에서는 없는 것이 FAIL 이다.
require_py_tool() {
    # $1: 명령
    "${PY_RUNNER[@]}" "$1" --version > /dev/null 2>&1 && return 0
    if [ "${CI:-}" = "true" ]; then
        report FAIL "$1" "미설치. CI 에서는 필수다. 설치: uv sync"
    else
        report SKIP "$1" "미설치. 설치: uv sync"
    fi
    return 1
}

echo "[1/2] 문서 인덱스"

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
echo "[2/2] ruff check --fix"

PY_FILES=()
while IFS= read -r f; do
    PY_FILES[${#PY_FILES[@]}]="$f"
done < <(git ls-files -- '*.py' '*.pyi' | sort)

if [ "${#PY_FILES[@]}" -eq 0 ]; then
    report SKIP "ruff check --fix" "추적 중인 파이썬 파일이 없다"
elif require_py_tool ruff; then
    # 고칠 수 없는 지적이 남으면 ruff 가 1 로 끝난다. 그것은 이 스크립트의 실패가
    # 아니라 사람이 손으로 고칠 몫이다. 검사는 tests/check-python.sh 가 한다.
    # 2 이상은 ruff 자체가 못 돈 것이므로 그때만 FAIL 이다.
    out="$("${PY_RUNNER[@]}" ruff check --fix --output-format=concise "${PY_FILES[@]}" 2>&1)"
    rc=$?
    printf '%s\n' "$out"
    case "$rc" in
        0) report PASS "ruff check --fix" "남은 지적 없음" ;;
        1) report PASS "ruff check --fix" "고칠 수 없는 지적이 남았다. 손으로 고친다" ;;
        *) report FAIL "ruff check --fix" "ruff 종료 코드 $rc" ;;
    esac
fi

echo
echo "결과: PASS $pass_count, FAIL $fail_count, SKIP $skip_count"

if [ "$fail_count" -gt 0 ]; then
    exit 1
fi

echo
echo "바뀐 내용을 git diff 로 확인한다"
exit 0
