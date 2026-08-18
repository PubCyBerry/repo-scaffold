#!/usr/bin/env bash
# 형식을 맞춘다. 이 스크립트는 파일을 바꾼다.
#
# 대상:
#   1. shfmt        추적 중인 *.sh, *.bash
#   2. ruff format  추적 중인 *.py, *.pyi
#   3. rumdl        추적 중인 *.md
#
# shfmt 에 형식 플래그를 주지 않는다. 플래그를 하나라도 주면 shfmt 가 .editorconfig 를
# 통째로 무시해서 훅, CI, 손으로 돌릴 때 기준이 갈린다. -w 는 형식이 아니라 모드
# 플래그라 .editorconfig 를 무시하지 않는다. 형식 기준은 .editorconfig 하나다.
# 파이썬 형식 기준은 pyproject.toml 의 line-length 다.
#
# rumdl fmt 는 위반이 있어도 0 으로 끝난다. 고쳤는지는 종료 코드가 아니라 diff 로 본다.
#
# 검사만 하려면 bash tests/check-shell.sh, bash tests/check-python.sh,
# bash tests/check-markdown.sh 를 쓴다. 그쪽은 파일을 바꾸지 않는다. 훅이 부르는 것도 그쪽이다.
#
# 도구가 없으면 로컬에서는 SKIP, CI(환경변수 CI=true)에서는 FAIL 이다.
#
# 이 스크립트는 모든 단계를 돌려 결과를 모으므로 set -e 를 쓰지 않는다.
# 예외 근거는 docs/standards/shell.md 에 있다.
#
# 사용법:
#   bash scripts/fmt.sh
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
        report FAIL "$1" "미설치. CI 에서는 필수다"
    else
        report SKIP "$1" "미설치"
    fi
    bash scripts/tool-help.sh "$1"
    return 1
}

echo "[1/3] shfmt"

SHELL_FILES=()
while IFS= read -r f; do
    SHELL_FILES[${#SHELL_FILES[@]}]="$f"
done < <(git ls-files -- '*.sh' '*.bash' | sort)

if [ "${#SHELL_FILES[@]}" -eq 0 ]; then
    report SKIP shfmt "추적 중인 셸 스크립트가 없다"
elif require_tool shfmt; then
    # -w 는 모드 플래그라 .editorconfig 를 무시하지 않는다. 형식 플래그를 주면 안 된다.
    if out="$(shfmt -w "${SHELL_FILES[@]}" 2>&1)"; then
        report PASS shfmt "${#SHELL_FILES[@]}개 정리"
    else
        printf '%s\n' "$out"
        report FAIL shfmt "형식 적용 실패"
    fi
fi

echo
echo "[2/3] ruff format"

PY_FILES=()
while IFS= read -r f; do
    PY_FILES[${#PY_FILES[@]}]="$f"
done < <(git ls-files -- '*.py' '*.pyi' | sort)

if [ "${#PY_FILES[@]}" -eq 0 ]; then
    report SKIP "ruff format" "추적 중인 파이썬 파일이 없다"
elif require_py_tool ruff; then
    if out="$("${PY_RUNNER[@]}" ruff format "${PY_FILES[@]}" 2>&1)"; then
        report PASS "ruff format" "${#PY_FILES[@]}개 정리"
    else
        printf '%s\n' "$out"
        report FAIL "ruff format" "형식 적용 실패"
    fi
fi

echo
echo "[3/3] rumdl"

DOC_FILES=()
while IFS= read -r f; do
    DOC_FILES[${#DOC_FILES[@]}]="$f"
done < <(git ls-files -- '*.md' | sort)

if [ "${#DOC_FILES[@]}" -eq 0 ]; then
    report SKIP rumdl "추적 중인 마크다운 문서가 없다"
elif [ ! -f ".rumdl.toml" ]; then
    report SKIP rumdl ".rumdl.toml 이 없다. 규칙 설정이 저장소에 있어야 한다"
elif require_tool rumdl; then
    # rumdl fmt 는 고칠 것이 있든 없든 0 으로 끝난다. 종료 코드로 판정하지 않는다.
    if out="$(rumdl fmt . 2>&1)"; then
        report PASS rumdl "${#DOC_FILES[@]}개 문서 정리"
    else
        printf '%s\n' "$out"
        report FAIL rumdl "형식 적용 실패"
    fi
fi

echo
echo "결과: PASS $pass_count, FAIL $fail_count, SKIP $skip_count"

if [ "$fail_count" -gt 0 ]; then
    exit 1
fi
exit 0
