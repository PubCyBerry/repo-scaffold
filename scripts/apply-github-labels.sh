#!/usr/bin/env bash
# .github/labels.yml 을 원격 저장소의 라벨에 반영한다.
#
# 기본은 dry-run 이다. 인자 없이 부르면 무엇이 바뀔지만 보여주고 아무것도 바꾸지 않는다.
# 원격을 실제로 바꾸는 것은 --apply 를 줬을 때뿐이다. 원격 변경은 되돌리기 어렵고
# 이 스크립트는 훅과 CI 와 사람이 같이 부르므로, 기본값이 안전한 쪽이어야 한다.
#
# 모드:
#   (없음)    dry-run. 만들 것, 고칠 것, 파일에 없는 것을 보고만 한다. 종료 코드 0
#   --apply   실제로 만들고 고친다. 지우지는 않는다
#   --check   드리프트만 본다. 어긋난 것이 있으면 종료 코드 1. just labels-check 가 쓴다
#
# 지우지 않는 이유: 파일에 없는 라벨이 곧 불필요한 라벨은 아니다. GitHub 기본 라벨과
# 사람이 손으로 만든 라벨이 섞여 있고, 라벨을 지우면 그 라벨이 붙어 있던 이슈의
# 분류 정보가 같이 사라진다. 파일에 없는 것은 보고만 하고 판단은 사람이 한다.
#
# 라벨이 없으면 세 가지가 조용히 깨진다. Issue Form 은 없는 라벨을 오류 없이 버리고,
# actions/stale 은 아무것도 매칭하지 못한 채 매일 초록으로 끝나며, pr-policy 는
# policy/skip-issue 를 붙일 수 없어 사소한 PR 을 전부 막는다. 근거는
# docs/standards/triage-labels.md 에 있다.
#
# gh 가 없으면 로컬에서는 SKIP, CI(환경변수 CI=true)에서는 FAIL 이다.
#
# 이 스크립트는 모든 라벨을 돌려 결과를 모으므로 set -e 를 쓰지 않는다.
# 예외 근거는 docs/standards/shell.md 에 있다.
#
# 사용법:
#   bash scripts/apply-github-labels.sh
#   bash scripts/apply-github-labels.sh --apply
#   bash scripts/apply-github-labels.sh --check
#
# 종료 코드: FAIL 이 하나라도 있으면 1, 알 수 없는 옵션이면 2, 아니면 0

set -uo pipefail

# cd 뒤에는 상대 경로인 BASH_SOURCE 가 안 풀린다. --help 가 자기 파일을 읽으므로 먼저 절대 경로로 잡는다.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SELF="$SCRIPT_DIR/$(basename "${BASH_SOURCE[0]}")"

LABEL_FILE=".github/labels.yml"
MODE="dry-run"

while [ $# -gt 0 ]; do
    case "$1" in
        --apply)
            MODE="apply"
            shift
            ;;
        --check)
            MODE="check"
            shift
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

# 스크립트 위치가 아니라 git 이 루트를 정한다. scripts/ 를 옮겨도 따라온다.
REPO_ROOT="$(git rev-parse --show-toplevel 2> /dev/null)" || {
    echo "FAIL: git 저장소가 아니다" >&2
    exit 1
}
cd "$REPO_ROOT" || exit 1

pass_count=0
fail_count=0
skip_count=0
plan_count=0
note_count=0

report() {
    # $1: 판정, $2: 대상, $3: 사유
    case "$1" in
        PASS) pass_count=$((pass_count + 1)) ;;
        FAIL) fail_count=$((fail_count + 1)) ;;
        SKIP) skip_count=$((skip_count + 1)) ;;
        PLAN | DONE) plan_count=$((plan_count + 1)) ;;
        NOTE) note_count=$((note_count + 1)) ;;
    esac
    printf '%-4s %-22s %s\n' "$1" "$2" "${3:-}"
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

# 라벨 이름은 슬래시와 공백을 갖는다. 경로에 그대로 넣으면 API 경로가 깨진다.
urlencode() {
    local raw="$1" out="" i char
    for ((i = 0; i < ${#raw}; i++)); do
        char="${raw:i:1}"
        case "$char" in
            [A-Za-z0-9._~-]) out="$out$char" ;;
            *) out="$out$(printf '%%%02X' "'$char")" ;;
        esac
    done
    printf '%s\n' "$out"
}

if [ ! -f "$LABEL_FILE" ]; then
    echo "SKIP $LABEL_FILE 이 없다. 반영할 라벨 정의가 없다"
    exit 0
fi

if ! require_tool gh; then
    echo
    echo "결과: PASS $pass_count, FAIL $fail_count, SKIP $skip_count"
    [ "$fail_count" -gt 0 ] && exit 1
    exit 0
fi

REPO="${GITHUB_REPOSITORY:-}"
if [ -z "$REPO" ]; then
    REPO="$(gh repo view --json nameWithOwner --jq '.nameWithOwner' 2> /dev/null)"
fi
case "$REPO" in
    */*) ;;
    *)
        echo "FAIL: OWNER/REPO 를 알아내지 못했다. GITHUB_REPOSITORY 로 지정한다" >&2
        exit 1
        ;;
esac

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

# --- 파일 읽기 ----------------------------------------------------------------
#
# yq 를 쓰지 않는다. tools.txt 에 없는 도구를 이 스크립트 하나 때문에 요구하지 않는다.
# 대신 .github/labels.yml 의 배치를 고정하고 그 배치만 읽는다. 항목마다
# name, color, description 이 이 순서로 하나씩 있어야 한다.
awk '
    /^[ \t]*#/ { next }
    /^[ \t]*-[ \t]+name:[ \t]*/ {
        if (name != "") print name "\t" color "\t" desc
        name = $0
        sub(/^[ \t]*-[ \t]+name:[ \t]*/, "", name)
        color = ""
        desc = ""
        next
    }
    /^[ \t]+color:[ \t]*/ {
        color = $0
        sub(/^[ \t]+color:[ \t]*/, "", color)
        next
    }
    /^[ \t]+description:[ \t]*/ {
        desc = $0
        sub(/^[ \t]+description:[ \t]*/, "", desc)
        next
    }
    END { if (name != "") print name "\t" color "\t" desc }
' "$LABEL_FILE" | sed 's/\r$//; s/"//g' > "$TMP_DIR/wanted"

WANTED_COUNT="$(wc -l < "$TMP_DIR/wanted" | tr -d ' ')"
if [ "$WANTED_COUNT" -eq 0 ]; then
    echo "SKIP $LABEL_FILE 에 라벨 항목이 없다"
    exit 0
fi

echo "저장소: $REPO"
echo "정의:   $LABEL_FILE 의 라벨 ${WANTED_COUNT}개"
echo "모드:   $MODE"
case "$MODE" in
    dry-run) echo "        아무것도 바꾸지 않는다. 실제로 반영하려면 --apply 를 준다" ;;
    check) echo "        드리프트만 본다. 어긋나면 종료 코드 1 이다" ;;
esac

# --- 원격 읽기 ----------------------------------------------------------------
if ! gh api "repos/$REPO/labels" --paginate \
    --jq '.[] | [.name, .color, (.description // "")] | @tsv' \
    > "$TMP_DIR/remote" 2> "$TMP_DIR/remote.err"; then
    cat "$TMP_DIR/remote.err" >&2
    report FAIL "$REPO" "라벨 목록을 읽지 못했다. gh auth status 를 확인한다"
    echo
    echo "결과: PASS $pass_count, FAIL $fail_count, SKIP $skip_count"
    exit 1
fi

remote_field() {
    # $1: 라벨 이름, $2: 필드 번호(2 색, 3 설명). 없으면 빈 줄
    awk -F'\t' -v want="$1" -v col="$2" '$1 == want { print $col; found = 1 }
        END { if (!found) print "" }' "$TMP_DIR/remote"
}

# --- 대조 --------------------------------------------------------------------
echo
echo "[1/2] 정의된 라벨"

apply_label() {
    # $1: 방식(POST 또는 PATCH), $2: 경로, $3: 이름, $4: 색, $5: 설명
    gh api --method "$1" -H "Accept: application/vnd.github+json" "$2" \
        -f "name=$3" -f "color=$4" -f "description=$5" > /dev/null 2>&1
}

while IFS=$'\t' read -r name color desc; do
    [ -n "$name" ] || continue
    case "$color" in
        [0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]) ;;
        *)
            report FAIL "$name" "색이 6자리 16진수가 아니다: '$color'"
            continue
            ;;
    esac

    cur_color="$(remote_field "$name" 2)"
    cur_desc="$(remote_field "$name" 3)"

    if [ -z "$cur_color" ]; then
        case "$MODE" in
            apply)
                if apply_label POST "repos/$REPO/labels" "$name" "$color" "$desc"; then
                    report DONE "$name" "만들었다"
                else
                    report FAIL "$name" "만들지 못했다"
                fi
                ;;
            check) report FAIL "$name" "원격에 없다. --apply 로 만든다" ;;
            *) report PLAN "$name" "만든다 (#$color)" ;;
        esac
        continue
    fi

    if [ "$cur_color" = "$color" ] && [ "$cur_desc" = "$desc" ]; then
        report PASS "$name" "일치"
        continue
    fi

    diff=""
    [ "$cur_color" = "$color" ] || diff="색 #$cur_color -> #$color"
    [ "$cur_desc" = "$desc" ] || diff="${diff:+$diff, }설명이 다르다"

    case "$MODE" in
        apply)
            if apply_label PATCH "repos/$REPO/labels/$(urlencode "$name")" \
                "$name" "$color" "$desc"; then
                report DONE "$name" "고쳤다: $diff"
            else
                report FAIL "$name" "고치지 못했다"
            fi
            ;;
        check) report FAIL "$name" "파일과 다르다: $diff" ;;
        *) report PLAN "$name" "고친다: $diff" ;;
    esac
done < "$TMP_DIR/wanted"

# --- 파일에 없는 라벨 ---------------------------------------------------------
echo
echo "[2/2] 파일에 없는 원격 라벨"
extra=0
while IFS=$'\t' read -r name _color _desc; do
    [ -n "$name" ] || continue
    if ! cut -f1 "$TMP_DIR/wanted" | grep -Fxq "$name"; then
        extra=$((extra + 1))
        report NOTE "$name" "파일에 없다. 지우지 않는다. 필요 없으면 사람이 지운다"
    fi
done < "$TMP_DIR/remote"
[ "$extra" -eq 0 ] && report PASS "extra" "파일에 없는 라벨이 없다"

echo
echo "결과: PASS $pass_count, FAIL $fail_count, SKIP $skip_count, 변경 $plan_count, NOTE $note_count"

if [ "$fail_count" -gt 0 ]; then
    echo
    echo "규약: docs/standards/triage-labels.md" >&2
    exit 1
fi
exit 0
