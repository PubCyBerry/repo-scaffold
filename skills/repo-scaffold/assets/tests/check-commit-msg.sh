#!/usr/bin/env bash
# 커밋 메시지 규약 검증. commit-msg 훅과 CI 가 부른다.
#
# 검사 단계. --only 로 고른다. 기본은 전부다.
#   conventional  commitlint  Conventional Commits 형식. 규칙은 commitlint.config.mjs
#   notation      bash        제목의 금지 문자. 규칙은 styles/Project/Punctuation.yml 과 같다
#
# 검사 대상을 고르는 방법은 둘이다.
#   메시지 파일  첫 번째 인자. 없으면 git 이 알려주는 COMMIT_EDITMSG 를 쓴다
#   --range      base..head 안의 커밋 전부. CI 가 PR 범위로 부른다
#
# commit-msg 훅은 메시지 파일 경로를 인자로 넘기므로 훅에서는 인자가 항상 있다.
# 커밋 중이 아니면 그 파일이 없다. 검사할 것이 없으므로 CI 에서도 SKIP 이다.
# CI 는 범위를 명시해서 부른다. 범위 없이 부르는 CI 잡은 그 자체가 워크플로 결함이고,
# 메시지 파일이 없다는 사실은 저장소의 결함이 아니라 그 순간 커밋 중이 아니라는 뜻이다.
#
# conventional 단계는 node_modules/.bin/commitlint 를 직접 부른다. npx 를 쓰지 않는다.
# npx 는 훅 안에서 네트워크를 타서 커밋마다 멈추고 공급망 표면을 하나 더 만든다.
#
# node_modules 는 gitignore 대상이라 링크된 git worktree 에는 없다. 그런데 이 저장소는
# 병렬 작업에 worktree 를 쓰라고 문서에 적어 두었다. 그래서 현재 worktree 에 없으면
# 주 저장소의 node_modules 를 찾아 쓴다. 그때는 --config 도 함께 넘긴다. 안 넘기면
# commitlint 가 extends 를 현재 디렉터리 기준으로 풀어 config-conventional 을 못 찾는다.
# 양쪽 모두에 없으면 로컬에서는 SKIP, CI(환경변수 CI=true)에서는 FAIL 이다.
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
#   bash tests/check-commit-msg.sh --range main..HEAD    # 범위 안의 커밋 전부
#
# 종료 코드: FAIL 이 하나라도 있으면 1, 알 수 없는 옵션이면 2, 아니면 0

set -uo pipefail

# cd 뒤에는 상대 경로인 BASH_SOURCE 가 안 풀린다. --help 가 자기 파일을 읽으므로 먼저 절대 경로로 잡는다.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SELF="$SCRIPT_DIR/$(basename "${BASH_SOURCE[0]}")"

ALL_PHASES="conventional notation"
PHASES="$ALL_PHASES"
MSG_FILE=""
RANGE=""

COMMITLINT="node_modules/.bin/commitlint"
COMMITLINT_ARGS=()
INSTALL_HINT="npm ci (또는 just bootstrap)"

# 주 저장소에서 찾아볼 설정 파일 이름. commitlint 가 스스로 찾는 이름 중 이 스킬이
# 배포하는 것과 흔한 변형만 본다. 못 찾으면 폴백을 쓰지 않는다.
COMMITLINT_CONFIGS="commitlint.config.mjs commitlint.config.js commitlint.config.cjs"

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
        --range)
            if [ "$#" -lt 2 ]; then
                echo "FAIL: --range 값이 없다" >&2
                exit 2
            fi
            RANGE="$2"
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

if [ -n "$RANGE" ] && [ -n "$MSG_FILE" ]; then
    echo "FAIL: --range 와 메시지 파일을 함께 줄 수 없다" >&2
    exit 2
fi

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

# 링크된 worktree 에는 node_modules 가 없다. 주 저장소의 것을 찾아 쓴다.
# --git-common-dir 은 worktree 가 공유하는 .git 을 가리키고 그 부모가 주 저장소 루트다.
if [ ! -x "$COMMITLINT" ]; then
    MAIN_ROOT="$(git rev-parse --path-format=absolute --git-common-dir 2> /dev/null)"
    MAIN_ROOT="$(dirname "${MAIN_ROOT:-.}")"
    if [ -x "$MAIN_ROOT/node_modules/.bin/commitlint" ]; then
        for config_name in $COMMITLINT_CONFIGS; do
            [ -f "$MAIN_ROOT/$config_name" ] || continue
            main_config="$MAIN_ROOT/$config_name"
            # node 는 Git Bash 의 /c/... 형식 경로를 이해하지 못한다.
            if command -v cygpath > /dev/null 2>&1; then
                main_config="$(cygpath -m "$main_config")"
            fi
            COMMITLINT="$MAIN_ROOT/node_modules/.bin/commitlint"
            COMMITLINT_ARGS=(--config "$main_config")
            break
        done
    fi
fi

# worktree 와 submodule 에서는 .git 이 디렉터리가 아니다. 경로를 직접 짜지 않고 git 에게 묻는다.
if [ -z "$RANGE" ] && [ -z "$MSG_FILE" ]; then
    MSG_FILE="$(git rev-parse --git-path COMMIT_EDITMSG)"
fi

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

# git 이 보는 제목과 같은 규칙으로 뽑는다. 주석 줄과 앞의 빈 줄을 건너뛴 첫 줄이다.
# 주석 문자는 core.commentChar 로 바뀐다. auto 처럼 한 글자가 아니면 기본값을 쓴다.
COMMENT_CHAR="$(git config --get core.commentChar 2> /dev/null)"
case "$COMMENT_CHAR" in
    ?) ;;
    *) COMMENT_CHAR="#" ;;
esac

subject_of() {
    # $1: 메시지 파일
    local line
    while IFS= read -r line; do
        line="${line%$'\r'}"
        case "$line" in
            "$COMMENT_CHAR"* | "") continue ;;
        esac
        printf '%s' "$line"
        return 0
    done < "$1"
    return 0
}

# 검사 대상. 파일 모드는 하나, 범위 모드는 커밋마다 하나다.
TARGET_FILES=()
TARGET_LABELS=()

# 보고 라벨. 파일 모드는 단계 이름을 쓰고 범위 모드는 커밋을 짚는다.
target_label() {
    # $1: 인덱스, $2: 파일 모드에서 쓸 이름
    if [ -n "$RANGE" ]; then
        printf '%s' "${TARGET_LABELS[$1]}"
    else
        printf '%s' "$2"
    fi
}

if [ -n "$RANGE" ]; then
    # 임시 파일은 저장소 밖에 둔다. 저장소 안에 두면 검사 대상에 섞인다.
    TMP_DIR="$(mktemp -d)"
    trap 'rm -rf "$TMP_DIR"' EXIT

    if ! REVS="$(git rev-list --no-merges --reverse "$RANGE" 2> "$TMP_DIR/rev-list.err")"; then
        cat "$TMP_DIR/rev-list.err" >&2
        echo "FAIL: 범위를 읽을 수 없다: $RANGE" >&2
        echo "      전체 이력이 필요하다. CI 는 checkout 에 fetch-depth: 0 을 준다" >&2
        exit 1
    fi

    while IFS= read -r rev; do
        [ -n "$rev" ] || continue
        git log -1 --format=%B "$rev" > "$TMP_DIR/$rev.msg" || continue
        TARGET_FILES[${#TARGET_FILES[@]}]="$TMP_DIR/$rev.msg"
        TARGET_LABELS[${#TARGET_LABELS[@]}]="${rev:0:8}"
    done <<< "$REVS"

    echo "검사 범위: $RANGE (커밋 ${#TARGET_FILES[@]}개)"
    if [ "${#TARGET_FILES[@]}" -eq 0 ]; then
        echo "SKIP 범위 안에 검사할 커밋이 없다"
        exit 0
    fi
else
    if [ ! -f "$MSG_FILE" ]; then
        echo "SKIP 검사할 커밋 메시지가 없다: $MSG_FILE"
        exit 0
    fi
    TARGET_FILES[0]="$MSG_FILE"
    TARGET_LABELS[0]="$MSG_FILE"
    echo "메시지 파일: $MSG_FILE"
fi

# ---------------------------------------------------------------- 형식

if phase_on conventional; then
    banner "commitlint"
    if [ ! -x "$COMMITLINT" ]; then
        missing_tool commitlint "이 저장소와 주 저장소 어디에도 없다. 설치: $INSTALL_HINT"
    elif ! command -v node > /dev/null 2>&1; then
        missing_tool node "미설치. commitlint 를 실행할 수 없다"
    else
        index=0
        while [ "$index" -lt "${#TARGET_FILES[@]}" ]; do
            label="$(target_label "$index" commitlint)"
            if out="$("$COMMITLINT" ${COMMITLINT_ARGS[@]+"${COMMITLINT_ARGS[@]}"} \
                --edit "${TARGET_FILES[$index]}" 2>&1)"; then
                report PASS "$label" "Conventional Commits 형식"
            else
                printf '%s\n' "$out"
                report FAIL "$label" "형식은 docs/standards/commit-convention.md 에 있다"
            fi
            index=$((index + 1))
        done
    fi
fi

# ---------------------------------------------------------------- 표기

if phase_on notation; then
    banner "제목 표기"
    index=0
    while [ "$index" -lt "${#TARGET_FILES[@]}" ]; do
        label="$(target_label "$index" subject)"
        SUBJECT="$(subject_of "${TARGET_FILES[$index]}")"
        if [ -z "$SUBJECT" ]; then
            report SKIP "$label" "메시지가 비어 있다"
        elif machine_generated "$SUBJECT"; then
            report SKIP "$label" "기계가 만든 제목이다. 원문을 그대로 옮긴 것이라 검사하지 않는다"
        else
            # 범위 모드에서는 어느 커밋인지 짚어야 한다. 대상 이름은 문자 이름이 차지한다.
            if [ -n "$RANGE" ]; then
                where="커밋 $label 의 "
            else
                where=""
            fi
            notation_hit=0
            for entry in "${NOTATION[@]}"; do
                name="${entry%%|*}"
                char="${entry#*|}"
                case "$SUBJECT" in
                    *"$char"*)
                        notation_hit=1
                        report FAIL "$name" \
                            "${where}제목에 있다. 대체 표기는 docs/standards/writing-style.md 에 있다"
                        ;;
                esac
            done
            [ "$notation_hit" -eq 0 ] && report PASS "$label" "금지 문자 없음"
        fi
        index=$((index + 1))
    done
fi

echo
echo "결과: PASS $pass_count, FAIL $fail_count, SKIP $skip_count"

if [ "$fail_count" -gt 0 ]; then
    echo
    echo "규약: docs/standards/commit-convention.md" >&2
    exit 1
fi
exit 0
