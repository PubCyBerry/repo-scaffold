#!/usr/bin/env bash
# 외부 URL 검사. 검사기는 lychee 다.
#
# 규칙은 lychee.toml 에 있다. 대상은 git 이 추적하는 마크다운 전부다.
# 저장소 안 링크는 여기서 보지 않는다. rumdl 의 MD057 과 MD051 이 본다.
#
# lychee 는 CI 전용 도구다. tools.txt 에 없고 uv 로 깔리지 않는다.
# PyPI 밖 도구이고 네트워크가 필요해서 개발자 머신에 요구하지 않는다.
# 없으면 로컬에서는 SKIP, CI(환경변수 CI=true)에서는 FAIL 이다.
# 설치는 https://lychee.cli.rs 에 있다.
#
# lychee.toml 이 없는 것도 같은 판정이다. 도구가 없는 것은 기계의 성질이지만 설정 파일이
# 없는 것은 저장소의 결함이다. 병합 사고로 사라지면 예약 잡이 영원히 초록 불이 된다.
#
# 네트워크를 타므로 훅에 넣지 않는다. 커밋마다 기다리게 하면 --no-verify 가 습관이 되고
# 그러면 훅 전체가 함께 죽는다. just verify 에도 넣지 않는다. 손으로 부르거나 CI 가 부른다.
#
# 이 스크립트는 모든 검사를 돌려 결과를 모으므로 set -e 를 쓰지 않는다.
# 예외 근거는 docs/standards/shell.md 에 있다.
#
# 사용법:
#   bash tests/check-links-external.sh
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

# 스크립트 위치가 아니라 git 이 루트를 정한다. tests/ 를 옮겨도 따라온다.
REPO_ROOT="$(git rev-parse --show-toplevel 2> /dev/null)" || {
    echo "FAIL: git 저장소가 아니다" >&2
    exit 1
}
cd "$REPO_ROOT" || exit 1

CONFIG="lychee.toml"

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

# 저장소 파일이 없을 때의 판정. CI 에서는 FAIL 이다.
# 도구가 없는 것은 기계의 성질이고 설정 파일이 없는 것은 저장소의 결함이다.
# 병합 사고로 lychee.toml 이 사라져도 예약 잡은 계속 초록 불이 된다.
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
        report SKIP "$1" "미설치. CI 전용 도구다"
    fi
    bash scripts/tool-help.sh "$1"
    return 1
}

# 저장소가 추적하는 문서만 넘긴다. 디렉터리를 통째로 넘기면 node_modules 와 .venv 안의
# 남의 문서까지 두드린다.
FILES=()
while IFS= read -r f; do
    FILES[${#FILES[@]}]="$f"
done < <(git ls-files -- '*.md' '*.mdx' | sort)

echo "[1/1] lychee"

if [ "${#FILES[@]}" -eq 0 ]; then
    report SKIP lychee "추적 중인 마크다운 문서가 없다"
elif [ ! -f "$CONFIG" ]; then
    missing_config lychee "$CONFIG 가 없다. 규칙 설정이 저장소에 있어야 한다"
elif require_tool lychee; then
    # 설정은 전부 lychee.toml 이 갖는다. 명령줄로 나누면 CI 와 손으로 돌릴 때가 갈린다.
    out="$(lychee --config "$CONFIG" -- "${FILES[@]}" 2>&1)"
    status=$?
    printf '%s\n' "$out"
    if [ "$status" -eq 0 ]; then
        report PASS lychee "${#FILES[@]}개 문서, 깨진 URL 없음"
    else
        report FAIL lychee "깨진 URL 을 고치거나 lychee.toml 의 exclude 에 근거를 적고 넣는다"
    fi
fi

echo
echo "결과: PASS $pass_count, FAIL $fail_count, SKIP $skip_count"

if [ "$fail_count" -gt 0 ]; then
    echo
    echo "규약: docs/standards/documentation.md" >&2
    exit 1
fi
exit 0
