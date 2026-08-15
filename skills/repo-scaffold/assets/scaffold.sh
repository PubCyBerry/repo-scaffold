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
#   --lang ko|en      문서 언어. 검증 스크립트의 summary 문체 검사에만 영향. 기본 ko
#   --init            대상이 git 저장소가 아니면 git init 한다
#   --dry-run         쓰지 않고 계획만 출력한다
#
# 종료 코드: 실패가 있으면 1, 아니면 0

set -uo pipefail

ASSET_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

TARGET=""
NAME=""
DESC=""
PRODUCT=""
LANG_CODE="ko"
DO_INIT=0
DRY_RUN=0

require_option_value() {
    if [ "$#" -lt 2 ]; then
        echo "FAIL: $1 값이 없다" >&2
        return 1
    fi
    case "$2" in
        --*|-h) echo "FAIL: $1 값이 없다" >&2; return 1 ;;
    esac
}

while [ $# -gt 0 ]; do
    case "$1" in
        --target|--name|--desc|--product|--lang)
            require_option_value "$@" || exit 2 ;;
    esac
    case "$1" in
        --target)  TARGET="$2"; shift 2 ;;
        --name)    NAME="$2"; shift 2 ;;
        --desc)    DESC="$2"; shift 2 ;;
        --product) PRODUCT="$2"; shift 2 ;;
        --lang)    LANG_CODE="$2"; shift 2 ;;
        --init)    DO_INIT=1; shift ;;
        --dry-run) DRY_RUN=1; shift ;;
        -h|--help) sed -n '2,32p' "${BASH_SOURCE[0]}"; exit 0 ;;
        *)         echo "알 수 없는 옵션: $1" >&2; exit 2 ;;
    esac
done

[ -n "$TARGET" ] || { echo "FAIL: --target 이 없다" >&2; exit 2; }
[ ! -L "$TARGET" ] || { echo "FAIL: 대상 경로가 심링크다: $TARGET" >&2; exit 2; }
[ -d "$TARGET" ] || { echo "FAIL: 대상 디렉터리가 없다: $TARGET" >&2; exit 2; }

case "$LANG_CODE" in
    ko|en) ;;
    *) echo "FAIL: --lang 은 ko 또는 en 이다: $LANG_CODE" >&2; exit 2 ;;
esac

case "$PRODUCT" in
    */*|.*) echo "FAIL: --product 는 디렉터리명 하나다: $PRODUCT" >&2; exit 2 ;;
esac

TARGET="$(cd "$TARGET" && pwd)"
[ -n "$NAME" ] || NAME="$(basename "$TARGET")"
[ -n "$DESC" ] || DESC="$NAME 저장소"

for value in "$NAME" "$DESC" "$PRODUCT"; do
    case "$value" in
        *$'\r'*|*$'\n'*)
            echo "FAIL: 이름, 설명, 제품 디렉터리는 한 줄이어야 한다" >&2
            exit 2 ;;
    esac
done
case "$NAME" in
    *"'"*) echo "FAIL: 저장소 이름에 작은따옴표를 쓸 수 없다" >&2; exit 2 ;;
esac

# summary 문체 검사는 한국어 종결어미 기준이라 한국어 문서에만 건다.
SUMMARY_STYLE="none"
[ "$LANG_CODE" = "ko" ] && SUMMARY_STYLE="ko"

# --- git 저장소 확인 ----------------------------------------------------------

if ! git -C "$TARGET" rev-parse --git-dir >/dev/null 2>&1; then
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
fail_count=0
GENERATED_PATHS=()
GENERATED_INDEX=0
GENERATED_AGENTS=0

report() {
    # $1: 판정, $2: 대상, $3: 사유
    case "$1" in
        ADD|PLAN) add_count=$((add_count + 1)) ;;
        SKIP)     skip_count=$((skip_count + 1)) ;;
        FAIL)     fail_count=$((fail_count + 1)) ;;
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

# render SRC DEST [KEY=VALUE ...]
# 전역 플레이스홀더에 호출별 추가 쌍을 얹어 치환한다.
render() {
    local src="$ASSET_DIR/$1" dest_rel="$2"; shift 2
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
            *$'\r'*|*$'\n'*) report FAIL "$dest_rel" "치환값은 한 줄이어야 한다: $key"; return ;;
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

    if ! sed "$script" "$src" > "$tmp" \
        || ! { case "$dest_rel" in *.sh) chmod 755 "$tmp" ;; *) chmod 644 "$tmp" ;; esac; }; then
        rm -f "$tmp"
        report FAIL "$dest_rel" "쓰기 실패"
        return
    fi

    if ln "$tmp" "$dest" 2>/dev/null; then
        rm -f "$tmp"
        GENERATED_PATHS[${#GENERATED_PATHS[@]}]="$dest_rel"
        case "$dest_rel" in
            scripts/gen-doc-index.sh) GENERATED_INDEX=1 ;;
            AGENTS.md)                GENERATED_AGENTS=1 ;;
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

# 카테고리 인덱스는 템플릿 하나를 메타만 갈아끼워 여러 번 쓴다.
# render_category CAT DOCS_DIR ID_PREFIX TITLE_PREFIX
render_category() {
    local cat="$1" docs_dir="$2" id_prefix="$3" title_prefix="$4"
    local title summary read_when purpose

    case "$cat" in
        standards)
            title="표준"
            summary="지켜야 하는 작업 규칙 목록"
            read_when="코드나 문서를 쓰기 전"
            purpose="어겼을 때 리뷰 지적 대상이 되는 규칙을 모은다." ;;
        guides)
            title="가이드"
            summary="따라 하면 결과가 나오는 절차 목록"
            read_when="절차를 따라 실행할 때"
            purpose="순서대로 실행하면 같은 결과가 나오는 절차를 모은다." ;;
        references)
            title="레퍼런스"
            summary="조회용 사실과 외부 자료 목록"
            read_when="값이나 위치를 조회할 때"
            purpose="절차가 아니라 조회 대상인 사실을 모은다. 인프라 주소, 계정 체계, 외부 명세가 해당한다." ;;
        generated)
            title="생성 문서"
            summary="코드나 스키마에서 생성한 문서 목록"
            read_when="현재 구현 상태를 확인할 때"
            purpose="코드나 스키마에서 생성한다. 손으로 고치지 않고 다시 생성한다." ;;
        *)
            report FAIL "$docs_dir/$cat/index.md" "알 수 없는 카테고리: $cat"
            return ;;
    esac

    render docs/category-index.md "$docs_dir/$cat/index.md" \
        "DOCS_DIR=$docs_dir" \
        "CAT_SLUG=$cat" \
        "IDX_ID=${id_prefix}${cat}" \
        "IDX_TITLE=${title_prefix}${title}" \
        "CAT_SUMMARY=$summary" \
        "CAT_READ_WHEN=$read_when" \
        "CAT_PURPOSE=$purpose"
}

# --- 배치 --------------------------------------------------------------------

echo "대상:   $TARGET"
echo "이름:   $NAME"
echo "언어:   $LANG_CODE${PRODUCT:+ / 제품 디렉터리 docs/$PRODUCT}"
[ "$DRY_RUN" -eq 1 ] && echo "모드:   dry-run. 아무것도 쓰지 않는다"
echo

echo "[1/3] 검증 스크립트와 훅"
render scripts/gen-doc-index.sh scripts/gen-doc-index.sh
render tests/check-docs.sh      tests/check-docs.sh
render tests/check-env.sh       tests/check-env.sh
render tests/check-secrets.sh   tests/check-secrets.sh
render root/pre-commit-config.yaml .pre-commit-config.yaml

echo
echo "[2/3] 저장소 루트 파일"
render root/gitattributes   .gitattributes
render root/editorconfig    .editorconfig
render root/gitignore       .gitignore
render root/env.example     .env.example
render root/AGENTS.md       AGENTS.md
render root/CLAUDE.md       CLAUDE.md
render root/README.md       README.md
render root/SECURITY.md     SECURITY.md
render claude/settings.json .claude/settings.json

echo
echo "[3/3] 문서 체계"
render docs/index.md           docs/index.md
render docs/standards-index.md docs/standards/index.md
render docs/documentation.md   docs/standards/documentation.md
render_category guides     docs "index-" ""
render_category references docs "index-" ""
render_category generated  docs "index-" ""

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
    echo "결과: PLAN $add_count, SKIP $skip_count, FAIL $fail_count"
    echo "실제로 적용하려면 --dry-run 을 뺀다"
    [ "$fail_count" -gt 0 ] && exit 1
    exit 0
fi

echo "결과: ADD $add_count, SKIP $skip_count, FAIL $fail_count"

if [ "$GENERATED_INDEX" -eq 1 ] && [ "$GENERATED_AGENTS" -eq 1 ]; then
    echo
    echo "문서 인덱스 생성"
    # git ls-files 는 인덱스를 읽는다. 새 파일이 아직 추적 전이면 인덱스가 비므로 먼저 등록한다.
    if git -C "$TARGET" add -N -- "${GENERATED_PATHS[@]}" >/dev/null 2>&1; then
        (cd "$TARGET" && bash scripts/gen-doc-index.sh) \
            || report FAIL "AGENTS.md" "인덱스 생성 실패"
    else
        report FAIL "AGENTS.md" "생성 경로를 git index 에 등록하지 못함"
    fi
fi

cat <<EOF

다음 절차:

  cd $TARGET
  uv venv && uv pip install --python .venv pre-commit
  .venv/Scripts/pre-commit install      # 리눅스, macOS 는 .venv/bin/pre-commit

  bash tests/check-docs.sh --no-net     # 문서 규약 확인
  git add -A && git commit              # 훅이 인덱스를 갱신하고 한 번 실패시킨다. 그대로 다시 커밋한다

SKIP 된 파일은 이미 있어서 건드리지 않았다. 내용을 합칠지는 사람이 판단한다.
EOF

[ "$fail_count" -gt 0 ] && exit 1
exit 0
