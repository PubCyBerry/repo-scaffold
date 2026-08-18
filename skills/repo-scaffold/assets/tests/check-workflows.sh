#!/usr/bin/env bash
# GitHub Actions 워크플로 검사.
#
# 대상: .github/workflows 아래 추적 중인 *.yml, *.yaml
#
# 검사 단계. --only 로 고른다. 기본은 전부다.
#   actionlint  문법, 표현식, step 안 셸
#   zizmor      보안 감사. 자격 증명 잔류, 주입, 미고정 action
#
# 단계를 고를 수 있는 이유는 스테이지마다 도는 범위가 다르기 때문이다.
# actionlint 는 pre-commit 과 pre-push 양쪽에서 돈다. 워크플로 파일을 안 고쳐도
# 워크플로가 부르는 스크립트가 바뀌면 깨지므로 push 전에 한 번 더 본다.
# zizmor 는 pre-commit 과 CI 에서만 돈다.
#
# zizmor 는 GH_TOKEN 또는 GITHUB_TOKEN 이 있으면 온라인 감사까지 하고,
# 없으면 --offline 으로 돈다. 토큰이 없다고 실패시키지 않는다.
#
# YAML 문법과 형식은 여기서 보지 않는다. tests/check-yaml.sh 가 본다.
# 같은 규칙을 두 도구에 두지 않는다.
#
# 도구가 없으면 로컬에서는 SKIP, CI(환경변수 CI=true)에서는 FAIL 이다.
#
# 이 스크립트는 모든 검사를 돌려 결과를 모으므로 set -e 를 쓰지 않는다.
# 예외 근거는 docs/standards/shell.md 에 있다.
#
# 사용법:
#   bash tests/check-workflows.sh                    # 전체 검사
#   bash tests/check-workflows.sh --only actionlint  # 한 단계만
#
# 종료 코드: FAIL 이 하나라도 있으면 1, 알 수 없는 옵션이면 2, 아니면 0

set -uo pipefail

# cd 뒤에는 상대 경로인 BASH_SOURCE 가 안 풀린다. --help 가 자기 파일을 읽으므로 먼저 절대 경로로 잡는다.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SELF="$SCRIPT_DIR/$(basename "${BASH_SOURCE[0]}")"

WORKFLOW_DIR=".github/workflows"

ALL_PHASES="actionlint zizmor"
PHASES="$ALL_PHASES"

# 쉼표로 이어진 단계 목록을 정규 순서로 되돌린다. 모르는 이름이면 실패한다.
select_phases() {
    local raw="$1" name selected=""
    for name in ${raw//,/ }; do
        case " $ALL_PHASES " in
            *" $name "*) ;;
            *)
                echo "FAIL: 그런 검사 단계가 없다: $name" >&2
                echo "      쓸 수 있는 단계: $ALL_PHASES" >&2
                return 1
                ;;
        esac
    done
    for name in $ALL_PHASES; do
        case " ${raw//,/ } " in
            *" $name "*) selected="$selected $name" ;;
        esac
    done
    PHASES="${selected# }"
}

while [ $# -gt 0 ]; do
    case "$1" in
        --only)
            if [ "$#" -lt 2 ]; then
                echo "FAIL: --only 값이 없다" >&2
                exit 2
            fi
            select_phases "$2" || exit 2
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

# 도구가 있으면 0, 없으면 판정을 남기고 1. CI 에서는 없는 것이 FAIL 이다.
require_tool() {
    # $1: 명령
    command -v "$1" > /dev/null 2>&1 && return 0
    if [ "${CI:-}" = "true" ]; then
        report FAIL "$1" "미설치. CI 에서는 필수다"
    else
        report SKIP "$1" "미설치"
    fi
    bash scripts/tool-help.sh "$1"
    return 1
}

phase_on() {
    case " $PHASES " in
        *" $1 "*) return 0 ;;
    esac
    return 1
}

phase_total="$(printf '%s\n' "$PHASES" | wc -w | tr -d ' ')"
phase_index=0

banner() {
    phase_index=$((phase_index + 1))
    echo
    echo "[$phase_index/$phase_total] $1"
}

if [ "$phase_total" -eq 0 ]; then
    echo "FAIL: 돌릴 검사 단계가 없다" >&2
    exit 2
fi

FILES=()
while IFS= read -r f; do
    FILES[${#FILES[@]}]="$f"
done < <(git ls-files -- "$WORKFLOW_DIR/*.yml" "$WORKFLOW_DIR/*.yaml" | sort)

if [ "${#FILES[@]}" -eq 0 ]; then
    echo "SKIP $WORKFLOW_DIR 에 추적 중인 워크플로가 없다"
    exit 0
fi

echo "대상 워크플로: ${#FILES[@]}개"

if phase_on actionlint; then
    banner actionlint
    if require_tool actionlint; then
        if out="$(actionlint -no-color "${FILES[@]}" 2>&1)"; then
            report PASS actionlint "지적 없음"
        else
            printf '%s\n' "$out"
            report FAIL actionlint "지적을 전부 고친다"
        fi
    fi
fi

if phase_on zizmor; then
    banner zizmor
    if require_tool zizmor; then
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
fi

echo
echo "결과: PASS $pass_count, FAIL $fail_count, SKIP $skip_count"

if [ "$fail_count" -gt 0 ]; then
    echo
    echo "규약: docs/standards/github-actions.md" >&2
    exit 1
fi
exit 0
