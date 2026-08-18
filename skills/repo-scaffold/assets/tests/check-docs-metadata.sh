#!/usr/bin/env bash
# front matter 의 기계 계약 검증. docs/ 아래 문서만 본다.
#
# 검사 단계. --only 로 고른다. 기본은 전부다.
#   schema  schemas/docs-frontmatter.schema.json 대조. 키 이름 오타와 값 형식을 잡는다
#   graph   scripts/docs_graph.py. id, 참조, 대체 관계, 선언된 소스, 도달 가능성
#   time    scripts/docs_freshness.py --only time. last_reviewed 가 검토 주기를 넘겼는가
#   drift   scripts/docs_freshness.py --only drift. sources 가 검토 이후에 바뀌었는가
#
# time 과 drift 는 서로 독립이다. time 은 시간이 흐른 것뿐이라 WARN 이고 종료 코드에
# 반영되지 않는다. drift 는 문서와 코드가 갈라졌다는 뜻이라 FAIL 이다. 그래서 pre-push
# 훅은 drift 만 부르고 time 은 예약 CI 가 부른다.
#
# check-jsonschema 에는 front matter 리더가 없다. 그래서 저장소 밖 임시 디렉터리에
# YAML 로 떼어내 검사하고, 보고할 때 임시 경로를 원래 문서 경로로 되돌린다.
#
# 파이썬 검사기는 PEP-723 인라인 메타데이터를 갖고 uv run --script 로 돈다.
# 대상 저장소에 pyproject.toml 이 없어도 되고 의존성도 없다.
#
# 도구가 없으면 로컬에서는 SKIP, CI(환경변수 CI=true)에서는 FAIL 이다.
# 다만 스키마 파일 자체가 없는 것은 SKIP 이 아니라 FAIL 이다. 계약이 없으면
# 검사가 통과한 것이 아니라 검사가 없는 것이다.
#
# 이 스크립트는 모든 검사를 돌려 결과를 모으므로 set -e 를 쓰지 않는다.
# 예외 근거는 docs/standards/shell.md 에 있다.
#
# 사용법:
#   bash tests/check-docs-metadata.sh                  # 전체 검사
#   bash tests/check-docs-metadata.sh --only schema    # 한 단계만
#   bash tests/check-docs-metadata.sh --only graph,drift
#
# 종료 코드: FAIL 이 하나라도 있으면 1, 알 수 없는 옵션이면 2, 아니면 0

set -uo pipefail

# cd 뒤에는 상대 경로인 BASH_SOURCE 가 안 풀린다. --help 가 자기 파일을 읽으므로 먼저 절대 경로로 잡는다.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SELF="$SCRIPT_DIR/$(basename "${BASH_SOURCE[0]}")"

ALL_PHASES="schema graph time drift"
PHASES="$ALL_PHASES"

SCHEMA="schemas/docs-frontmatter.schema.json"
GRAPH_SCRIPT="scripts/docs_graph.py"
FRESHNESS_SCRIPT="scripts/docs_freshness.py"

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
    printf '%-4s %-22s %s\n' "$1" "$2" "${3:-}"
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

DOCS_ROOT="$REPO_ROOT/docs"
DOC_FILES=()
if [ -d "$DOCS_ROOT" ]; then
    while IFS= read -r doc; do
        DOC_FILES[${#DOC_FILES[@]}]="$doc"
    done < <(find "$DOCS_ROOT" -type f \( -name '*.md' -o -name '*.mdx' \) | sort)
fi

if [ "${#DOC_FILES[@]}" -eq 0 ]; then
    echo "SKIP docs/ 에 문서가 없다"
    exit 0
fi

echo "대상 문서: ${#DOC_FILES[@]}개"

# 임시 파일은 저장소 밖에 둔다. 저장소 안에 두면 실수로 커밋되거나 검사 대상에 섞인다.
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

# ---------------------------------------------------------------- JSON Schema

front_matter() {
    awk 'NR==1 && $0 != "---" { exit }
         NR==1 { next }
         /^---[[:space:]]*$/ { exit }
         { print }' "$1"
}

# 임시 파일 이름은 자릿수를 고정한다. doc-1 이 doc-11 의 앞부분과 겹치면
# 경로 되돌리기가 다른 문서를 건드린다.
extract_front_matter() {
    local index=0 rel name fm
    : > "$TMP_DIR/map.sed"
    for doc in "${DOC_FILES[@]}"; do
        rel="${doc#"$REPO_ROOT"/}"
        fm="$(front_matter "$doc")"
        if [ -z "$fm" ]; then
            report FAIL "$rel" "front matter 가 없다. --- 로 감싼 블록으로 시작한다"
            continue
        fi
        index=$((index + 1))
        name="$(printf 'doc-%04d.yaml' "$index")"
        printf '%s\n' "$fm" > "$TMP_DIR/$name"
        printf 's|%s|%s|g\n' "$name" "$(printf '%s' "$rel" | sed 's/[\\&|]/\\&/g')" \
            >> "$TMP_DIR/map.sed"
    done
    EXTRACTED="$index"
}

if phase_on schema; then
    banner "JSON Schema ($SCHEMA)"
    if [ ! -f "$SCHEMA" ]; then
        report FAIL "$SCHEMA" "없다. front matter 의 기계 계약이 저장소에 있어야 한다"
    elif require_tool check-jsonschema; then
        EXTRACTED=0
        extract_front_matter
        # 스키마도 임시 디렉터리로 옮긴다. 검사기를 임시 디렉터리 안에서 파일 이름만 주고
        # 부르기 위해서다. Git Bash 는 / 로 시작하는 인자를 Windows 경로로 바꿔버려서,
        # 절대 경로를 넘기면 출력에 나오는 이름이 map.sed 와 어긋난다.
        cp "$SCHEMA" "$TMP_DIR/schema.json"
        if [ "$EXTRACTED" -eq 0 ]; then
            report SKIP "$SCHEMA" "front matter 를 가진 문서가 없다"
        elif out="$(cd "$TMP_DIR" && check-jsonschema --schemafile schema.json doc-*.yaml 2>&1)"; then
            report PASS "$SCHEMA" "$EXTRACTED개 문서가 계약을 지킨다"
        else
            printf '%s\n' "$out" | sed -f "$TMP_DIR/map.sed"
            report FAIL "$SCHEMA" "front matter 를 고친다. 규약은 docs/standards/documentation.md 다"
        fi
    fi
fi

# ---------------------------------------------------------------- 파이썬 검사기

# uv run --script 로 PEP-723 스크립트를 돌리고 판정을 남긴다.
# run_checker LABEL SCRIPT [ARG ...]
run_checker() {
    local label="$1" script="$2"
    shift 2
    if [ ! -f "$script" ]; then
        report FAIL "$script" "없다. 검사기가 저장소에 있어야 한다"
        return
    fi
    if ! require_tool uv; then
        return
    fi
    if out="$(uv run --script "$script" "$@" 2>&1)"; then
        printf '%s\n' "$out"
        report PASS "$label" "지적 없음"
    else
        printf '%s\n' "$out"
        report FAIL "$label" "위 지적을 고친다"
    fi
}

if phase_on graph; then
    banner "문서 그래프 ($GRAPH_SCRIPT)"
    run_checker docs-graph "$GRAPH_SCRIPT"
fi

if phase_on time; then
    banner "시간 기준 신선도 ($FRESHNESS_SCRIPT)"
    run_checker docs-time "$FRESHNESS_SCRIPT" --only time
fi

if phase_on drift; then
    banner "source drift ($FRESHNESS_SCRIPT)"
    run_checker docs-drift "$FRESHNESS_SCRIPT" --only drift
fi

echo
echo "결과: PASS $pass_count, FAIL $fail_count, SKIP $skip_count"

if [ "$fail_count" -gt 0 ]; then
    echo
    echo "규약: docs/standards/documentation.md" >&2
    exit 1
fi
exit 0
