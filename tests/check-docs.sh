#!/usr/bin/env bash
# docs/ 문서 규약 검증 스크립트.
#
# 검사 단계. --only 로 고른다. 기본은 전부다.
#   frontmatter  필수 property, summary 문체, type enum, 위치와 type 일치, status,
#                title 과 H1 일치, generated 문서의 generated_from
#   graph        id 중복, related 와 supersedes 대상. 저장소 전체를 봐야 답이 나온다
#   paths        백틱으로 감싼 로컬 경로의 링크 표기 위반
#   links        마크다운 링크 대상 존재 여부. 링크는 문서 기준 상대 경로다
#   urls         마크다운 링크 [text](url) 와 자동 링크 <url> 의 HTTP 응답
#
# 대상은 .md 와 .mdx 다. 훅이 두 확장자에 다 도는데 검사가 .md 만 보면 .mdx 는
# 훅이 돌면서도 아무것도 검사하지 않는다.
#
# frontmatter, graph, paths 는 docs/ 안만 본다. front matter 를 갖는 문서가 거기뿐이다.
# links 와 urls 는 저장소 루트 문서까지 본다. README.md 의 깨진 링크도 깨진 링크다.
#
# front matter 의 기계 계약(JSON Schema)과 수명주기는 tests/check-docs-metadata.sh 가 본다.
#
# 규약: docs/standards/documentation.md
#
# 사용법:
#   bash tests/check-docs.sh                     # 전체 검사
#   bash tests/check-docs.sh --only links        # 한 단계만
#   bash tests/check-docs.sh --only links,graph  # 여러 단계
#   bash tests/check-docs.sh --no-net            # urls 만 뺀 나머지 전부
#   bash tests/check-docs.sh --timeout 5         # URL 응답 대기 시간 변경
#
# --only 와 --no-net 은 둘 다 단계 목록을 정한다. 나중에 온 쪽이 이긴다.
#
# 이 스크립트는 모든 검사를 돌려 결과를 모으므로 set -e 를 쓰지 않는다.
# 예외 근거는 docs/standards/shell.md 에 있다.
#
# 종료 코드: FAIL 이 하나라도 있으면 1, 알 수 없는 옵션이면 2, 아니면 0

set -uo pipefail

# cd 뒤에는 상대 경로인 BASH_SOURCE 가 안 풀린다. --help 가 자기 파일을 읽으므로 먼저 절대 경로로 잡는다.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SELF="$SCRIPT_DIR/$(basename "${BASH_SOURCE[0]}")"

ALL_PHASES="frontmatter graph paths links urls"
NO_NET_PHASES="frontmatter graph paths links"

PHASES="$ALL_PHASES"
TIMEOUT=10

# 백틱으로 써도 되는 경로. 저장소에 실재하지만 링크 대상으로 부적절한 것들.
# index.md 가 없는 디렉터리는 링크 대상이 될 수 없으므로 여기 둔다.
BACKTICK_ALLOW=".env .git .gitignore .github .github/workflows"
BACKTICK_PATTERN="\`[^\`]\\+\`"

REQUIRED_KEYS="id title type status summary scope read_when"
TYPE_ENUM="index standard guide reference generated decision"

# summary 문체 검사. 문서 언어에 따라 규칙이 다르다. none 이면 검사하지 않는다.
SUMMARY_STYLE="en"

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
        --no-net)
            PHASES="$NO_NET_PHASES"
            shift
            ;;
        --timeout)
            if [ "$#" -lt 2 ]; then
                echo "FAIL: --timeout 값이 없다" >&2
                exit 2
            fi
            case "$2" in
                '' | *[!0-9]*)
                    echo "FAIL: --timeout 은 0 이상의 정수다: $2" >&2
                    exit 2
                    ;;
            esac
            TIMEOUT="$2"
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
total_skip=0

report() {
    # $1: 판정, $2: 대상, $3: 사유
    printf '%-4s %-64s %s\n' "$1" "$2" "${3:-}"
}

# 단계 출력은 파이프라인 안에서 만들어져 카운터가 서브셸에 갇힌다. 파일로 받아 세다.
tally() {
    # $1: 단계 출력 파일
    local p f s
    p="$(grep -c '^PASS' "$1" 2> /dev/null)" || true
    f="$(grep -c '^FAIL' "$1" 2> /dev/null)" || true
    s="$(grep -c '^SKIP' "$1" 2> /dev/null)" || true
    total_pass=$((total_pass + ${p:-0}))
    total_fail=$((total_fail + ${f:-0}))
    total_skip=$((total_skip + ${s:-0}))
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

# 링크와 URL 은 docs/ 밖에서도 깨진다. 훅은 모든 마크다운 변경에 도는데 검사 범위가
# docs/ 안이면 README.md 나 AGENTS.md 의 깨진 링크는 훅이 돌면서도 잡히지 않는다.
# front matter 가 없는 문서라 나머지 단계의 대상은 아니다.
LINK_FILES=("${DOC_FILES[@]}")
while IFS= read -r doc; do
    LINK_FILES[${#LINK_FILES[@]}]="$doc"
done < <(find "$REPO_ROOT" -maxdepth 1 -type f \( -name '*.md' -o -name '*.mdx' \) | sort)

# 임시 파일은 저장소 밖에 둔다. 저장소 안에 두면 실수로 커밋되거나 검사 대상에 섞인다.
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

rel_path() { printf '%s\n' "${1#"$REPO_ROOT"/}"; }

# ---------------------------------------------------------------- front matter

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

fm_has_key() {
    printf '%s\n' "$2" | grep -qE "^$1:"
}

fm_list() {
    printf '%s\n' "$2" | awk -v key="$1" '
        $0 ~ "^"key":" { inkey=1; next }
        inkey && /^[[:space:]]*-[[:space:]]*/ { sub(/^[[:space:]]*-[[:space:]]*/, ""); gsub(/^"|"$/, ""); print; next }
        inkey && /^[^[:space:]]/ { inkey=0 }'
}

# 문서 위치로 기대되는 type. 상위에 도메인 디렉터리가 붙어도 규칙은 같다.
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

status_allowed() {
    case "$1" in
        index) [ "$2" = "active" ] ;;
        standard) [[ "$2" =~ ^(draft|active|deprecated)$ ]] ;;
        guide) [[ "$2" =~ ^(draft|active|outdated)$ ]] ;;
        reference) [[ "$2" =~ ^(active|outdated|archived)$ ]] ;;
        generated) [[ "$2" =~ ^(current|stale)$ ]] ;;
        decision) [[ "$2" =~ ^(proposed|accepted|rejected|superseded)$ ]] ;;
        *) return 1 ;;
    esac
}

# 개조식 판정. 명사나 명사구로 끝나야 한다.
# ko 는 서술형 종결어미와 마침표, en 은 마침표를 위반으로 본다.
summary_style_ok() {
    case "$SUMMARY_STYLE" in
        ko)
            case "$1" in
                *. | *다 | *요 | *음\ 함) return 1 ;;
            esac
            ;;
        en)
            case "$1" in
                *.) return 1 ;;
            esac
            ;;
    esac
    return 0
}

echo "대상 문서: ${#DOC_FILES[@]}개 (링크와 URL 은 루트 문서까지 ${#LINK_FILES[@]}개)"

ID_LIST="$TMP_DIR/ids"
REF_LIST="$TMP_DIR/refs"
: > "$ID_LIST"
: > "$REF_LIST"

# graph 단계는 frontmatter 가 모은 id 와 참조를 쓴다. 둘 중 하나만 골라도 수집은 돈다.
if phase_on frontmatter || phase_on graph; then
    {
        for f in "${DOC_FILES[@]}"; do
            rel="$(rel_path "$f")"
            fm="$(front_matter "$f")"

            if [ -z "$fm" ]; then
                report FAIL "$rel" "front matter 없음"
                continue
            fi

            missing=""
            for k in $REQUIRED_KEYS; do
                fm_has_key "$k" "$fm" || missing="$missing $k"
            done
            if [ -n "$missing" ]; then
                report FAIL "$rel" "필수 property 누락:$missing"
                continue
            fi

            doc_id="$(fm_value id "$fm")"
            doc_type="$(fm_value type "$fm")"
            doc_status="$(fm_value status "$fm")"
            doc_title="$(fm_value title "$fm")"
            doc_summary="$(fm_value summary "$fm")"

            printf '%s\t%s\n' "$doc_id" "$rel" >> "$ID_LIST"
            for r in $(fm_list related "$fm") $(fm_list supersedes "$fm"); do
                printf '%s\t%s\n' "$r" "$rel" >> "$REF_LIST"
            done

            case " $TYPE_ENUM " in
                *" $doc_type "*) ;;
                *)
                    report FAIL "$rel" "type '$doc_type' 는 enum 밖 ($TYPE_ENUM)"
                    continue
                    ;;
            esac

            want="$(expected_type "$rel")"
            if [ -n "$want" ] && [ "$want" != "$doc_type" ]; then
                report FAIL "$rel" "위치 기준 type 은 '$want' 인데 '$doc_type'"
                continue
            fi

            if ! status_allowed "$doc_type" "$doc_status"; then
                report FAIL "$rel" "status '$doc_status' 는 type '$doc_type' 에 허용되지 않음"
                continue
            fi

            if ! summary_style_ok "$doc_summary"; then
                report FAIL "$rel" "summary 가 개조식이 아니다: '$doc_summary'"
                continue
            fi

            h1="$(grep -m1 '^# ' "$f" | sed 's/^# //')"
            if [ "$h1" != "$doc_title" ]; then
                report FAIL "$rel" "H1 '$h1' 이 title '$doc_title' 과 다름"
                continue
            fi

            if [ "$doc_type" = "generated" ] && ! fm_has_key generated_from "$fm"; then
                report FAIL "$rel" "type generated 인데 generated_from 없음"
                continue
            fi

            report PASS "$rel" "$doc_type/$doc_status"
        done
    } > "$TMP_DIR/fm.out"
fi

if phase_on frontmatter; then
    banner "front matter"
    cat "$TMP_DIR/fm.out"
    tally "$TMP_DIR/fm.out"
fi

# ---------------------------------------------------------------- 문서 그래프

if phase_on graph; then
    banner "문서 그래프"
    {
        dup="$(cut -f1 "$ID_LIST" | sort | uniq -d)"
        if [ -n "$dup" ]; then
            while IFS= read -r d; do
                [ -n "$d" ] || continue
                owners="$(awk -F'\t' -v id="$d" '$1 == id { printf "%s ", $2 }' "$ID_LIST")"
                report FAIL "id: $d" "중복: $owners"
            done <<< "$dup"
        else
            report PASS "id 중복" "$(wc -l < "$ID_LIST" | tr -d ' ')개 문서 id 가 모두 다름"
        fi

        while IFS=$'\t' read -r ref src; do
            [ -n "$ref" ] || continue
            if cut -f1 "$ID_LIST" | grep -qx "$ref"; then
                report PASS "$src -> id:$ref"
            else
                report FAIL "$src -> id:$ref" "그런 id 가 없음"
            fi
        done < "$REF_LIST"
    } > "$TMP_DIR/graph.out"
    cat "$TMP_DIR/graph.out"
    tally "$TMP_DIR/graph.out"
fi

# ---------------------------------------------------------------- 백틱 경로

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

# ---------------------------------------------------------------- 링크 대상

# 문서 기준 상대 경로를 저장소 루트 기준 경로로 편다.
# 문자열로만 푼다. 심링크를 따르지 않고 대상이 아직 없어도 답이 나온다.
# 저장소 밖으로 나가면 1 을 돌려준다.
# resolve_link DOC_DIR TARGET
resolve_link() {
    local rest="${1:+$1/}$2" out="" part
    while [ -n "$rest" ]; do
        case "$rest" in
            */*)
                part="${rest%%/*}"
                rest="${rest#*/}"
                ;;
            *)
                part="$rest"
                rest=""
                ;;
        esac
        case "$part" in
            '' | .) ;;
            ..)
                case "$out" in
                    '') return 1 ;;
                    */*) out="${out%/*}" ;;
                    *) out="" ;;
                esac
                ;;
            *) out="${out:+$out/}$part" ;;
        esac
    done
    printf '%s\n' "$out"
}

if phase_on links; then
    banner "링크 대상 (문서 기준 상대 경로)"
    {
        for f in "${LINK_FILES[@]}"; do
            rel="$(rel_path "$f")"
            dir="$(dirname "$rel")"
            [ "$dir" != "." ] || dir=""
            # 코드 블록 안은 예시이므로 제외한다.
            # 외부 링크는 urls 단계가 본다. 여기서는 대상 첫 글자가 아니라 스킴으로 거른다.
            awk '/^[[:space:]]*```/ { fence = !fence; next } !fence' "$f" \
                | grep -o '](\([^)][^)]*\))' 2> /dev/null \
                | sed 's/^](//; s/)$//; s/#.*$//' \
                | grep -vE '^$|^(https?|mailto|ftp|tel):' \
                | sort -u \
                | while IFS= read -r target; do
                    case "$target" in
                        /*)
                            report FAIL "$rel -> $target" "절대 경로는 쓰지 않는다. 문서 기준 상대 경로로 쓴다"
                            continue
                            ;;
                    esac
                    if ! resolved="$(resolve_link "$dir" "$target")"; then
                        report FAIL "$rel -> $target" "저장소 밖으로 나간다"
                    elif [ -e "$REPO_ROOT/$resolved" ]; then
                        report PASS "$rel -> $target" "$resolved"
                    elif [ -e "$REPO_ROOT/$target" ]; then
                        report FAIL "$rel -> $target" "저장소 루트 기준으로 쓰였다. 문서 기준 상대 경로로 고친다"
                    else
                        report FAIL "$rel -> $target" "대상 없음: $resolved"
                    fi
                done
        done
    } > "$TMP_DIR/links.out"
    cat "$TMP_DIR/links.out"
    tally "$TMP_DIR/links.out"
fi

# ---------------------------------------------------------------- URL

check_url() {
    local url="$1" code
    code="$(curl -sS -o /dev/null -w '%{http_code}' \
        --location --max-redirs 5 --connect-timeout "$TIMEOUT" --max-time $((TIMEOUT * 3)) \
        --retry 1 --user-agent 'doc-check' "$url" 2> /dev/null)"

    case "$code" in
        2*) report PASS "$url" "HTTP $code" ;;
        401 | 403) report PASS "$url" "HTTP $code (인증 필요, 페이지는 존재)" ;;
        3*) report PASS "$url" "HTTP $code (리다이렉트)" ;;
        404 | 410) report FAIL "$url" "HTTP $code" ;;
        000 | "") report SKIP "$url" "응답 없음 (사내망 접근 또는 네트워크 확인 필요)" ;;
        *) report FAIL "$url" "HTTP $code" ;;
    esac
}

if phase_on urls; then
    banner "URL"
    # 코드 블록 안은 예시다. links 단계와 같은 기준으로 뺀다. 문서 구조 예시에 적힌
    # https://example.com/spec 을 실제로 두드리면 영원히 404 다.
    # 파일이 바뀌면 fence 상태를 되돌린다. 안 그러면 펜스 개수가 홀수인 문서 하나가
    # 뒤따르는 모든 문서를 통째로 코드 블록으로 만든다.
    awk 'FNR == 1 { fence = 0 }
         /^[[:space:]]*```/ { fence = !fence; next }
         !fence' "${LINK_FILES[@]}" > "$TMP_DIR/urls.src"
    {
        grep -ho '](http[^)]*)' "$TMP_DIR/urls.src" | sed 's/^](//; s/)$//'
        grep -ho '<http[^>]*>' "$TMP_DIR/urls.src" | tr -d '<>'
    } | sort -u > "$TMP_DIR/urls"

    while IFS= read -r url; do
        [ -n "$url" ] || continue
        check_url "$url"
    done < "$TMP_DIR/urls" > "$TMP_DIR/urls.out"
    cat "$TMP_DIR/urls.out"
    tally "$TMP_DIR/urls.out"
fi

echo
echo "결과: PASS $total_pass, FAIL $total_fail, SKIP $total_skip"

if [ "$total_fail" -gt 0 ]; then
    exit 1
fi
exit 0
