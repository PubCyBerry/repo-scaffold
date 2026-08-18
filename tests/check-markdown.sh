#!/usr/bin/env bash
# 마크다운 구조와 형식 검사. 검사기는 rumdl 이다.
#
# 규칙은 .rumdl.toml 에 있고 사람이 읽는 원본은 docs/standards/documentation.md 다.
#
# 저장소 전체를 한 번에 본다. 바뀐 파일만 넘기지 않는다.
# rumdl 의 cross-file 앵커 검사(MD051)는 실행 대상으로 넘어온 파일들로 색인을 만들고,
# 색인에 없는 대상 파일은 조용히 건너뛴다. 파일 하나만 넘기면 다른 문서를 가리키는
# 앵커가 전부 미검사가 되고, 초록 불이 곧 미검사라는 뜻이 된다. 실측으로 확인했다.
#
# 이 스크립트는 파일을 바꾸지 않는다. rumdl check 만 부르고 rumdl fmt 는 부르지 않는다.
# 훅이 파일을 바꾸면 커밋되는 내용이 사람이 본 내용과 달라진다.
# 자동 수정은 scripts/fmt.sh 가 한다.
#
# 도구가 없으면 로컬에서는 SKIP, CI(환경변수 CI=true)에서는 FAIL 이다.
# 로컬에서 커밋을 막으면 --no-verify 가 습관이 되므로 막지 않고, CI 에서 잡는다.
#
# 이 스크립트는 모든 검사를 돌려 결과를 모으므로 set -e 를 쓰지 않는다.
# 예외 근거는 docs/standards/shell.md 에 있다.
#
# 사용법:
#   bash tests/check-markdown.sh
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

CONFIG=".rumdl.toml"

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

FILES=()
while IFS= read -r f; do
    FILES[${#FILES[@]}]="$f"
done < <(git ls-files -- '*.md' | sort)

echo "[1/1] rumdl"

if [ "${#FILES[@]}" -eq 0 ]; then
    report SKIP rumdl "추적 중인 마크다운 문서가 없다"
elif [ ! -f "$CONFIG" ]; then
    report SKIP rumdl "$CONFIG 가 없다. 규칙 설정이 저장소에 있어야 한다"
elif require_tool rumdl; then
    # 대상은 파일 목록이 아니라 저장소 전체다. MD051 이 색인을 만들려면 그래야 한다.
    if out="$(rumdl check . 2>&1)"; then
        report PASS rumdl "${#FILES[@]}개 문서, 지적 없음"
    else
        printf '%s\n' "$out"
        report FAIL rumdl "지적을 고친다. 형식 지적은 just fmt 가 자동으로 고친다"
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
