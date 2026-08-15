#!/usr/bin/env bash
# GitHub Actions 워크플로 검사.
#
# 대상: .github/workflows 아래 추적 중인 *.yml, *.yaml
#   1. actionlint  문법, 표현식, step 안 셸
#   2. zizmor      보안 감사. 자격 증명 잔류, 주입, 미고정 action
#
# zizmor 는 GH_TOKEN 또는 GITHUB_TOKEN 이 있으면 온라인 감사까지 하고,
# 없으면 --offline 으로 돈다. 토큰이 없다고 실패시키지 않는다.
#
# 도구가 없으면 로컬에서는 SKIP, CI(환경변수 CI=true)에서는 FAIL 이다.
#
# 이 스크립트는 모든 검사를 돌려 결과를 모으므로 set -e 를 쓰지 않는다.
# 예외 근거는 docs/standards/shell.md 에 있다.
#
# 사용법:
#   bash tests/check-workflows.sh
#
# 종료 코드: FAIL 이 하나라도 있으면 1, 아니면 0

set -uo pipefail

# cd 뒤에는 상대 경로인 BASH_SOURCE 가 안 풀린다. --help 가 자기 파일을 읽으므로 먼저 절대 경로로 잡는다.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SELF="$SCRIPT_DIR/$(basename "${BASH_SOURCE[0]}")"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT" || exit 1

WORKFLOW_DIR=".github/workflows"

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
done < <(git ls-files -- "$WORKFLOW_DIR/*.yml" "$WORKFLOW_DIR/*.yaml" | sort)

if [ "${#FILES[@]}" -eq 0 ]; then
    echo "SKIP $WORKFLOW_DIR 에 추적 중인 워크플로가 없다"
    exit 0
fi

echo "대상 워크플로: ${#FILES[@]}개"

echo
echo "[1/2] actionlint"
if require_tool actionlint "uv tool install actionlint-py"; then
    if out="$(actionlint -no-color "${FILES[@]}" 2>&1)"; then
        report PASS actionlint "지적 없음"
    else
        printf '%s\n' "$out"
        report FAIL actionlint "지적을 전부 고친다"
    fi
fi

echo
echo "[2/2] zizmor"
if require_tool zizmor "uv tool install zizmor"; then
    ZIZMOR_ARGS=(--no-progress --persona=regular)
    if [ -z "${GH_TOKEN:-}${GITHUB_TOKEN:-}" ]; then
        ZIZMOR_ARGS[${#ZIZMOR_ARGS[@]}]="--offline"
    fi

    out="$(zizmor "${ZIZMOR_ARGS[@]}" "${FILES[@]}" 2>&1)"
    zizmor_code=$?
    # 0 지적 없음, 3 감사 대상 없음, 11-14 심각도별 지적, 그 밖은 도구 오류
    case "$zizmor_code" in
        0) report PASS zizmor "지적 없음" ;;
        3) report SKIP zizmor "감사 대상 없음" ;;
        *)
            printf '%s\n' "$out"
            report FAIL zizmor "지적을 해소한다. 오탐이면 사유와 함께 억제한다"
            ;;
    esac
fi

echo
echo "결과: PASS $pass_count, FAIL $fail_count, SKIP $skip_count"

if [ "$fail_count" -gt 0 ]; then
    echo
    echo "규약: docs/standards/github-actions.md" >&2
    exit 1
fi
exit 0
