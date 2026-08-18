#!/usr/bin/env bash
# 선언된 도구 버전이 파일마다 같은지 검사한다.
#
# 같은 도구의 버전이 여러 파일에 적혀 있다. 워크플로는 tools.txt 를 읽을 수 없는 자리가
# 있어서 env 로 다시 적고, 파이썬 도구는 pyproject.toml 과 워크플로 양쪽에 있다.
# 복제 자체는 지금 구조에서 피할 수 없다. 피할 수 있는 것은 복제가 조용히 갈리는 것이다.
# 한 곳만 갱신되면 CI 와 개발자 머신이 다른 버전으로 돌고, 그동안 검사는 초록 불이다.
#
# 선언 위치는 셋이다.
#   tools.txt              개발자 머신에 까는 도구. 원본
#   pyproject.toml         [dependency-groups] 의 dev. ruff 와 mypy 의 원본
#   .github/workflows/*.yml  env 의 <NAME>_VERSION. 위 둘의 복제
#
# 원본이 없는 버전은 복제가 아니라 단일 출처다. 갈릴 상대가 없으므로 통과시킨다.
# CI 전용 도구는 아예 대조를 걸지 않도록 아래 CI_ONLY 에 이름과 이유를 적는다.
#
# rust-just 는 검사 대상이 아니다. 워크플로가 env 에 복제하지 않고 tools.txt 를 awk 로
# 직접 읽는다. 이 스크립트가 없어도 갈릴 수 없는 형태이고, 나머지가 가야 할 방향이다.
#
# 이 스크립트는 도구를 쓰지 않는다. bash, awk, grep, sed 만 쓴다.
# 버전 선언이 갈렸는지는 파일을 읽으면 답이 나오고, 그 답에 도구가 필요하지 않다.
#
# 이 스크립트는 모든 검사를 돌려 결과를 모으므로 set -e 를 쓰지 않는다.
# 예외 근거는 docs/standards/shell.md 에 있다.
#
# 사용법:
#   bash tests/check-tool-versions.sh
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

TOOLS_FILE="tools.txt"
PYPROJECT="pyproject.toml"
WORKFLOW_DIR=".github/workflows"

# 워크플로 env 이름과 원본 패키지 이름의 대응. 이름이 유도되지 않으므로 적어 둔다.
# 왼쪽은 <NAME>_VERSION 의 <NAME>, 오른쪽은 tools.txt 나 pyproject.toml 의 패키지 이름이다.
ENV_TO_PACKAGE="
YQ|yq
SHELLCHECK|shellcheck-py
SHFMT|shfmt-py
ACTIONLINT|actionlint-py
ZIZMOR|zizmor
RUMDL|rumdl
VALE|vale
CHECK_JSONSCHEMA|check-jsonschema
RUFF|ruff
MYPY|mypy
"

# 워크플로에만 있는 버전. 대조할 원본이 없으므로 검사 대상이 아니다.
# 줄마다 이유를 적는다. 근거 없는 제외는 검사를 지우는 것과 같다.
CI_ONLY="
LYCHEE|PyPI 밖 도구. 네트워크가 필요해 개발자 머신에 요구하지 않는다
GITLEAKS|PyPI 밖 도구. 권위 있는 스캔은 CI 전용 잡이 한다
OSV_SCANNER|PyPI 밖 도구. 잠긴 의존성의 취약점만 본다
"

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

# 표에서 키에 대응하는 값을 찾는다. 없으면 빈 문자열이다.
lookup() {
    # $1: 표, $2: 키
    printf '%s\n' "$1" | awk -F'|' -v key="$2" '$1 == key { print $2; exit }'
}

# 원본 선언을 모은다. "패키지<탭>버전<탭>선언한 파일" 한 줄에 하나.
SOURCES="$(
    if [ -f "$TOOLS_FILE" ]; then
        awk -v f="$TOOLS_FILE" '
            /^#/ || NF == 0 { next }
            $1 ~ /==/ {
                split($1, a, "==")
                print a[1] "\t" a[2] "\t" f
            }' "$TOOLS_FILE"
    fi
    if [ -f "$PYPROJECT" ]; then
        # [dependency-groups] 의 dev 목록만 본다. "pkg==ver" 꼴만 세다.
        awk -v f="$PYPROJECT" '
            /^\[dependency-groups\]/ { ingroup = 1; next }
            /^\[/ { ingroup = 0 }
            ingroup && match($0, /"[A-Za-z0-9._-]+==[0-9][^"]*"/) {
                spec = substr($0, RSTART + 1, RLENGTH - 2)
                split(spec, a, "==")
                print a[1] "\t" a[2] "\t" f
            }' "$PYPROJECT"
    fi
)"

echo "[1/1] 워크플로 env 와 원본 선언 대조"

if [ -z "$SOURCES" ]; then
    report FAIL "$TOOLS_FILE" "원본 선언을 하나도 읽지 못했다. 도구 버전의 단일 출처가 없다"
elif [ ! -d "$WORKFLOW_DIR" ]; then
    report SKIP "$WORKFLOW_DIR" "없다. 대조할 복제가 없다"
else
    # 워크플로 env 의 <NAME>_VERSION 을 전부 뽑는다. 같은 이름이 여러 파일에 있으면 각각 본다.
    while IFS=$'\t' read -r file name value; do
        [ -n "$name" ] || continue

        if [ -n "$(lookup "$CI_ONLY" "$name")" ]; then
            continue
        fi

        pkg="$(lookup "$ENV_TO_PACKAGE" "$name")"
        if [ -z "$pkg" ]; then
            report FAIL "$file: ${name}_VERSION" \
                "어느 원본의 복제인지 알 수 없다. 이 스크립트의 ENV_TO_PACKAGE 나 CI_ONLY 에 넣는다"
            continue
        fi

        want="$(printf '%s\n' "$SOURCES" | awk -F'\t' -v p="$pkg" '$1 == p { print $2; exit }')"
        origin="$(printf '%s\n' "$SOURCES" | awk -F'\t' -v p="$pkg" '$1 == p { print $3; exit }')"
        if [ -z "$want" ]; then
            # 원본이 없으면 복제가 아니다. 파이썬을 쓰지 않는 저장소에는 pyproject.toml 이
            # 없고, 그때 워크플로 env 가 그 도구의 단일 출처다. 갈릴 상대가 없다.
            report PASS "$file: ${name}_VERSION" \
                "$pkg $value (원본이 없다. 여기가 단일 출처다)"
            continue
        fi

        # yq 의 릴리스 태그는 v 로 시작하고 tools.txt 는 그러지 않는다. 앞의 v 한 글자를 뗀다.
        if [ "$want" = "${value#v}" ]; then
            report PASS "$file: ${name}_VERSION" "$pkg $want ($origin 과 같다)"
        else
            report FAIL "$file: ${name}_VERSION" \
                "$value 인데 $origin 은 $want. 둘을 같게 맞춘다"
        fi
    done < <(
        grep -rhn '^  [A-Z][A-Z0-9_]*_VERSION:' "$WORKFLOW_DIR" --include='*.yml' --include='*.yaml' -H \
            | sed 's/^\([^:]*\):[0-9]*:  \([A-Z][A-Z0-9_]*\)_VERSION:[[:space:]]*"\?\([^"]*\)"\?$/\1\t\2\t\3/'
    )
fi

echo
echo "결과: PASS $pass_count, FAIL $fail_count, SKIP $skip_count"

if [ "$fail_count" -gt 0 ]; then
    echo
    echo "규약: docs/standards/github-actions.md" >&2
    exit 1
fi
exit 0
