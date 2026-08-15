#!/usr/bin/env bash
# docs/ 문서 규약 검증 스크립트.
#
# 검사 대상: docs/ 하위 모든 마크다운 문서
#   1. front matter (필수 property, summary 문체, type enum, 위치와 type 일치,
#      status, title 과 H1 일치, id 중복, related 대상)
#   2. 백틱으로 감싼 로컬 경로의 링크 표기 위반
#   3. 마크다운 링크 대상 존재 여부 (저장소 루트 기준 상대 경로)
#   4. 마크다운 링크 [text](url) 와 자동 링크 <url> 의 HTTP 응답
#
# 규약: docs/standards/documentation.md
#
# 사용법:
#   bash tests/check-docs.sh              # 전체 검사
#   bash tests/check-docs.sh --no-net     # URL 검사 제외
#   bash tests/check-docs.sh --timeout 5  # URL 응답 대기 시간 변경
#
# 종료 코드: FAIL 이 하나라도 있으면 1, 아니면 0

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOCS_ROOT="$REPO_ROOT/docs"

CHECK_NET=1
TIMEOUT=10

# 백틱으로 써도 되는 경로. 저장소에 실재하지만 링크 대상으로 부적절한 것들.
# index.md 가 없는 디렉터리는 링크 대상이 될 수 없으므로 여기 둔다.
BACKTICK_ALLOW=".env .git .gitignore .github .github/workflows"
BACKTICK_PATTERN="\`[^\`]\\+\`"

REQUIRED_KEYS="id title type status summary scope read_when"
TYPE_ENUM="index standard guide reference generated"

# summary 문체 검사. 문서 언어에 따라 규칙이 다르다. none 이면 검사하지 않는다.
SUMMARY_STYLE="{{SUMMARY_STYLE}}"

while [ $# -gt 0 ]; do
    case "$1" in
        --no-net)
            CHECK_NET=0
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
            sed -n '2,/^$/p' "${BASH_SOURCE[0]}"
            exit 0
            ;;
        *)
            echo "알 수 없는 옵션: $1" >&2
            exit 2
            ;;
    esac
done

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
    printf '%-4s %-64s %s\n' "$1" "$2" "${3:-}"
}

if [ ! -d "$DOCS_ROOT" ]; then
    echo "FAIL: $DOCS_ROOT 가 없다" >&2
    exit 1
fi

DOC_FILES=()
while IFS= read -r doc; do
    DOC_FILES[${#DOC_FILES[@]}]="$doc"
done < <(find "$DOCS_ROOT" -type f -name '*.md' | sort)

if [ "${#DOC_FILES[@]}" -eq 0 ]; then
    echo "FAIL: $DOCS_ROOT 에 문서가 없다" >&2
    exit 1
fi

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

echo "대상 문서: ${#DOC_FILES[@]}개"
echo
echo "[1/4] front matter"

ID_LIST="$TMP_DIR/ids"
REF_LIST="$TMP_DIR/refs"
: > "$ID_LIST"
: > "$REF_LIST"

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

    dup="$(cut -f1 "$ID_LIST" | sort | uniq -d)"
    if [ -n "$dup" ]; then
        while IFS= read -r d; do
            [ -n "$d" ] || continue
            owners="$(awk -F'\t' -v id="$d" '$1 == id { printf "%s ", $2 }' "$ID_LIST")"
            report FAIL "id: $d" "중복: $owners"
        done <<< "$dup"
    fi

    while IFS=$'\t' read -r ref src; do
        [ -n "$ref" ] || continue
        if cut -f1 "$ID_LIST" | grep -qx "$ref"; then
            report PASS "$src -> id:$ref"
        else
            report FAIL "$src -> id:$ref" "그런 id 가 없음"
        fi
    done < "$REF_LIST"
} > "$TMP_DIR/fm.out"

cat "$TMP_DIR/fm.out"
fm_fail=$(grep -c '^FAIL' "$TMP_DIR/fm.out" || true)
fm_pass=$(grep -c '^PASS' "$TMP_DIR/fm.out" || true)

# ---------------------------------------------------------------- 백틱 경로

echo
echo "[2/4] 백틱 경로"
# 코드 블록 안은 규약 예외이므로 제외한다.
awk '/^[[:space:]]*```/ { fence = !fence; next } !fence' "${DOC_FILES[@]}" \
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
path_fail=$(grep -c '^FAIL' "$TMP_DIR/paths.out" || true)
path_pass=$(grep -c '^PASS' "$TMP_DIR/paths.out" || true)

# ---------------------------------------------------------------- 링크 대상

echo
echo "[3/4] 링크 대상 (저장소 루트 기준)"
{
    for f in "${DOC_FILES[@]}"; do
        rel="$(rel_path "$f")"
        awk '/^[[:space:]]*```/ { fence = !fence; next } !fence' "$f" \
            | grep -o '](\([^)h][^)]*\))' 2> /dev/null \
            | sed 's/^](//; s/)$//; s/#.*$//' \
            | grep -v '^$' \
            | sort -u \
            | while IFS= read -r target; do
                case "$target" in
                    /* | ./* | ../*)
                        report FAIL "$rel -> $target" "저장소 루트 기준 경로로 쓴다"
                        continue
                        ;;
                esac
                if [ -e "$REPO_ROOT/$target" ]; then
                    report PASS "$rel -> $target"
                else
                    report FAIL "$rel -> $target" "대상 없음"
                fi
            done
    done
} > "$TMP_DIR/links.out"
cat "$TMP_DIR/links.out"
rel_fail=$(grep -c '^FAIL' "$TMP_DIR/links.out" || true)
rel_pass=$(grep -c '^PASS' "$TMP_DIR/links.out" || true)

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

echo
echo "[4/4] URL"
url_fail=0
url_skip=0
url_pass=0
if [ "$CHECK_NET" -eq 0 ]; then
    echo "SKIP 옵션 --no-net 으로 URL 검사를 건너뛴다"
else
    {
        grep -ho '](http[^)]*)' "${DOC_FILES[@]}" | sed 's/^](//; s/)$//'
        grep -ho '<http[^>]*>' "${DOC_FILES[@]}" | tr -d '<>'
    } | sort -u > "$TMP_DIR/urls"

    while IFS= read -r url; do
        [ -n "$url" ] || continue
        check_url "$url"
    done < "$TMP_DIR/urls" > "$TMP_DIR/urls.out"
    cat "$TMP_DIR/urls.out"
    url_fail=$(grep -c '^FAIL' "$TMP_DIR/urls.out" || true)
    url_skip=$(grep -c '^SKIP' "$TMP_DIR/urls.out" || true)
    url_pass=$(grep -c '^PASS' "$TMP_DIR/urls.out" || true)
fi

total_pass=$((fm_pass + path_pass + rel_pass + url_pass))
total_fail=$((fm_fail + path_fail + rel_fail + url_fail))
total_skip=$((url_skip))

echo
echo "결과: PASS $total_pass, FAIL $total_fail, SKIP $total_skip"

if [ "$total_fail" -gt 0 ]; then
    exit 1
fi
exit 0
