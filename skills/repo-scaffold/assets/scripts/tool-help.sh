#!/usr/bin/env bash
# 도구가 없을 때 어디를 읽고 무엇을 치면 되는지 답한다. 두 줄에서 네 줄이다.
#
# 검사 스크립트가 미설치 판정을 낼 때 이것을 부른다. 판정만 내고 끝내면 읽는 사람이
# 도구 이름으로 검색을 시작해야 하고, 그 검색이 매번 다른 설치 방법으로 이어진다.
# 그러면 tools.txt 가 고정한 버전이 사람마다 갈린다.
#
# 설치 명령의 버전은 tools.txt 에서 읽는다. 여기에 버전을 적지 않는다. 두 곳에
# 적으면 Renovate 가 한쪽만 올리고 다른 쪽이 조용히 낡는다.
#
# 여기 없는 이름을 물으면 안내 대신 그 사실을 낸다. 종료 코드는 그래도 0 이다.
# 안내가 없다고 검사를 실패시키면 도구 목록이 검사의 통과 조건이 된다.
#
# 사용법:
#   bash scripts/tool-help.sh shellcheck
#
# 종료 코드: 이름이 없어도 0, 알 수 없는 옵션이면 2

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
        echo "도구 이름이 필요하다" >&2
        exit 2
        ;;
    -*)
        echo "알 수 없는 옵션: $1" >&2
        exit 2
        ;;
esac

TOOL="$1"
INDENT="     "

# 검사 스크립트는 저장소 루트에서 돌지만 이 스크립트는 어디서 불려도 같은 답을 내야 한다.
TOOLS_FILE="tools.txt"
if root="$(git rev-parse --show-toplevel 2> /dev/null)"; then
    TOOLS_FILE="$root/tools.txt"
fi

# 문서 주소. 도구마다 한 줄이다.
# 배포 페이지가 여러 번 옮겨 다닌 도구는 개발 저장소를 가리킨다. 주소가 오래 산다.
home_of() {
    case "$1" in
        just) echo "https://just.systems" ;;
        prek) echo "https://prek.j178.dev" ;;
        uv) echo "https://docs.astral.sh/uv" ;;
        ruff) echo "https://docs.astral.sh/ruff" ;;
        mypy) echo "https://github.com/python/mypy" ;;
        pytest) echo "https://docs.pytest.org" ;;
        shellcheck) echo "https://www.shellcheck.net" ;;
        shfmt) echo "https://github.com/mvdan/sh" ;;
        actionlint) echo "https://github.com/rhysd/actionlint" ;;
        zizmor) echo "https://docs.zizmor.sh" ;;
        rumdl) echo "https://github.com/rvben/rumdl" ;;
        vale) echo "https://vale.sh" ;;
        yamllint) echo "https://github.com/adrienverge/yamllint" ;;
        check-jsonschema) echo "https://github.com/python-jsonschema/check-jsonschema" ;;
        yq) echo "https://github.com/mikefarah/yq" ;;
        jq) echo "https://github.com/jqlang/jq" ;;
        gh) echo "https://cli.github.com" ;;
        lychee) echo "https://github.com/lycheeverse/lychee" ;;
        gitleaks) echo "https://github.com/gitleaks/gitleaks" ;;
        osv-scanner) echo "https://github.com/google/osv-scanner" ;;
        node | npm) echo "https://nodejs.org" ;;
        commitlint) echo "https://commitlint.js.org" ;;
        *) return 1 ;;
    esac
}

# tools.txt 의 설치 인자. 실행 파일 이름으로 찾는다. 없으면 빈 문자열이다.
spec_of() {
    [ -f "$TOOLS_FILE" ] || return 0
    awk -v name="$1" '
        /^[[:space:]]*#/ || NF == 0 { next }
        { binary = (NF >= 3) ? $3 : $1 }
        binary == name && $2 == "uv" { print $1; exit }
    ' "$TOOLS_FILE"
}

# 설치 방법. tools.txt 가 버전을 갖는 도구는 그 줄에서 만들고, 나머지는 여기 적는다.
install_of() {
    local spec
    spec="$(spec_of "$1")"
    if [ -n "$spec" ]; then
        echo "uv tool install $spec"
        return 0
    fi
    case "$1" in
        uv) echo "문서의 설치 안내를 따른다. PyPI 밖이다" ;;
        node | npm) echo "문서에서 LTS 를 깐다. npm 은 함께 깔린다" ;;
        commitlint)
            echo "npm ci"
            echo "설치는 node_modules 안이다. PATH 에서 찾지 않는다"
            ;;
        ruff | mypy | pytest)
            echo "uv sync"
            echo "프로젝트 의존성이다. uv tool install 로 깔지 않는다"
            ;;
        gh) echo "문서의 플랫폼별 안내를 따른다" ;;
        lychee | gitleaks | osv-scanner)
            echo "깔지 않아도 된다. CI 가 고정된 버전으로 대신 돌린다"
            echo "직접 깔려면 문서의 배포판 안내를 따른다"
            ;;
        yq | jq) echo "PyPI 밖이다. 문서의 플랫폼별 안내를 따른다" ;;
        *) return 1 ;;
    esac
}

home="$(home_of "$TOOL")" || home=""
install="$(install_of "$TOOL")" || install=""

if [ -z "$home" ] && [ -z "$install" ]; then
    printf '%s%s\n' "$INDENT" "설치 안내가 없다. scripts/tool-help.sh 에 $TOOL 을 추가한다"
    exit 0
fi

[ -n "$home" ] && printf '%s문서: %s\n' "$INDENT" "$home"

# 첫 줄이 설치 명령이고 뒤따르는 줄은 그 명령에 붙는 단서다.
label="설치: "
while IFS= read -r line; do
    [ -n "$line" ] || continue
    printf '%s%s%s\n' "$INDENT" "$label" "$line"
    label="      "
done <<< "$install"

exit 0
