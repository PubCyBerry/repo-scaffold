#!/usr/bin/env bash
# 저장소의 머지 설정을 규약에 맞춘다.
#
# 기본은 dry-run 이다. 인자 없이 부르면 현재 값과 의도한 값을 나란히 보여주고
# 아무것도 바꾸지 않는다. 원격을 실제로 바꾸는 것은 --apply 를 줬을 때뿐이다.
#
# 맞추는 값:
#   allow_squash_merge          true       squash 만 허용한다
#   allow_merge_commit          false      머지 커밋을 끈다
#   allow_rebase_merge          false      리베이스 머지를 끈다
#   allow_auto_merge            true       머지 큐와 자동 머지를 쓴다
#   delete_branch_on_merge      true       머지한 브랜치를 지운다
#   squash_merge_commit_title   PR_TITLE   기본 브랜치 커밋 제목이 PR 제목이 된다
#   squash_merge_commit_message PR_BODY    커밋 본문이 PR 본문이 된다
#
# squash_merge_commit_title 이 PR_TITLE 이라는 것이 pr-policy 가 PR 제목을 검사하는
# 이유다. 기본 브랜치에 남는 커밋 메시지가 PR 제목에서 합성되고, commit-msg 훅은
# 브랜치 커밋만 보므로 그 문자열을 영원히 보지 못한다.
#
# 브랜치 룰셋은 여기서 적용하지 않는다. 잘못 걸면 기본 브랜치가 잠기고, 푸는 데
# 같은 관리자 권한이 필요하다. .github/rulesets 의 예제를 읽고 사람이 손으로 건다.
# 절차는 docs/guides/github-governance-setup.md 에 있다.
#
# gh 가 없으면 로컬에서는 SKIP, CI(환경변수 CI=true)에서는 FAIL 이다.
#
# 이 스크립트는 모든 항목을 돌려 결과를 모으므로 set -e 를 쓰지 않는다.
# 예외 근거는 docs/standards/shell.md 에 있다.
#
# 사용법:
#   bash scripts/apply-github-repository-settings.sh
#   bash scripts/apply-github-repository-settings.sh --apply
#
# 종료 코드: FAIL 이 하나라도 있으면 1, 알 수 없는 옵션이면 2, 아니면 0

set -uo pipefail

# cd 뒤에는 상대 경로인 BASH_SOURCE 가 안 풀린다. --help 가 자기 파일을 읽으므로 먼저 절대 경로로 잡는다.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SELF="$SCRIPT_DIR/$(basename "${BASH_SOURCE[0]}")"

APPLY=0

# 키|의도한 값|gh 인자 형식. 불리언은 -F 로 보내야 JSON true/false 가 되고,
# 문자열을 -F 로 보내면 gh 가 숫자나 불리언으로 해석하려 든다.
SETTINGS=(
    'allow_squash_merge|true|-F'
    'allow_merge_commit|false|-F'
    'allow_rebase_merge|false|-F'
    'allow_auto_merge|true|-F'
    'delete_branch_on_merge|true|-F'
    'squash_merge_commit_title|PR_TITLE|-f'
    'squash_merge_commit_message|PR_BODY|-f'
)

while [ $# -gt 0 ]; do
    case "$1" in
        --apply)
            APPLY=1
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

report() {
    # $1: 판정, $2: 대상, $3: 사유
    case "$1" in
        PASS) pass_count=$((pass_count + 1)) ;;
        FAIL) fail_count=$((fail_count + 1)) ;;
        SKIP) skip_count=$((skip_count + 1)) ;;
        PLAN | DONE) plan_count=$((plan_count + 1)) ;;
    esac
    printf '%-4s %-28s %s\n' "$1" "$2" "${3:-}"
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

# 현재 값을 한 번에 읽는다. 키마다 부르면 같은 저장소를 일곱 번 조회한다.
JQ_EXPR=""
for entry in "${SETTINGS[@]}"; do
    key="${entry%%|*}"
    JQ_EXPR="${JQ_EXPR:+$JQ_EXPR, }.$key"
done

echo "저장소: $REPO"
if [ "$APPLY" -eq 0 ]; then
    echo "모드:   dry-run. 아무것도 바꾸지 않는다. 반영하려면 --apply 를 준다"
else
    echo "모드:   apply. 아래 차이를 실제로 반영한다"
fi

if ! gh api "repos/$REPO" --jq "[$JQ_EXPR] | .[] | tostring" \
    > "$TMP_DIR/current" 2> "$TMP_DIR/current.err"; then
    cat "$TMP_DIR/current.err" >&2
    report FAIL "$REPO" "설정을 읽지 못했다. gh auth status 와 관리자 권한을 확인한다"
    echo
    echo "결과: PASS $pass_count, FAIL $fail_count, SKIP $skip_count"
    exit 1
fi

echo
echo "[1/2] 현재 값과 의도한 값"

PATCH_ARGS=()
index=0
while IFS= read -r current; do
    index=$((index + 1))
    entry="${SETTINGS[$((index - 1))]}"
    key="${entry%%|*}"
    rest="${entry#*|}"
    want="${rest%%|*}"
    flag="${rest#*|}"

    if [ "$current" = "$want" ]; then
        report PASS "$key" "$current"
        continue
    fi
    report PLAN "$key" "$current -> $want"
    PATCH_ARGS[${#PATCH_ARGS[@]}]="$flag"
    PATCH_ARGS[${#PATCH_ARGS[@]}]="$key=$want"
done < "$TMP_DIR/current"

if [ "$index" -ne "${#SETTINGS[@]}" ]; then
    report FAIL "$REPO" "설정 ${#SETTINGS[@]}개를 물었는데 ${index}개만 돌아왔다"
fi

echo
echo "[2/2] 반영"
if [ "${#PATCH_ARGS[@]}" -eq 0 ]; then
    report PASS "$REPO" "이미 규약대로다. 바꿀 것이 없다"
elif [ "$APPLY" -eq 0 ]; then
    report SKIP "$REPO" "dry-run 이다. --apply 를 줘야 바꾼다"
elif gh api --method PATCH -H "Accept: application/vnd.github+json" \
    "repos/$REPO" "${PATCH_ARGS[@]}" > /dev/null 2> "$TMP_DIR/patch.err"; then
    report DONE "$REPO" "머지 설정을 반영했다"
else
    cat "$TMP_DIR/patch.err" >&2
    report FAIL "$REPO" "반영하지 못했다. 관리자 권한이 필요하다"
fi

echo
echo "브랜치 룰셋은 이 스크립트가 적용하지 않는다."
echo "  .github/rulesets/default-branch.example.json 이 기본이다. 1 인 저장소를 가정한다."
echo "  승인자가 둘 이상이면 default-branch.team.example.json 을 쓴다."
echo "  절차: docs/guides/github-governance-setup.md"

echo
echo "결과: PASS $pass_count, FAIL $fail_count, SKIP $skip_count, 변경 $plan_count"

if [ "$fail_count" -gt 0 ]; then
    echo
    echo "규약: docs/standards/github-enforcement.md" >&2
    exit 1
fi
exit 0
