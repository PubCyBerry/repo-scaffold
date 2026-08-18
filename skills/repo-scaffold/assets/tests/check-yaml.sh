#!/usr/bin/env bash
# YAML 형식 검사와 선언 설정 파일의 스키마 검사.
#
# 대상:
#   1. yamllint          추적 중인 *.yml, *.yaml 전부. 기준은 .yamllint.yaml
#   2. check-jsonschema  .github/workflows 아래 워크플로. 내장 vendor.github-workflows 스키마
#   3. check-jsonschema  renovate.json. 내장 vendor.renovate 스키마
#
# 셋으로 나누는 이유는 소유 범위가 다르기 때문이다. yamllint 은 YAML 문법과 형식을 보고,
# 스키마는 키 구조를 본다. 워크플로의 의미는 actionlint 이, 보안은 zizmor 가
# 보고 그 둘은 tests/check-workflows.sh 에 있다. 같은 규칙을 두 도구에 두지 않는다.
#
# renovate.json 은 YAML 이 아니지만 여기서 본다. 검사기가 같고, 이 파일이 없으면 의존성
# 갱신 PR 이 조용히 0건이 된다. 어느 검사도 지금까지 이 파일을 읽지 않았다.
# 스키마는 check-jsonschema 가 vendor 로 품고 있다. 훅이 네트워크를 타지 않는다.
# 잡는 것은 키의 자료형과 값 형식이다. 모르는 최상위 키와 오타 난 preset 이름은
# 스키마가 열려 있어 통과한다. 그것은 Renovate 대시보드가 보고한다.
#
# yamllint 은 --strict 로 부른다. 경고도 실패다.
# 근거는 docs/standards/code-quality.md 의 zero warnings 다.
#
# 도구가 없으면 로컬에서는 SKIP, CI(환경변수 CI=true)에서는 FAIL 이다.
# 로컬에서 커밋을 막으면 --no-verify 가 습관이 되므로 막지 않고, CI 에서 잡는다.
#
# 이 스크립트는 모든 검사를 돌려 결과를 모으므로 set -e 를 쓰지 않는다.
# 예외 근거는 docs/standards/shell.md 에 있다.
#
# 사용법:
#   bash tests/check-yaml.sh
#
# 종료 코드: FAIL 이 하나라도 있으면 1, 알 수 없는 옵션이면 2, 아니면 0

set -uo pipefail

# cd 뒤에는 상대 경로인 BASH_SOURCE 가 안 풀린다. --help 가 자기 파일을 읽으므로 먼저 절대 경로로 잡는다.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SELF="$SCRIPT_DIR/$(basename "${BASH_SOURCE[0]}")"

CONFIG=".yamllint.yaml"
WORKFLOW_DIR=".github/workflows"
WORKFLOW_SCHEMA="vendor.github-workflows"
RENOVATE_SCHEMA="vendor.renovate"

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
    printf '%-4s %-18s %s\n' "$1" "$2" "${3:-}"
}

# 저장소 파일이 없을 때의 판정. CI 에서는 FAIL 이다.
# 도구가 없는 것은 기계의 성질이고 설정 파일이 없는 것은 저장소의 결함이다.
missing_config() {
    # $1: 이름, $2: 사유
    if [ "${CI:-}" = "true" ]; then
        report FAIL "$1" "$2"
    else
        report SKIP "$1" "$2"
    fi
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

FILES=()
while IFS= read -r f; do
    FILES[${#FILES[@]}]="$f"
done < <(git ls-files -- '*.yml' '*.yaml' | sort)

WORKFLOWS=()
while IFS= read -r f; do
    WORKFLOWS[${#WORKFLOWS[@]}]="$f"
done < <(git ls-files -- "$WORKFLOW_DIR/*.yml" "$WORKFLOW_DIR/*.yaml" | sort)

# Renovate 는 설정 파일 이름을 여럿 받아들인다. JSON5 와 확장자 없는 이름은 검사기가
# 형식을 못 읽으므로 여기서 보지 않는다.
RENOVATE_FILES=()
while IFS= read -r f; do
    RENOVATE_FILES[${#RENOVATE_FILES[@]}]="$f"
done < <(git ls-files -- 'renovate.json' '.renovaterc.json' '.github/renovate.json' | sort)

# 대상이 하나도 없어도 여기서 멈추지 않는다. 멈추면 renovate.json 이 사라진 것을
# 알려야 하는 3단계가 영영 못 돈다. 단계마다 스스로 판정을 남긴다.
echo "대상 YAML: ${#FILES[@]}개 (워크플로 ${#WORKFLOWS[@]}개), Renovate 설정: ${#RENOVATE_FILES[@]}개"

echo
echo "[1/3] yamllint"
if [ "${#FILES[@]}" -eq 0 ]; then
    report SKIP yamllint "추적 중인 YAML 파일이 없다"
elif require_tool yamllint; then
    # 설정 파일을 명시한다. 안 주면 yamllint 이 찾지 못했을 때 사용자 홈의 설정이나
    # 내장 기본값(줄 길이 80)으로 조용히 떨어져서 사람마다 다른 답이 나온다.
    YAMLLINT_ARGS=(--strict --format parsable)
    if [ -f "$CONFIG" ]; then
        YAMLLINT_ARGS[${#YAMLLINT_ARGS[@]}]="-c"
        YAMLLINT_ARGS[${#YAMLLINT_ARGS[@]}]="$CONFIG"
    else
        report SKIP "$CONFIG" "없다. yamllint 내장 기본값으로 돈다. 기준은 저장소 것이 아니다"
    fi

    if out="$(yamllint "${YAMLLINT_ARGS[@]}" "${FILES[@]}" 2>&1)" && [ -z "$out" ]; then
        report PASS yamllint "지적 없음"
    else
        printf '%s\n' "$out"
        report FAIL yamllint "지적을 전부 고친다. 기준은 $CONFIG 다"
    fi
fi

echo
echo "[2/3] 워크플로 스키마"
if [ "${#WORKFLOWS[@]}" -eq 0 ]; then
    report SKIP workflow-schema "$WORKFLOW_DIR 에 추적 중인 워크플로가 없다"
elif require_tool check-jsonschema; then
    if out="$(check-jsonschema --builtin-schema "$WORKFLOW_SCHEMA" "${WORKFLOWS[@]}" 2>&1)"; then
        report PASS workflow-schema "워크플로 스키마 일치"
    else
        printf '%s\n' "$out"
        report FAIL workflow-schema "워크플로 키 구조가 $WORKFLOW_SCHEMA 스키마에 어긋난다"
    fi
fi

echo
echo "[3/3] Renovate 스키마"
if [ "${#RENOVATE_FILES[@]}" -eq 0 ]; then
    # 파일이 사라진 것과 파일이 잘못된 것은 결과가 같다. 갱신 PR 이 0건이 되고
    # 그 상태는 갱신할 것이 없는 상태와 구분되지 않는다. CI 에서는 FAIL 이다.
    missing_config renovate-schema "추적 중인 Renovate 설정이 없다. 의존성 갱신 정책이 저장소에 있어야 한다"
elif require_tool check-jsonschema; then
    if out="$(check-jsonschema --builtin-schema "$RENOVATE_SCHEMA" "${RENOVATE_FILES[@]}" 2>&1)"; then
        report PASS renovate-schema "Renovate 설정 스키마 일치"
    else
        printf '%s\n' "$out"
        report FAIL renovate-schema "설정이 $RENOVATE_SCHEMA 스키마에 어긋난다. 갱신 PR 이 오지 않는다"
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
