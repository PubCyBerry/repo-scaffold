#!/usr/bin/env bash
# 커밋 메시지 규약 검증. commit-msg 훅이 부른다.
#
# 검사 단계. --only 로 고른다. 기본은 전부다.
#   conventional  commitlint  Conventional Commits 형식. 규칙은 commitlint.config.mjs
#   notation      bash        제목의 금지 문자. 규칙은 styles/Project/Punctuation.yml 과 같다
#
# 검사할 메시지 파일은 첫 번째 인자다. 없으면 git 이 알려주는 COMMIT_EDITMSG 를 쓴다.
# commit-msg 훅은 메시지 파일 경로를 인자로 넘기므로 훅에서는 인자가 항상 있다.
# 커밋 중이 아니면 그 파일이 없다. 검사할 것이 없으므로 CI 에서도 SKIP 이다.
#
# conventional 단계는 node_modules/.bin/commitlint 를 직접 부른다. npx 를 쓰지 않는다.
# npx 는 훅 안에서 네트워크를 타서 커밋마다 멈추고 공급망 표면을 하나 더 만든다.
# node_modules 가 없으면 로컬에서는 SKIP, CI(환경변수 CI=true)에서는 FAIL 이다.
# 폐쇄망에서는 이 단계가 계속 SKIP 이다. 훅이 도는 것과 훅이 작동하는 것은 다르다.
#
# notation 단계는 도구를 쓰지 않는다. 그래서 node_modules 가 없어도 돈다.
# 대상은 제목 한 줄뿐이다. 본문은 도구 출력을 그대로 붙이는 자리이고 코드 블록 표시가
# 없어서 예외를 구분할 수 없다. 본문은 사람이 판단한다.
# 기계가 만든 제목(fixup!, squash!, amend!, Merge, Revert)은 원문을 그대로 옮긴 것이라 넘어간다.
#
# 이 스크립트는 모든 검사를 돌려 결과를 모으므로 set -e 를 쓰지 않는다.
# 예외 근거는 docs/standards/shell.md 에 있다.
#
# 사용법:
#   bash tests/check-commit-msg.sh                       # COMMIT_EDITMSG
#   bash tests/check-commit-msg.sh .git/COMMIT_EDITMSG   # 파일 지정
#   bash tests/check-commit-msg.sh --only notation       # 한 단계만
#
# 종료 코드: FAIL 이 하나라도 있으면 1, 알 수 없는 옵션이면 2, 아니면 0

set -uo pipefail

# cd 뒤에는 상대 경로인 BASH_SOURCE 가 안 풀린다. --help 가 자기 파일을 읽으므로 먼저 절대 경로로 잡는다.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SELF="$SCRIPT_DIR/$(basename "${BASH_SOURCE[0]}")"

ALL_PHASES="conventional notation"
PHASES="$ALL_PHASES"
MSG_FILE=""

COMMITLINT="node_modules/.bin/commitlint"
INSTALL_HINT="npm ci (또는 just bootstrap)"

# 제목에서 금지하는 문자. 이름|문자 쌍이다.
# 목록은 styles/Project/Punctuation.yml 과 같은 것이고 원본은
# docs/standards/writing-style.md 의 Notation 표다. Vale 은 마크다운만 보므로
# 커밋 메시지에는 여기서 같은 규칙을 건다.
# hyphen 두 개는 앞뒤에 공백이 있을 때만 잡는다. --no-cache 같은 옵션 접두사는 규약의 예외다.
NOTATION=(
    'interpunct|·'
    'em dash|—'
    'en dash|–'
    'double hyphen| -- '
    'ditto mark|〃'
)

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
        -*)
            echo "알 수 없는 옵션: $1" >&2
            exit 2
            ;;
        *)
            if [ -n "$MSG_FILE" ]; then
                echo "알 수 없는 인자: $1" >&2
                exit 2
            fi
            MSG_FILE="$1"
            shift
            ;;
    esac
done

# 저장소 루트로 옮기기 전에 경로를 루트 기준으로 되돌린다. commitlint 는 node 로 파일을 읽어서
# Git Bash 의 /c/... 형식 절대 경로를 이해하지 못한다. 상대 경로로 넘기면 그 문제가 없다.
case "$MSG_FILE" in
    "") ;;
    /* | ?:*)
        if command -v cygpath > /dev/null 2>&1; then
            MSG_FILE="$(cygpath -m "$MSG_FILE")"
        fi
        ;;
    *) MSG_FILE="$(git rev-parse --show-prefix 2> /dev/null)$MSG_FILE" ;;
esac

# 스크립트 위치가 아니라 git 이 루트를 정한다. tests/ 를 옮겨도 따라온다.
REPO_ROOT="$(git rev-parse --show-toplevel 2> /dev/null)" || {
    echo "FAIL: git 저장소가 아니다" >&2
    exit 1
}
cd "$REPO_ROOT" || exit 1

# worktree 와 submodule 에서는 .git 이 디렉터리가 아니다. 경로를 직접 짜지 않고 git 에게 묻는다.
[ -n "$MSG_FILE" ] || MSG_FILE="$(git rev-parse --git-path COMMIT_EDITMSG)"

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
    printf '%-4s %-16s %s\n' "$1" "$2" "${3:-}"
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

# 도구가 없으면 판정만 남긴다. CI 에서는 없는 것이 FAIL 이다.
missing_tool() {
    # $1: 이름, $2: 사유
    if [ "${CI:-}" = "true" ]; then
        report FAIL "$1" "$2"
    else
        report SKIP "$1" "$2"
    fi
}

# 기계가 만들거나 원문을 그대로 옮기는 제목. 표기 검사에서 뺀다.
# fixup!/squash!/amend! 는 원래 제목을 그대로 달고 Merge 와 Revert 는 git 이 만든다.
machine_generated() {
    case "$1" in
        "fixup! "* | "squash! "* | "amend! "* | "Merge "* | 'Revert "'*) return 0 ;;
    esac
    return 1
}

if [ ! -f "$MSG_FILE" ]; then
    echo "SKIP 검사할 커밋 메시지가 없다: $MSG_FILE"
    exit 0
fi

# git 이 보는 제목과 같은 규칙으로 뽑는다. 주석 줄과 앞의 빈 줄을 건너뛴 첫 줄이다.
# 주석 문자는 core.commentChar 로 바뀐다. auto 처럼 한 글자가 아니면 기본값을 쓴다.
COMMENT_CHAR="$(git config --get core.commentChar 2> /dev/null)"
case "$COMMENT_CHAR" in
    ?) ;;
    *) COMMENT_CHAR="#" ;;
esac

SUBJECT=""
while IFS= read -r line; do
    line="${line%$'\r'}"
    case "$line" in
        "$COMMENT_CHAR"* | "") continue ;;
    esac
    SUBJECT="$line"
    break
done < "$MSG_FILE"

echo "메시지 파일: $MSG_FILE"

# ---------------------------------------------------------------- 형식

if phase_on conventional; then
    banner "commitlint"
    if [ ! -x "$COMMITLINT" ]; then
        missing_tool commitlint "미설치. 설치: $INSTALL_HINT"
    elif ! command -v node > /dev/null 2>&1; then
        missing_tool node "미설치. commitlint 를 실행할 수 없다"
    elif out="$("$COMMITLINT" --edit "$MSG_FILE" 2>&1)"; then
        report PASS commitlint "Conventional Commits 형식"
    else
        printf '%s\n' "$out"
        report FAIL commitlint "형식은 docs/standards/commit-convention.md 에 있다"
    fi
fi

# ---------------------------------------------------------------- 표기

if phase_on notation; then
    banner "제목 표기"
    if [ -z "$SUBJECT" ]; then
        report SKIP subject "메시지가 비어 있다"
    elif machine_generated "$SUBJECT"; then
        report SKIP subject "기계가 만든 제목이다. 원문을 그대로 옮긴 것이라 검사하지 않는다"
    else
        notation_hit=0
        for entry in "${NOTATION[@]}"; do
            name="${entry%%|*}"
            char="${entry#*|}"
            case "$SUBJECT" in
                *"$char"*)
                    notation_hit=1
                    report FAIL "$name" "제목에 있다. 대체 표기는 docs/standards/writing-style.md 에 있다"
                    ;;
            esac
        done
        [ "$notation_hit" -eq 0 ] && report PASS subject "금지 문자 없음"
    fi
fi

echo
echo "결과: PASS $pass_count, FAIL $fail_count, SKIP $skip_count"

if [ "$fail_count" -gt 0 ]; then
    echo
    echo "규약: docs/standards/commit-convention.md" >&2
    exit 1
fi
exit 0
