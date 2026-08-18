#!/usr/bin/env bash
# 테스트 실행. 실행기는 pytest 다.
#
# 갈래. --only 로 고른다. 기본은 전부다.
#   unit         tests/unit         빠르고 격리된 것. pre-push 훅이 이것만 돌린다
#   integration  tests/integration  경계를 실제로 넘는 것
#   e2e          tests/e2e          바깥에서 본 것
#
# 갈래 하나가 디렉터리 하나다. 디렉터리가 없거나 수집할 테스트가 없으면 SKIP 이고
# 0 으로 끝난다. 테스트를 아직 안 쓴 저장소에서도 훅과 just verify 가 통과해야 한다.
# pytest 는 수집한 테스트가 없을 때 5 로 끝나는데, 그것은 실패가 아니라 없는 것이다.
#
# 추적 중인 파이썬 파일이 하나도 없으면 pytest 를 찾지도 않고 SKIP 한다.
# 이 스크립트는 언어 감지와 무관하게 항상 배치되기 때문이다.
#
# pyproject.toml 과 uv.lock 과 uv 가 모두 있으면 uv run --frozen 으로 부른다.
# 그래야 훅과 CI 와 손으로 돌릴 때가 잠긴 같은 버전을 쓴다. 셋 중 하나라도 없으면
# PATH 에서 찾는다.
#
# 무엇을 테스트하는지는 docs/standards/testing.md 에 있다. 여기는 실행만 한다.
#
# 도구가 없으면 로컬에서는 SKIP, CI(환경변수 CI=true)에서는 FAIL 이다.
#
# 이 스크립트는 모든 갈래를 돌려 결과를 모으므로 set -e 를 쓰지 않는다.
# 예외 근거는 docs/standards/shell.md 에 있다.
#
# 사용법:
#   bash tests/run-tests.sh                          # 전부
#   bash tests/run-tests.sh --only unit              # 한 갈래만
#   bash tests/run-tests.sh --only unit,integration  # 여러 갈래
#
# 종료 코드: FAIL 이 하나라도 있으면 1, 알 수 없는 옵션이면 2, 아니면 0

set -uo pipefail

# cd 뒤에는 상대 경로인 BASH_SOURCE 가 안 풀린다. --help 가 자기 파일을 읽으므로 먼저 절대 경로로 잡는다.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SELF="$SCRIPT_DIR/$(basename "${BASH_SOURCE[0]}")"

ALL_SUITES="unit integration e2e"
SUITES="$ALL_SUITES"

# 쉼표로 이어진 갈래 목록을 정규 순서로 되돌린다. 모르는 이름이면 실패한다.
select_suites() {
    local raw="$1" name selected=""
    for name in ${raw//,/ }; do
        case " $ALL_SUITES " in
            *" $name "*) ;;
            *)
                echo "FAIL: 그런 테스트 갈래가 없다: $name" >&2
                echo "      쓸 수 있는 갈래: $ALL_SUITES" >&2
                return 1
                ;;
        esac
    done
    for name in $ALL_SUITES; do
        case " ${raw//,/ } " in
            *" $name "*) selected="$selected $name" ;;
        esac
    done
    SUITES="${selected# }"
}

while [ $# -gt 0 ]; do
    case "$1" in
        --only)
            if [ "$#" -lt 2 ]; then
                echo "FAIL: --only 값이 없다" >&2
                exit 2
            fi
            select_suites "$2" || exit 2
            shift 2
            ;;
        -h | --help)
            sed -n '2,/^$/p' "$SELF"
            exit 0
            ;;
        *)
            echo "알 수 없는 옵션: $1" >&2
            exit 2
            ;;
    esac
done

# 스크립트 위치가 아니라 git 이 루트를 정한다. tests/ 를 옮겨도 따라온다.
REPO_ROOT="$(git rev-parse --show-toplevel 2> /dev/null)" || {
    echo "FAIL: git 저장소가 아니다" >&2
    exit 1
}
cd "$REPO_ROOT" || exit 1

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

# 잠긴 버전으로 pytest 를 부를 수 있으면 그렇게 한다. 훅과 CI 와 사람이 같은 버전을
# 쓰게 하는 유일한 방법이다. 셋 중 하나라도 없으면 PATH 로 물러선다.
# 빈 배열을 확장하면 set -u 에서 터지므로 PATH 쪽에는 무해한 command 를 둔다.
RUNNER=(command)
RUNNER_LABEL="PATH"
if [ -f pyproject.toml ] && [ -f uv.lock ] && command -v uv > /dev/null 2>&1; then
    RUNNER=(uv run --frozen)
    RUNNER_LABEL="uv run --frozen"
fi

# 도구가 있으면 0, 없으면 판정을 남기고 1. CI 에서는 없는 것이 FAIL 이다.
require_tool() {
    # $1: 명령
    "${RUNNER[@]}" "$1" --version > /dev/null 2>&1 && return 0
    if [ "${CI:-}" = "true" ]; then
        report FAIL "$1" "미설치. CI 에서는 필수다"
    else
        report SKIP "$1" "미설치"
    fi
    bash scripts/tool-help.sh "$1"
    return 1
}

run_suite() {
    # $1: 갈래 이름
    local suite="$1" dir="tests/$1" out rc

    if [ ! -d "$dir" ]; then
        report SKIP "$suite" "$dir 가 없다"
        return
    fi

    out="$("${RUNNER[@]}" pytest "$dir" 2>&1)"
    rc=$?

    # 5 는 수집한 테스트가 없다는 뜻이다. 아직 안 쓴 것이지 실패한 것이 아니다.
    if [ "$rc" -eq 5 ]; then
        report SKIP "$suite" "$dir 에 수집할 테스트가 없다"
        return
    fi

    printf '%s\n' "$out"
    if [ "$rc" -eq 0 ]; then
        report PASS "$suite" "$dir"
    else
        report FAIL "$suite" "pytest 종료 코드 $rc"
    fi
}

if [ -z "$(git ls-files -- '*.py')" ]; then
    echo "SKIP 추적 중인 파이썬 파일이 없다"
    exit 0
fi

echo "대상 갈래: $SUITES"
echo "실행 경로: $RUNNER_LABEL"

# 갈래 디렉터리가 하나도 없으면 pytest 를 찾지 않는다. 파이썬을 쓰지 않는 저장소에도
# scripts/*.py 검사기가 깔리므로 추적 파일 검사만으로는 여기까지 온다. 돌릴 것이
# 없는데 도구가 없다고 CI 를 빨갛게 만들면, 그 빨간불은 아무 사실도 알려주지 않는다.
have_suite=0
for suite in $SUITES; do
    [ -d "tests/$suite" ] && have_suite=1
done

if [ "$have_suite" -eq 0 ]; then
    for suite in $SUITES; do
        report SKIP "$suite" "tests/$suite 가 없다"
    done
    echo
    echo "결과: PASS $pass_count, FAIL $fail_count, SKIP $skip_count"
    exit 0
fi

if require_tool pytest; then
    suite_total="$(printf '%s\n' "$SUITES" | wc -w | tr -d ' ')"
    suite_index=0
    for suite in $SUITES; do
        suite_index=$((suite_index + 1))
        echo
        echo "[$suite_index/$suite_total] $suite"
        run_suite "$suite"
    done
fi

echo
echo "결과: PASS $pass_count, FAIL $fail_count, SKIP $skip_count"

if [ "$fail_count" -gt 0 ]; then
    echo
    echo "규약: docs/standards/testing.md" >&2
    exit 1
fi
exit 0
