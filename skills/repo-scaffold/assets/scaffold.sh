#!/usr/bin/env bash
# 에이전트 특화 저장소 스캐폴딩.
#
# 이 스크립트가 하는 일은 파일 복사와 플레이스홀더 치환뿐이다.
# 무엇을 왜 두는지는 references/layout.md 에 있다.
#
# 원칙:
#   - 기존 파일을 덮어쓰지 않는다. 이미 있으면 SKIP 하고 보고만 한다
#   - 여러 번 돌려도 결과가 같다 (idempotent)
#   - --dry-run 이 기본 확인 수단이다. 먼저 돌려서 계획을 본다
#
# 사용법:
#   bash scaffold.sh --target DIR [옵션]
#
#   --target DIR      대상 저장소 루트. 필수
#   --name NAME       저장소 이름. 기본값은 --target 의 basename
#   --desc TEXT       한 줄 설명. README 와 AGENTS.md 에 들어간다
#   --product DIR     제품 종속 문서 디렉터리명. 예: --product nexus 면 docs/nexus/ 생성
#   --lang en|ko      문서 언어. 검증 스크립트의 summary 문체 검사에만 영향. 기본 en.
#                     docs/ 를 영어로 쓰는 것이 규약이므로 ko 는 규약을 벗어날 때만 쓴다
#   --with LANG       감지 결과와 무관하게 그 언어의 도구 설정을 배치한다. 여러 번 줄 수 있다
#   --without LANG    감지 결과와 무관하게 배치하지 않는다. 여러 번 줄 수 있다
#   --init            대상이 git 저장소가 아니면 git init 한다
#   --dry-run         쓰지 않고 계획만 출력한다
#
# 판정: ADD 새로 만듦 / PLAN 만들 예정 / SKIP 이미 있음 / OMIT 이 저장소에 불필요 /
#       NOTE 이미 있어서 사람이 손으로 합쳐야 함 / FAIL 실패
#
# 종료 코드: 실패가 있으면 1, 아니면 0

set -uo pipefail

ASSET_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 도구 설정 파일을 언어별로 거르는 대상. 스크립트와 Justfile 과 훅 설정은 여기 없다.
KNOWN_LANGS="python"

TARGET=""
NAME=""
DESC=""
PRODUCT=""
LANG_CODE="en"
WITH_LANGS=""
WITHOUT_LANGS=""
DO_INIT=0
DRY_RUN=0

require_option_value() {
    if [ "$#" -lt 2 ]; then
        echo "FAIL: $1 값이 없다" >&2
        return 1
    fi
    case "$2" in
        --* | -h)
            echo "FAIL: $1 값이 없다" >&2
            return 1
            ;;
    esac
}

require_known_lang() {
    case " $KNOWN_LANGS " in
        *" $1 "*) return 0 ;;
    esac
    echo "FAIL: 그런 언어가 없다: $1" >&2
    echo "      쓸 수 있는 언어: $KNOWN_LANGS" >&2
    return 1
}

while [ $# -gt 0 ]; do
    case "$1" in
        --target | --name | --desc | --product | --lang | --with | --without)
            require_option_value "$@" || exit 2
            ;;
    esac
    case "$1" in
        --target)
            TARGET="$2"
            shift 2
            ;;
        --name)
            NAME="$2"
            shift 2
            ;;
        --desc)
            DESC="$2"
            shift 2
            ;;
        --product)
            PRODUCT="$2"
            shift 2
            ;;
        --lang)
            LANG_CODE="$2"
            shift 2
            ;;
        --with)
            require_known_lang "$2" || exit 2
            WITH_LANGS="$WITH_LANGS $2"
            shift 2
            ;;
        --without)
            require_known_lang "$2" || exit 2
            WITHOUT_LANGS="$WITHOUT_LANGS $2"
            shift 2
            ;;
        --init)
            DO_INIT=1
            shift
            ;;
        --dry-run)
            DRY_RUN=1
            shift
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

[ -n "$TARGET" ] || {
    echo "FAIL: --target 이 없다" >&2
    exit 2
}
[ ! -L "$TARGET" ] || {
    echo "FAIL: 대상 경로가 심링크다: $TARGET" >&2
    exit 2
}
[ -d "$TARGET" ] || {
    echo "FAIL: 대상 디렉터리가 없다: $TARGET" >&2
    exit 2
}

case "$LANG_CODE" in
    ko | en) ;;
    *)
        echo "FAIL: --lang 은 ko 또는 en 이다: $LANG_CODE" >&2
        exit 2
        ;;
esac

case "$PRODUCT" in
    */* | .*)
        echo "FAIL: --product 는 디렉터리명 하나다: $PRODUCT" >&2
        exit 2
        ;;
esac

TARGET="$(cd "$TARGET" && pwd)"
[ -n "$NAME" ] || NAME="$(basename "$TARGET")"
[ -n "$DESC" ] || DESC="$NAME 저장소"

for value in "$NAME" "$DESC" "$PRODUCT"; do
    case "$value" in
        *$'\r'* | *$'\n'*)
            echo "FAIL: 이름, 설명, 제품 디렉터리는 한 줄이어야 한다" >&2
            exit 2
            ;;
    esac
done
case "$NAME" in
    *"'"*)
        echo "FAIL: 저장소 이름에 작은따옴표를 쓸 수 없다" >&2
        exit 2
        ;;
esac

# summary 는 개조식이다. 검사 규칙이 언어마다 달라 문서 언어를 그대로 넘긴다.
SUMMARY_STYLE="$LANG_CODE"

# --- git 저장소 확인 ----------------------------------------------------------

if ! git -C "$TARGET" rev-parse --git-dir > /dev/null 2>&1; then
    if [ "$DO_INIT" -eq 1 ]; then
        if [ "$DRY_RUN" -eq 1 ]; then
            echo "PLAN git init $TARGET"
        else
            git -C "$TARGET" init -q
            echo "INIT git 저장소 생성: $TARGET"
        fi
    else
        echo "FAIL: git 저장소가 아니다: $TARGET" >&2
        echo "      git init 을 먼저 하거나 --init 을 준다" >&2
        exit 1
    fi
fi

# --- 보고 --------------------------------------------------------------------

add_count=0
skip_count=0
omit_count=0
note_count=0
fail_count=0
GENERATED_PATHS=()
GENERATED_INDEX=0
GENERATED_AGENTS=0

report() {
    # $1: 판정, $2: 대상, $3: 사유
    # 파일이 없는 이유는 셋이다. SKIP 이미 있음 / OMIT 이 저장소에 불필요 /
    # NOTE 이미 있어서 사람이 손으로 합쳐야 함. 셋을 뭉치면 무엇을 해야 하는지 알 수 없다.
    case "$1" in
        ADD | PLAN) add_count=$((add_count + 1)) ;;
        SKIP) skip_count=$((skip_count + 1)) ;;
        OMIT) omit_count=$((omit_count + 1)) ;;
        NOTE) note_count=$((note_count + 1)) ;;
        FAIL) fail_count=$((fail_count + 1)) ;;
    esac
    printf '%-4s %-44s %s\n' "$1" "$2" "${3:-}"
}

# --- 치환 --------------------------------------------------------------------

symlink_component() {
    local path="$1"
    while :; do
        if [ -L "$path" ]; then
            SYMLINK_COMPONENT="$path"
            return 0
        fi
        [ "$path" = "$TARGET" ] && return 1
        path="$(dirname "$path")"
    done
}

# 목적지 확장자로 권한을 정한다. 셸 스크립트만 실행 권한을 준다.
# set_mode TMP DEST_REL
set_mode() {
    case "$2" in
        *.sh) chmod 755 "$1" ;;
        *) chmod 644 "$1" ;;
    esac
}

# render SRC DEST [KEY=VALUE ...]
# 전역 플레이스홀더에 호출별 추가 쌍을 얹어 치환한다.
render() {
    local src="$ASSET_DIR/$1" dest_rel="$2"
    shift 2
    local dest="$TARGET/$dest_rel"
    local parent tmp=""

    if [ ! -f "$src" ]; then
        report FAIL "$dest_rel" "템플릿 없음: $src"
        return
    fi

    if symlink_component "$dest"; then
        report FAIL "$dest_rel" "심링크 경로 거부: $SYMLINK_COMPONENT"
        return
    fi

    if [ -e "$dest" ]; then
        report SKIP "$dest_rel" "이미 있음"
        return
    fi

    if [ "$DRY_RUN" -eq 1 ]; then
        report PLAN "$dest_rel" "새로 만듦"
        return
    fi

    # sed replacement 메타문자는 escape 하고 줄바꿈은 옵션 검증에서 거른다.
    local args=("REPO_NAME=$NAME" "REPO_DESC=$DESC" "PRODUCT_DIR=$PRODUCT"
        "SUMMARY_STYLE=$SUMMARY_STYLE" "DOC_LANG=$LANG_CODE" "$@")
    local script="" pair key value escaped
    for pair in "${args[@]}"; do
        key="${pair%%=*}"
        value="${pair#*=}"
        case "$value" in
            *$'\r'* | *$'\n'*)
                report FAIL "$dest_rel" "치환값은 한 줄이어야 한다: $key"
                return
                ;;
        esac
        escaped="$(printf '%s' "$value" | sed 's/[\\&|]/\\&/g')"
        script="${script}s|{{$key}}|$escaped|g;"
    done

    parent="$(dirname "$dest")"
    if ! mkdir -p "$parent"; then
        report FAIL "$dest_rel" "상위 디렉터리 생성 실패"
        return
    fi
    if symlink_component "$dest"; then
        report FAIL "$dest_rel" "심링크 경로 거부: $SYMLINK_COMPONENT"
        return
    fi

    tmp="$(mktemp "$parent/.repo-scaffold.XXXXXX")" || {
        report FAIL "$dest_rel" "임시 파일 생성 실패"
        return
    }

    if ! sed "$script" "$src" > "$tmp" || ! set_mode "$tmp" "$dest_rel"; then
        rm -f "$tmp"
        report FAIL "$dest_rel" "쓰기 실패"
        return
    fi

    if ln "$tmp" "$dest" 2> /dev/null; then
        rm -f "$tmp"
        GENERATED_PATHS[${#GENERATED_PATHS[@]}]="$dest_rel"
        case "$dest_rel" in
            scripts/gen-doc-index.sh) GENERATED_INDEX=1 ;;
            AGENTS.md) GENERATED_AGENTS=1 ;;
        esac
        report ADD "$dest_rel"
    elif [ -e "$dest" ] || [ -L "$dest" ]; then
        rm -f "$tmp"
        report SKIP "$dest_rel" "생성 중 다른 파일이 생김"
    else
        rm -f "$tmp"
        report FAIL "$dest_rel" "파일 게시 실패"
    fi
}

# 이미 있으면 사람이 손으로 합쳐야 하는 설정 파일. SKIP 대신 원본 경로를 짚어준다.
# TOML 과 JSON 을 자동으로 병합하지 않는다. 주석과 순서가 사라지고 의도를 알 수 없다.
# render_mergeable SRC DEST [KEY=VALUE ...]
render_mergeable() {
    local dest_rel="$2"

    # 심링크 판정은 render 가 한다. 여기서 -e 로 먼저 걸러버리면 심링크가 NOTE 로 새어나간다.
    if ! symlink_component "$TARGET/$dest_rel" && [ -e "$TARGET/$dest_rel" ]; then
        report NOTE "$dest_rel" "이미 있다. 합칠 원본: $ASSET_DIR/$1"
        return
    fi
    render "$@"
}

# 언어별 도구 설정. 감지 결과가 yes 일 때만 배치한다.
# 스크립트와 Justfile 과 훅 설정에는 쓰지 않는다. 그것들은 언어와 무관하게 항상 깐다.
# render_lang LANG SRC DEST [KEY=VALUE ...]
# shellcheck disable=SC2329  # 확장 지점. 호출자는 언어별 설정 템플릿이 들어올 때 생긴다
render_lang() {
    local lang="$1" dest_rel="$3"
    shift
    case "$(lang_verdict "$lang")" in
        yes) render_mergeable "$@" ;;
        unknown)
            report OMIT "$dest_rel" "$lang 사용 여부를 판단할 근거가 없다. --with $lang 으로 강제한다"
            ;;
        *) report OMIT "$dest_rel" "$lang 을 쓰는 흔적이 없다" ;;
    esac
}

# 문서 상대 링크를 쓰므로 같은 템플릿이 깊이가 다른 곳에 깔리면 상위 경로가 달라진다.
# docs/guides/index.md 는 ../index.md 이고 docs/nexus/guides/index.md 는 ../../index.md 다.
# docs_dir 의 경로 조각 수가 곧 올라가야 할 단계 수다.
# docs_index_rel DOCS_DIR
docs_index_rel() {
    local rest="$1" up=""
    while [ -n "$rest" ]; do
        up="../$up"
        case "$rest" in
            */*) rest="${rest#*/}" ;;
            *) rest="" ;;
        esac
    done
    printf '%sindex.md\n' "$up"
}

# 카테고리 인덱스는 템플릿 하나를 메타만 갈아끼워 여러 번 쓴다.
# render_category CAT DOCS_DIR ID_PREFIX TITLE_PREFIX
render_category() {
    local cat="$1" docs_dir="$2" id_prefix="$3" title_prefix="$4"
    local title summary read_when purpose

    case "$cat" in
        standards)
            title="Standards"
            summary="Rules that must be followed"
            read_when="Before writing code or documents"
            purpose="Collect the rules whose violation is a review finding."
            ;;
        guides)
            title="Guides"
            summary="Procedures that produce a result when followed"
            read_when="When following a procedure"
            purpose="Collect procedures that produce the same result every time they are run in order."
            ;;
        references)
            title="References"
            summary="Facts to look up and external material"
            read_when="When looking up a value or a location"
            purpose="Collect facts that are looked up rather than followed: addresses, account schemes, specifications."
            ;;
        generated)
            title="Generated"
            summary="Documents produced from code or a schema"
            read_when="When checking the current implementation state"
            purpose="Produced from code or a schema. Regenerated rather than edited by hand."
            ;;
        *)
            report FAIL "$docs_dir/$cat/index.md" "알 수 없는 카테고리: $cat"
            return
            ;;
    esac

    render docs/category-index.md "$docs_dir/$cat/index.md" \
        "DOCS_DIR=$docs_dir" \
        "DOCS_INDEX=$(docs_index_rel "$docs_dir")" \
        "CAT_SLUG=$cat" \
        "IDX_ID=${id_prefix}${cat}" \
        "IDX_TITLE=${title_prefix}${title}" \
        "CAT_SUMMARY=$summary" \
        "CAT_READ_WHEN=$read_when" \
        "CAT_PURPOSE=$purpose"
}

# --- 언어 감지 ----------------------------------------------------------------
#
# 감지가 정하는 것은 도구 설정 파일뿐이다. Justfile, 훅 설정, tests/*, scripts/* 는
# 언어와 무관하게 항상 깐다. 스크립트를 언어로 거르면 "파이썬 없음" 이 깨끗한 SKIP 이
# 아니라 매 커밋 "No such file" 훅 에러가 된다.
#
# package.json 도 거르지 않는다. Node 는 도구 의존성이지 소스 언어가 아니다.

# vendor 경로를 직접 뺀다. 대상에 .gitignore 가 아직 없으면 --exclude-standard 는 무력하고,
# 그러면 .venv 하나 때문에 모든 저장소가 다국어로 판정된다.
#
# 짧은 형식 :!PATH 를 쓰지 않는다. PATH 첫 글자를 pathspec magic 으로 읽어서
# ':!__pycache__/**' 가 "Unimplemented pathspec magic '_'" 로 죽는다.
# 맨 앞의 '.' 는 positive pathspec 이다. 제외만 주면 매칭 규칙이 git 버전마다 갈린다.
PATHSPEC=(
    '.'
    ':(exclude).venv/**' ':(exclude)node_modules/**' ':(exclude)__pycache__/**'
    ':(exclude)vendor/**' ':(exclude)dist/**' ':(exclude)build/**'
    ':(exclude)target/**' ':(exclude)site-packages/**'
)

# --cached 만 보면 git init 만 하고 아무것도 add 하지 않은 저장소가 전부 빈 것으로 보인다.
# 그게 가장 흔한 실제 상황이므로 --others 까지 본다.
repo_files() {
    git -C "$TARGET" ls-files --cached --others --exclude-standard \
        -- "${PATHSPEC[@]}" 2> /dev/null
}

# 저장소가 사실상 비었는가. 어느 저장소에나 있는 파일만 남으면 빈 것으로 본다.
repo_is_empty() {
    local f
    while IFS= read -r f; do
        case "$f" in
            README* | LICENSE* | COPYING* | .gitignore | .gitattributes | .github/*) continue ;;
        esac
        return 1
    done < <(repo_files)
    return 0
}

lang_evidence() {
    case "$1" in
        python)
            repo_files | grep -qE \
                '(^|/)(pyproject\.toml|setup\.py|setup\.cfg|Pipfile|requirements[^/]*\.txt)$|\.pyi?$'
            ;;
        *) return 1 ;;
    esac
}

LANG_YES=""
LANG_NO=""
LANG_UNKNOWN=""

lang_verdict() {
    case " $LANG_YES " in *" $1 "*)
        echo yes
        return
        ;;
    esac
    case " $LANG_UNKNOWN " in *" $1 "*)
        echo unknown
        return
        ;;
    esac
    echo no
}

# unknown 을 yes 로 올리지 않는다. 빈 저장소에 파이썬 설정을 깔면 파이썬을 안 쓰는
# 사람이 그것을 지워야 한다. 다시 돌려도 덮어쓰지 않으므로 나중에 다시 돌리면 된다.
detect_languages() {
    local lang empty=0
    repo_is_empty && empty=1
    for lang in $KNOWN_LANGS; do
        case " $WITHOUT_LANGS " in
            *" $lang "*)
                LANG_NO="$LANG_NO $lang"
                continue
                ;;
        esac
        case " $WITH_LANGS " in
            *" $lang "*)
                LANG_YES="$LANG_YES $lang"
                continue
                ;;
        esac
        if lang_evidence "$lang"; then
            LANG_YES="$LANG_YES $lang"
        elif [ "$empty" -eq 1 ]; then
            LANG_UNKNOWN="$LANG_UNKNOWN $lang"
        else
            LANG_NO="$LANG_NO $lang"
        fi
    done
}

detect_languages

# --- 배치 --------------------------------------------------------------------

echo "대상:   $TARGET"
echo "이름:   $NAME"
echo "언어:   $LANG_CODE${PRODUCT:+ / 제품 디렉터리 docs/$PRODUCT}"
verdict_line=""
for lang in $KNOWN_LANGS; do
    verdict_line="$verdict_line $lang=$(lang_verdict "$lang")"
done
echo "감지:  $verdict_line"
[ "$DRY_RUN" -eq 1 ] && echo "모드:   dry-run. 아무것도 쓰지 않는다"
echo

echo "[1/3] 검증 스크립트와 훅"
render scripts/gen-doc-index.sh scripts/gen-doc-index.sh
render scripts/run-all.sh scripts/run-all.sh
render scripts/bootstrap.sh scripts/bootstrap.sh
render scripts/doctor.sh scripts/doctor.sh
render scripts/fmt.sh scripts/fmt.sh
render scripts/fix.sh scripts/fix.sh
render tests/check-docs.sh tests/check-docs.sh
render tests/check-markdown.sh tests/check-markdown.sh
render tests/check-prose.sh tests/check-prose.sh
render tests/check-shell.sh tests/check-shell.sh
render tests/check-yaml.sh tests/check-yaml.sh
render tests/check-workflows.sh tests/check-workflows.sh
render tests/check-hooks.sh tests/check-hooks.sh
render tests/check-env.sh tests/check-env.sh
render tests/check-secrets.sh tests/check-secrets.sh
render_mergeable root/pre-commit-config.yaml .pre-commit-config.yaml

echo
echo "[2/3] 저장소 루트 파일"
render_mergeable root/Justfile Justfile
render_mergeable root/tools.txt tools.txt
render_mergeable root/gitattributes .gitattributes
render_mergeable root/editorconfig .editorconfig
render_mergeable root/gitignore .gitignore
render_mergeable root/rumdl.toml .rumdl.toml
render_mergeable root/vale.ini .vale.ini
render_mergeable root/shellcheckrc .shellcheckrc
render_mergeable root/yamllint.yaml .yamllint.yaml
render root/env.example .env.example
render root/AGENTS.md AGENTS.md
render root/CLAUDE.md CLAUDE.md
render root/README.md README.md
render root/SECURITY.md SECURITY.md
render_mergeable claude/settings.json .claude/settings.json

echo
echo "      산문 규칙 (Vale)"
# Project 는 문자 규칙이라 언어와 무관하고, English 와 Korean 은 문서 언어별로 갈린다.
# 어느 파일에 어느 스타일을 거는지는 .vale.ini 가 정한다.
render styles/Project/Punctuation.yml styles/Project/Punctuation.yml
render styles/Project/ByteCounts.yml styles/Project/ByteCounts.yml
render styles/English/Tone.yml styles/English/Tone.yml
render styles/English/Hedges.yml styles/English/Hedges.yml
render styles/English/Dates.yml styles/English/Dates.yml
render styles/Korean/Terminology.yml styles/Korean/Terminology.yml
render styles/Korean/ForeignWords.yml styles/Korean/ForeignWords.yml
render styles/Korean/ProductNames.yml styles/Korean/ProductNames.yml
render styles/Korean/Punctuation.yml styles/Korean/Punctuation.yml
render styles/Korean/SpacingPatterns.yml styles/Korean/SpacingPatterns.yml
render styles/Korean/RedundantExpressions.yml styles/Korean/RedundantExpressions.yml
render styles/Korean/SentenceEndings.yml styles/Korean/SentenceEndings.yml
render styles/Korean/Tone.yml styles/Korean/Tone.yml

echo
echo "[3/3] 문서 체계"
render docs/index.md docs/index.md
render docs/standards-index.md docs/standards/index.md
render docs/documentation.md docs/standards/documentation.md
render docs/writing-style.md docs/standards/writing-style.md
render docs/code-quality.md docs/standards/code-quality.md
render docs/testing.md docs/standards/testing.md
render docs/code-review.md docs/standards/code-review.md
render docs/commit-convention.md docs/standards/commit-convention.md
render docs/shell.md docs/standards/shell.md
render docs/github-actions.md docs/standards/github-actions.md
render_category guides docs "index-" ""
render_category references docs "index-" ""
render_category generated docs "index-" ""

if [ -n "$PRODUCT" ]; then
    render docs/product-index.md "docs/$PRODUCT/index.md" \
        "DOCS_DIR=docs/$PRODUCT" "IDX_ID=index-$PRODUCT" "IDX_TITLE=$PRODUCT 문서"
    for cat in standards guides references; do
        render_category "$cat" "docs/$PRODUCT" "index-$PRODUCT-" "$PRODUCT "
    done
fi

# --- 마무리 ------------------------------------------------------------------

echo
if [ "$DRY_RUN" -eq 1 ]; then
    echo "결과: PLAN $add_count, SKIP $skip_count, OMIT $omit_count, NOTE $note_count, FAIL $fail_count"
    echo "실제로 적용하려면 --dry-run 을 뺀다"
    [ "$fail_count" -gt 0 ] && exit 1
    exit 0
fi

echo "결과: ADD $add_count, SKIP $skip_count, OMIT $omit_count, NOTE $note_count, FAIL $fail_count"

if [ "$GENERATED_INDEX" -eq 1 ] && [ "$GENERATED_AGENTS" -eq 1 ]; then
    echo
    echo "문서 인덱스 생성"
    # git ls-files 는 인덱스를 읽는다. 새 파일이 아직 추적 전이면 인덱스가 비므로 먼저 등록한다.
    if git -C "$TARGET" add -N -- "${GENERATED_PATHS[@]}" > /dev/null 2>&1; then
        (cd "$TARGET" && bash scripts/gen-doc-index.sh) \
            || report FAIL "AGENTS.md" "인덱스 생성 실패"
    else
        report FAIL "AGENTS.md" "생성 경로를 git index 에 등록하지 못함"
    fi
fi

cat << EOF

다음 절차:

  cd $TARGET
  uv tool install rust-just    # just 하나만 손으로 깐다
  just bootstrap               # 나머지 도구, 의존성, git 훅. 클론마다 한 번
  just doctor                  # 환경 진단
  just verify                  # 검사 전체

SKIP 된 파일은 이미 있어서 건드리지 않았다. 내용을 합칠지는 사람이 판단한다.
NOTE 는 이미 있는 설정 파일이다. 원본을 열어 필요한 부분만 손으로 합친다.
EOF

if [ -n "$LANG_UNKNOWN" ]; then
    cat << EOF

저장소가 비어 있어 다음 언어의 사용 여부를 판단하지 못했다:$LANG_UNKNOWN
코드를 넣은 뒤 다시 돌리거나, 지금 배치하려면 --with 로 지정한다. 다시 돌려도 덮어쓰지 않는다.
EOF
fi

[ "$fail_count" -gt 0 ] && exit 1
exit 0
