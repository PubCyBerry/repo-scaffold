#!/usr/bin/env bash
# 산문, 용어, 문자 규칙 검사. 검사기는 Vale 이다.
#
# 규칙은 .vale.ini 와 styles/ 에 있고 사람이 읽는 원본은 docs/standards/writing-style.md 다.
#
# Vale 의 자리는 산문 정책 검사기와 용어 검사기 둘이다. 문법 검사기도, 글 품질 평가기도,
# 맞춤법 검사기도 아니다. 한국어 맞춤법은 Vale 로 검사할 수 없다.
#
# error 만 실패로 친다. warning 은 출력에 나오지만 종료 코드에 반영되지 않는다.
# 오탐으로 커밋을 막으면 --no-verify 가 습관이 되고, 그러면 훅 전체가 함께 죽는다.
#
# 대상은 git 이 추적하는 마크다운뿐이다. 저장소 전체를 훑게 두면 node_modules 와
# .venv 안의 남의 문서를 검사한다.
#
# Vale 은 첫 실행에 네트워크로 실행 파일을 받는다.
# 도구가 없으면 로컬에서는 SKIP, CI(환경변수 CI=true)에서는 FAIL 이다.
#
# 이 스크립트는 모든 검사를 돌려 결과를 모으므로 set -e 를 쓰지 않는다.
# 예외 근거는 docs/standards/shell.md 에 있다.
#
# 사용법:
#   bash tests/check-prose.sh
#
# 종료 코드: FAIL 이 하나라도 있으면 1, 알 수 없는 옵션이면 2, 아니면 0

set -uo pipefail

# cd 뒤에는 상대 경로인 BASH_SOURCE 가 안 풀린다. --help 가 자기 파일을 읽으므로 먼저 절대 경로로 잡는다.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SELF="$SCRIPT_DIR/$(basename "${BASH_SOURCE[0]}")"

# 인자로 받은 파일만 검사한다. 인자가 없으면 지금까지처럼 추적 중인 파일 전부를 본다.
# PostToolUse 훅이 방금 고친 파일 하나만 넘긴다. 편집 한 번마다 저장소 전체를 도는
# 비용을 없애려는 것이고, 훅 없이 부르는 쪽의 동작은 그대로다.
ARGV_FILES=()
while [ $# -gt 0 ]; do
    case "$1" in
        -h | --help)
            sed -n '2,/^$/p' "$SELF"
            exit 0
            ;;
        -*)
            echo "알 수 없는 옵션: $1" >&2
            exit 2
            ;;
        *)
            ARGV_FILES[${#ARGV_FILES[@]}]="$1"
            shift
            ;;
    esac
done

# 스크립트 위치가 아니라 git 이 루트를 정한다. tests/ 를 옮겨도 따라온다.
REPO_ROOT="$(git rev-parse --show-toplevel 2> /dev/null)" || {
    echo "FAIL: git 저장소가 아니다" >&2
    exit 1
}
cd "$REPO_ROOT" || exit 1

CONFIG=".vale.ini"
STYLES_DIR="styles"

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

# 이 목록은 이 저장소에만 있다. 배포되는 원본은
# skills/repo-scaffold/assets/tests/check-prose.sh 이고 거기에는 없다.
#
# Vale 은 front matter 를 YAML 로 파싱하고, 파싱에 실패하면 E201 로 실행 자체를 멈춘다.
# 그 파일 하나만 건너뛰는 것이 아니라 뒤따르는 파일이 전부 미검사가 된다.
#
# 걸리는 것은 값의 첫 글자가 치환 키인 경우뿐이다. '{' 로 시작하는 값은 YAML 이
# flow mapping 으로 읽는다. 아래 둘이 그렇다.
#   category-index.md   id: {{IDX_ID}}
#   product-index.md    id: {{IDX_ID}}
# 값 중간에 있는 것은 평범한 문자열이라 통과한다. assets/docs/index.md 의
# 'summary: Entry point for the {{REPO_NAME}} documentation' 이 그 예다.
#
# 그래서 assets/ 를 통째로 빼지 않고 이 둘만 뺀다. 통째로 빼면 템플릿 문서 27 편이
# 영영 산문 검사를 안 받는다. 새 템플릿이 값 첫 자리에 치환 키를 두면 Vale 이 그 파일
# 이름을 대고 멈추므로, 그때 이 목록에 한 줄 추가한다. 조용히 지나가지 않는다.
#
# 렌더된 결과는 skills/repo-scaffold/tests/smoke.sh 가 임시 저장소에서 검사한다.
# .rumdl.toml 쪽 예외는 이보다 넓다. 사유가 달라서다. 근거는 ADR 0002 에 있다.
EXCLUDE=(
    ':(exclude)skills/*/assets/docs/category-index.md'
    ':(exclude)skills/*/assets/docs/product-index.md'
)

FILES=()
while IFS= read -r f; do
    FILES[${#FILES[@]}]="$f"
done < <(git ls-files -- '*.md' "${EXCLUDE[@]}" | sort)

# 인자로 받은 파일이 있으면 그것만 본다. 대상 밖 확장자와 없는 파일은 뺀다.
if [ "${#ARGV_FILES[@]}" -gt 0 ]; then
    FILES=()
    for f in "${ARGV_FILES[@]}"; do
        case "$f" in
            *.md | *.mdx) [ -f "$f" ] && FILES[${#FILES[@]}]="$f" ;;
        esac
    done
    if [ "${#FILES[@]}" -eq 0 ]; then
        echo "SKIP 인자에 마크다운 문서가 없다"
        exit 0
    fi
fi

echo "[1/1] Vale"

if [ "${#FILES[@]}" -eq 0 ]; then
    report SKIP vale "추적 중인 마크다운 문서가 없다"
elif [ ! -f "$CONFIG" ]; then
    report SKIP vale "$CONFIG 가 없다. 규칙 설정이 저장소에 있어야 한다"
elif [ ! -d "$STYLES_DIR" ]; then
    report SKIP vale "$STYLES_DIR/ 가 없다. 규칙 파일이 저장소에 있어야 한다"
elif require_tool vale; then
    # --no-exit 를 쓰지 않는다. 위반이 있어도 0 으로 끝나 훅과 CI 가 아무것도 막지 못한다.
    out="$(vale "${FILES[@]}" 2>&1)"
    status=$?
    printf '%s\n' "$out"
    if [ "$status" -eq 0 ]; then
        report PASS vale "${#FILES[@]}개 문서, error 없음"
    else
        report FAIL vale "error 를 고친다. warning 은 종료 코드에 반영되지 않는다"
    fi
fi

echo
echo "결과: PASS $pass_count, FAIL $fail_count, SKIP $skip_count"

if [ "$fail_count" -gt 0 ]; then
    echo
    echo "규약: docs/standards/writing-style.md" >&2
    exit 1
fi
exit 0
