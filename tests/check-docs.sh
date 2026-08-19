#!/usr/bin/env bash
# docs/ 문서 규약 검증 스크립트.
#
# 이 스크립트가 보는 것은 서로 다른 두 세계를 잇는 규칙뿐이다. 한 세계 안에서 끝나는
# 규칙은 표준 도구가 이미 갖고 있고, 같은 규칙을 두 곳에 두면 한쪽만 고쳤을 때 조용히
# 갈린다. 소유권 표는 docs/standards/documentation.md 에 있다.
#
# 검사 단계. --only 로 고른다. 기본은 전부다.
#   title      front matter 의 title 과 본문 H1 이 같은가. front matter 와 본문을 잇는다
#   placement  파일 위치가 요구하는 type 과 선언된 type 이 같은가. front matter 와 경로를 잇는다
#   paths      백틱으로 감싼 로컬 경로의 링크 표기 위반. 산문과 파일시스템을 잇는다
#
# 대상은 .md 와 .mdx 다. 훅이 두 확장자에 다 도는데 검사가 .md 만 보면 .mdx 는
# 훅이 돌면서도 아무것도 검사하지 않는다. 대상 범위는 docs/ 안이다. front matter 를
# 갖는 문서가 거기뿐이다.
#
# 여기서 보지 않는 것과 그 주인:
#   front matter 필수 키, type enum, status, summary 문체   schemas/docs-frontmatter.schema.json
#   id 중복, related, supersedes, sources, 도달 가능성       scripts/docs_graph.py
#   링크 대상 존재와 앵커                                    rumdl 의 MD057, MD051
#   외부 URL                                                 lychee
#
# 이 스크립트는 도구를 하나도 쓰지 않는다. bash, awk, grep, sed, git 만 쓴다.
# 다른 검사기의 백업이라서가 아니라 이 세 규칙에 도구가 필요 없어서다.
#
# 규약: docs/standards/documentation.md
#
# 사용법:
#   bash tests/check-docs.sh                        # 전체 검사
#   bash tests/check-docs.sh --only paths           # 한 단계만
#   bash tests/check-docs.sh --only title,placement # 여러 단계
#
# 이 스크립트는 모든 검사를 돌려 결과를 모으므로 set -e 를 쓰지 않는다.
# 예외 근거는 docs/standards/shell.md 에 있다.
#
# 종료 코드: FAIL 이 하나라도 있으면 1, 알 수 없는 옵션이면 2, 아니면 0

set -uo pipefail

# cd 뒤에는 상대 경로인 BASH_SOURCE 가 안 풀린다. --help 가 자기 파일을 읽으므로 먼저 절대 경로로 잡는다.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SELF="$SCRIPT_DIR/$(basename "${BASH_SOURCE[0]}")"

ALL_PHASES="title placement paths"
PHASES="$ALL_PHASES"

# 백틱으로 써도 되는 경로. 저장소에 실재하지만 링크 대상으로 부적절한 것들.
# index.md 가 없는 디렉터리는 링크 대상이 될 수 없으므로 여기 둔다.
BACKTICK_ALLOW=".env .git .gitignore .github .github/workflows"
BACKTICK_PATTERN="\`[^\`]\\+\`"

# 필수 키가 없을 때 가리킬 곳. 그 검사는 이 스크립트의 일이 아니다.
SCHEMA_HINT="schemas/docs-frontmatter.schema.json 이 본다"

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

REPO_ROOT="$(git rev-parse --show-toplevel 2> /dev/null)" || {
    echo "FAIL: git 저장소가 아니다" >&2
    exit 1
}
cd "$REPO_ROOT" || exit 1
DOCS_ROOT="$REPO_ROOT/docs"

phase_on() {
    case " $PHASES " in
        *" $1 "*) return 0 ;;
    esac
    return 1
}

total_pass=0
total_fail=0

report() {
    # $1: 판정, $2: 대상, $3: 사유
    printf '%-4s %-64s %s\n' "$1" "$2" "${3:-}"
}

# 단계 출력은 파이프라인 안에서 만들어져 카운터가 서브셸에 갇힌다. 파일로 받아 세다.
tally() {
    # $1: 단계 출력 파일
    local p f
    p="$(grep -c '^PASS' "$1" 2> /dev/null)" || true
    f="$(grep -c '^FAIL' "$1" 2> /dev/null)" || true
    total_pass=$((total_pass + ${p:-0}))
    total_fail=$((total_fail + ${f:-0}))
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

if [ ! -d "$DOCS_ROOT" ]; then
    echo "FAIL: $DOCS_ROOT 가 없다" >&2
    exit 1
fi

DOC_FILES=()
while IFS= read -r doc; do
    DOC_FILES[${#DOC_FILES[@]}]="$doc"
done < <(find "$DOCS_ROOT" -type f \( -name '*.md' -o -name '*.mdx' \) | sort)

if [ "${#DOC_FILES[@]}" -eq 0 ]; then
    echo "FAIL: $DOCS_ROOT 에 문서가 없다" >&2
    exit 1
fi

# 임시 파일은 저장소 밖에 둔다. 저장소 안에 두면 실수로 커밋되거나 검사 대상에 섞인다.
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

rel_path() { printf '%s\n' "${1#"$REPO_ROOT"/}"; }

front_matter() {
    awk 'NR==1 && $0 != "---" { exit }
         NR==1 { next }
         /^---[[:space:]]*$/ { exit }
         { print }' "$1"
}

fm_value() {
    printf '%s\n' "$2" | sed -n "s/^$1:[[:space:]]*//p" | head -1 \
        | sed 's/^"\(.*\)"$/\1/; s/^'"'"'\(.*\)'"'"'$/\1/'
}

echo "대상 문서: ${#DOC_FILES[@]}개"

# ---------------------------------------------------------------- title 과 H1

# 스키마는 본문을 볼 수 없다. 둘이 같은지는 여기서만 답이 나온다.
if phase_on title; then
    banner "title 과 본문 H1"
    {
        for f in "${DOC_FILES[@]}"; do
            rel="$(rel_path "$f")"
            fm="$(front_matter "$f")"
            doc_title="$(fm_value title "$fm")"
            h1="$(grep -m1 '^# ' "$f" | sed 's/^# //')"

            if [ -z "$doc_title" ]; then
                report FAIL "$rel" "front matter 에 title 이 없다. 필수 키는 $SCHEMA_HINT"
            elif [ "$h1" != "$doc_title" ]; then
                report FAIL "$rel" "H1 '$h1' 이 title '$doc_title' 과 다름"
            else
                report PASS "$rel" "$doc_title"
            fi
        done
    } > "$TMP_DIR/title.out"
    cat "$TMP_DIR/title.out"
    tally "$TMP_DIR/title.out"
fi

# ---------------------------------------------------------------- 위치와 type

# 문서 위치로 기대되는 type. 상위에 도메인 디렉터리가 붙어도 규칙은 같다.
# 아는 디렉터리가 아니면 빈 값이고 그때는 판정하지 않는다.
expected_type() {
    local rel="$1" parent
    case "$rel" in
        */index.md | index.md)
            echo "index"
            return
            ;;
    esac
    parent="$(basename "$(dirname "$rel")")"
    case "$parent" in
        standards) echo "standard" ;;
        guides) echo "guide" ;;
        references) echo "reference" ;;
        generated) echo "generated" ;;
        # architecture/ 는 그 자체가 참고 자료이고 그 아래 adr/ 만 결정 기록이다.
        architecture) echo "reference" ;;
        adr) echo "decision" ;;
        *) echo "" ;;
    esac
}

# 스키마는 자기가 검사하는 문서의 경로를 모른다. 위치와 type 의 일치는 여기서만 답이 나온다.
if phase_on placement; then
    banner "위치와 type"
    {
        for f in "${DOC_FILES[@]}"; do
            rel="$(rel_path "$f")"
            fm="$(front_matter "$f")"
            doc_type="$(fm_value type "$fm")"
            want="$(expected_type "$rel")"

            if [ -z "$doc_type" ]; then
                report FAIL "$rel" "front matter 에 type 이 없다. 필수 키는 $SCHEMA_HINT"
            elif [ -z "$want" ]; then
                report PASS "$rel" "$doc_type (위치가 type 을 요구하지 않는 디렉터리)"
            elif [ "$want" != "$doc_type" ]; then
                report FAIL "$rel" "위치 기준 type 은 '$want' 인데 '$doc_type'"
            else
                report PASS "$rel" "$doc_type"
            fi
        done
    } > "$TMP_DIR/placement.out"
    cat "$TMP_DIR/placement.out"
    tally "$TMP_DIR/placement.out"
fi

# ---------------------------------------------------------------- 백틱 경로

# rumdl 은 링크 대상을 본다. 백틱 안의 문자열이 실재하는 저장소 경로인지는 보지 않는다.
if phase_on paths; then
    banner "백틱 경로"
    # 코드 블록 안은 규약 예외이므로 제외한다. 파일이 바뀌면 fence 상태를 되돌린다.
    awk 'FNR == 1 { fence = 0 }
         /^[[:space:]]*```/ { fence = !fence; next }
         !fence' "${DOC_FILES[@]}" \
        | grep -o "$BACKTICK_PATTERN" \
        | tr -d '`' \
        | sed 's:/*$::' \
        | grep -E '(/|\.(md|yaml|yml|sh|properties|example|Dockerfile))' \
        | grep -v '^http' \
        | grep -v '[{}*]' \
        | sort -u \
        | while IFS= read -r token; do
            case " $BACKTICK_ALLOW " in
                *" $token "*) continue ;;
            esac
            # gitignore 대상은 다른 저장소이거나 산출물이다. 링크 대상이 아니다.
            if git -C "$REPO_ROOT" check-ignore -q "$token" 2> /dev/null; then
                report PASS "$token" "(다른 저장소 또는 무시 대상)"
            elif [ -e "$REPO_ROOT/$token" ]; then
                report FAIL "$token" "저장소 안 경로는 링크로 쓴다"
            else
                report PASS "$token" "(저장소 밖 경로)"
            fi
        done > "$TMP_DIR/paths.out"
    cat "$TMP_DIR/paths.out"
    tally "$TMP_DIR/paths.out"
fi

echo
echo "결과: PASS $total_pass, FAIL $total_fail"

if [ "$total_fail" -gt 0 ]; then
    echo
    echo "규약: docs/standards/documentation.md" >&2
    exit 1
fi
exit 0
