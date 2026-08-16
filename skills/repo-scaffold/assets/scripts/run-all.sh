#!/usr/bin/env bash
# just 레시피 여러 개를 끝까지 돌리고 결과를 모은다.
#
# 인자는 명령이 아니라 레시피 이름이다. Justfile 이 묶음의 유일한 정의이고
# 이 스크립트는 실행과 집계만 한다.
#
# 필요한 이유: Justfile 의 set shell 이 -c 를 쓰므로 just 는 레시피 줄마다 셸을
# 새로 띄우고 첫 실패에서 멈춘다. 이 저장소의 관용은 전부 돌리고 마지막에 집계하는
# 것이다. 그 차이를 여기서 메운다. 근거는 docs/standards/shell.md 에 있다.
#
# Justfile 에 없는 이름은 SKIP 이다. 아직 도입하지 않은 검사를 verify 목록에
# 미리 적어둘 수 있고, 필요 없는 레시피를 지워도 묶음이 깨지지 않는다.
#
# 이 스크립트는 모든 검사를 돌려 결과를 모으므로 set -e 를 쓰지 않는다.
# 예외 근거는 docs/standards/shell.md 에 있다.
#
# 사용법:
#   bash scripts/run-all.sh RECIPE [RECIPE ...]
#
# 환경 변수:
#   JUST   just 실행 파일 경로. Justfile 이 just_executable() 로 넣어준다
#
# 종료 코드: FAIL 이 하나라도 있으면 1, 인자가 없거나 알 수 없는 옵션이면 2, 아니면 0

set -uo pipefail

# cd 뒤에는 상대 경로인 BASH_SOURCE 가 안 풀린다. --help 가 자기 파일을 읽으므로 먼저 절대 경로로 잡는다.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SELF="$SCRIPT_DIR/$(basename "${BASH_SOURCE[0]}")"

case "${1:-}" in
    -h | --help)
        sed -n '2,/^$/p' "$SELF"
        exit 0
        ;;
    "")
        echo "FAIL: 돌릴 레시피 이름이 없다" >&2
        echo "      사용법: bash scripts/run-all.sh RECIPE [RECIPE ...]" >&2
        exit 2
        ;;
    -*)
        echo "알 수 없는 옵션: $1" >&2
        exit 2
        ;;
esac

REPO_ROOT="$(git rev-parse --show-toplevel 2> /dev/null)" || {
    echo "FAIL: git 저장소가 아니다" >&2
    exit 1
}
cd "$REPO_ROOT" || exit 1

pass_count=0
fail_count=0
skip_count=0
FAILED=()

report() {
    # $1: 판정, $2: 대상, $3: 사유
    case "$1" in
        PASS) pass_count=$((pass_count + 1)) ;;
        FAIL) fail_count=$((fail_count + 1)) ;;
        SKIP) skip_count=$((skip_count + 1)) ;;
    esac
    printf '%-4s %-20s %s\n' "$1" "$2" "${3:-}"
}

JUST_BIN="${JUST:-just}"

# just 를 부르지 못하면 아무것도 못 한다. 이 스크립트는 레시피 안에서만 불린다.
if ! RECIPES="$("$JUST_BIN" --summary 2>&1)"; then
    printf '%s\n' "$RECIPES"
    echo "FAIL: just 로 레시피 목록을 읽지 못했다. 설치: uv tool install rust-just" >&2
    exit 1
fi

# 순환 방지. 조상 레시피를 다시 부르면 무한히 프로세스를 낳는다.
STACK="${REPO_SCAFFOLD_RECIPE_STACK:-}"

total=$#
index=0

for name in "$@"; do
    index=$((index + 1))

    case " $STACK " in
        *" $name "*)
            report FAIL "$name" "순환 호출. 이미 실행 중인 레시피다"
            FAILED[${#FAILED[@]}]="$name"
            continue
            ;;
    esac

    case " $RECIPES " in
        *" $name "*) ;;
        *)
            report SKIP "$name" "Justfile 에 없는 레시피다"
            continue
            ;;
    esac

    echo
    echo "===== [$index/$total] $name ====="
    REPO_SCAFFOLD_RECIPE_STACK="$STACK $name" "$JUST_BIN" "$name"
    rc=$?
    if [ "$rc" -eq 0 ]; then
        report PASS "$name"
    else
        report FAIL "$name" "종료 코드 $rc"
        FAILED[${#FAILED[@]}]="$name"
    fi
done

echo
echo "결과: PASS $pass_count, FAIL $fail_count, SKIP $skip_count"

if [ "$fail_count" -gt 0 ]; then
    echo
    echo "실패한 레시피: ${FAILED[*]}" >&2
    exit 1
fi
exit 0
