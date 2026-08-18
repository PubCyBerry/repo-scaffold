#!/usr/bin/env bash
# 개발 환경 진단. 무엇이 없고 무엇이 어긋났는지 보고만 하고 아무것도 고치지 않는다.
#
# 검사 대상:
#   1. 실행 환경    bash, git, 저장소 루트
#   2. 명령 레이어  just, Justfile 파싱, 남은 치환 자리표시자
#   3. 도구         tools.txt 와 uv tool list 대조, 그리고 Node 와 commitlint
#   4. git 훅       설치된 훅 파일
#
# Node 는 tools.txt 에 없다. uv 채널 밖이고 commitlint 하나를 위한 도구 의존성이다.
# 그래서 없으면 commit-msg 훅의 형식 검사가 조용히 SKIP 된다. 여기서 보고하지 않으면
# 그 SKIP 이 불편한 정도가 아니라 보이지 않는 것이 된다.
#
# 버전 대조는 uv tool list 로 한다. 실행 파일의 --version 과 대조하지 않는다.
# 예를 들어 shellcheck-py==0.11.0.1 이 까는 실행 파일은 자기 버전을 0.11.0 이라고 답한다.
#
# uv 밖에서 설치한 도구는 버전이 고정되지 않는다. 경로만 보고하고 통과시킨다.
#
# 도구가 없으면 로컬에서는 SKIP, CI(환경변수 CI=true)에서는 FAIL 이다.
#
# 이 스크립트는 모든 검사를 돌려 결과를 모으므로 set -e 를 쓰지 않는다.
# 예외 근거는 docs/standards/shell.md 에 있다.
#
# 사용법:
#   bash scripts/doctor.sh
#
# 종료 코드: FAIL 이 하나라도 있으면 1, 알 수 없는 옵션이면 2, 아니면 0

set -uo pipefail

# cd 뒤에는 상대 경로인 BASH_SOURCE 가 안 풀린다. --help 가 자기 파일을 읽으므로 먼저 절대 경로로 잡는다.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SELF="$SCRIPT_DIR/$(basename "${BASH_SOURCE[0]}")"

case "${1:-}" in
    -h | --help)
        sed -n '2,/^$/p' "$SELF"
        exit 0
        ;;
    "") ;;
    *)
        echo "알 수 없는 옵션: $1" >&2
        exit 2
        ;;
esac

TOOLS_FILE="tools.txt"
JUSTFILE="Justfile"

# 치환되지 않고 남은 스캐폴딩 자리표시자. 남아 있으면 just 가 파싱 단계에서 죽는다.
PLACEHOLDER_PATTERN='\{\{[A-Z][A-Z0-9_]*\}\}'

pass_count=0
fail_count=0
skip_count=0
note_count=0

report() {
    # $1: 판정, $2: 대상, $3: 사유
    case "$1" in
        PASS) pass_count=$((pass_count + 1)) ;;
        FAIL) fail_count=$((fail_count + 1)) ;;
        SKIP) skip_count=$((skip_count + 1)) ;;
        NOTE) note_count=$((note_count + 1)) ;;
    esac
    printf '%-4s %-26s %s\n' "$1" "$2" "${3:-}"
}

# 도구가 없을 때의 판정. CI 에서는 없는 것이 FAIL 이다.
missing_tool() {
    # $1: 이름, $2: 사유, $3: 설치 안내를 찾을 도구 이름(기본값 $1)
    if [ "${CI:-}" = "true" ]; then
        report FAIL "$1" "$2"
    else
        report SKIP "$1" "$2"
    fi
    bash scripts/tool-help.sh "${3:-$1}"
}

# --- 1. 실행 환경 -------------------------------------------------------------

echo "[1/4] 실행 환경"

report PASS bash "${BASH_VERSION:-알 수 없음} ($(command -v bash 2> /dev/null || echo '경로 미상'))"

if ! command -v git > /dev/null 2>&1; then
    report FAIL git "미설치. git 없이는 아무 검사도 돌지 않는다"
    echo
    echo "결과: PASS $pass_count, FAIL $fail_count, SKIP $skip_count, NOTE $note_count"
    exit 1
fi

REPO_ROOT="$(git rev-parse --show-toplevel 2> /dev/null)" || {
    report FAIL git "저장소가 아니다. git init 을 먼저 한다"
    echo
    echo "결과: PASS $pass_count, FAIL $fail_count, SKIP $skip_count, NOTE $note_count"
    exit 1
}
cd "$REPO_ROOT" || exit 1
report PASS git "$(git --version 2>&1 | head -1) / 루트 $REPO_ROOT"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

# --- 2. 명령 레이어 -----------------------------------------------------------

echo
echo "[2/4] 명령 레이어"

# Justfile 이 스캐폴딩 치환을 다 받았는지 본다. 자리표시자가 남으면 모든 레시피가 죽는다.
if [ ! -f "$JUSTFILE" ]; then
    report FAIL "$JUSTFILE" "없다. 명령 레이어가 없으면 just verify 가 돌지 않는다"
elif grep -nE "$PLACEHOLDER_PATTERN" "$JUSTFILE" > "$TMP_DIR/placeholders" 2>&1; then
    cat "$TMP_DIR/placeholders"
    report FAIL "$JUSTFILE" "치환되지 않은 자리표시자가 남았다. just 가 파싱 단계에서 죽는다"
else
    report PASS "$JUSTFILE" "자리표시자 없음"
fi

JUST_BIN="${JUST:-just}"
if just_version="$("$JUST_BIN" --version 2>&1)"; then
    report PASS just "$just_version"
    if summary="$("$JUST_BIN" --summary 2>&1)"; then
        report PASS "just --summary" "레시피 $(printf '%s' "$summary" | wc -w | tr -d ' ')개"
    else
        printf '%s\n' "$summary"
        report FAIL "just --summary" "Justfile 파싱 실패"
    fi
else
    missing_tool just "미설치"
fi

if command -v prek > /dev/null 2>&1; then
    report PASS prek "$(prek --version 2>&1 | head -1)"
else
    missing_tool prek "미설치"
fi

# --- 3. 도구 ------------------------------------------------------------------

echo
echo "[3/4] 도구 (tools.txt)"

# uv 가 없어도 아래 루프는 돈다. PATH 에 있는 도구를 uv 밖 설치로 보고해야 하기 때문이다.
: > "$TMP_DIR/installed"

if ! command -v uv > /dev/null 2>&1; then
    missing_tool uv "미설치"
elif ! uv tool list > "$TMP_DIR/uv-tools" 2>&1; then
    cat "$TMP_DIR/uv-tools"
    report FAIL uv "uv tool list 실패"
else
    # uv tool list 는 "패키지 v버전" 줄과 "- 실행파일" 줄을 번갈아 낸다.
    awk '/^[A-Za-z0-9._-]+ v/ { sub(/^v/, "", $2); print $1 "\t" $2 }' \
        "$TMP_DIR/uv-tools" > "$TMP_DIR/installed"
fi

if [ ! -f "$TOOLS_FILE" ]; then
    report FAIL "$TOOLS_FILE" "없다. 도구 버전의 단일 출처다"
else
    while read -r spec source binary; do
        [ -n "$spec" ] || continue
        case "$spec" in \#*) continue ;; esac

        pkg="${spec%%==*}"
        want="${spec#*==}"
        binary="${binary:-$pkg}"

        if [ "$source" != "uv" ]; then
            # uv 로 깔 수 없는 도구다. 버전은 고정할 수 없어도 도는지 안 도는지는 볼 수 있다.
            # NOTE 한 줄로 뭉개면 아예 없는 도구가 "손으로 설치한다" 안내에 묻히고,
            # 그 도구를 부르는 검사는 진단에 안 잡힌 채로 실패한다.
            #
            # command -v 로 끝내지 않고 실제로 실행해 본다. PATH 에는 멀쩡히 잡히면서
            # exec 에서 Permission denied 로 죽는 shim 이 실재한다. 그런 도구는 진단에
            # PASS 로 찍히고 정작 그것을 부르는 검사는 엉뚱한 이유로 실패한다.
            # 출력은 버리고 종료 코드만 본다. 버전 문자열은 믿을 것이 못 된다.
            if "$binary" --version > /dev/null 2>&1; then
                report NOTE "$binary" "출처 $source. 버전이 고정되지 않는다: $(command -v "$binary")"
            elif command -v "$binary" > /dev/null 2>&1; then
                report FAIL "$binary" "PATH 에 있지만 실행되지 않는다: $(command -v "$binary")"
            else
                missing_tool "$binary" "미설치. 출처 $source"
            fi
            continue
        fi

        have="$(awk -F'\t' -v p="$pkg" '$1 == p { print $2; exit }' "$TMP_DIR/installed")"

        if [ -z "$have" ]; then
            if command -v "$binary" > /dev/null 2>&1; then
                report NOTE "$binary" "uv 밖에서 설치됨. 버전이 고정되지 않는다: $(command -v "$binary")"
            else
                missing_tool "$binary" "미설치"
            fi
        elif [ "$have" = "$want" ]; then
            report PASS "$binary" "$pkg $have"
        else
            report FAIL "$binary" "$pkg 가 $have. tools.txt 는 $want. bash scripts/bootstrap.sh 로 맞춘다"
        fi
    done < "$TOOLS_FILE"
fi

# Node 는 tools.txt 밖이다. uv 로 깔리지 않고 commitlint 만 쓴다.
# node_modules 는 gitignore 대상이라 링크된 worktree 에는 없다. 주 저장소의 것도 함께 본다.
#
# 판정 조건은 tests/check-commit-msg.sh 의 것과 같아야 한다. 이 스크립트가 "주 저장소의
# 것을 쓴다" 고 말하는데 검사기는 SKIP 을 내면, 죽은 게이트와 산 게이트를 구분하려고
# 만든 보고가 정반대를 말하게 된다. 그래서 설정 파일 조건까지 여기서 같이 본다.
COMMITLINT_BIN="node_modules/.bin/commitlint"
COMMITLINT_CONFIGS="
.commitlintrc
.commitlintrc.json
.commitlintrc.yaml
.commitlintrc.yml
.commitlintrc.js
.commitlintrc.cjs
.commitlintrc.mjs
.commitlintrc.ts
.commitlintrc.cts
commitlint.config.js
commitlint.config.cjs
commitlint.config.mjs
commitlint.config.ts
commitlint.config.cts
"
MAIN_ROOT="$(git rev-parse --path-format=absolute --git-common-dir 2> /dev/null)"
MAIN_ROOT="$(dirname "${MAIN_ROOT:-.}")"

find_commitlint_config() {
    # $1: 루트 디렉터리. 찾으면 경로를 내고 0, 없으면 1
    local root="$1" name
    for name in $COMMITLINT_CONFIGS; do
        if [ -f "$root/$name" ]; then
            printf '%s' "$root/$name"
            return 0
        fi
    done
    if [ -f "$root/package.json" ] && grep -q '"commitlint"[[:space:]]*:' "$root/package.json"; then
        printf 'package.json'
        return 0
    fi
    return 1
}

if command -v node > /dev/null 2>&1; then
    report PASS node "$(node --version 2>&1 | head -1) ($(command -v node))"
else
    missing_tool node "미설치. 커밋 메시지 형식 검사가 SKIP 된다"
fi

if command -v npm > /dev/null 2>&1; then
    report PASS npm "$(npm --version 2>&1 | head -1)"
else
    missing_tool npm "미설치. node_modules 를 만들 수 없다"
fi

LOCAL_CONFIG="$(find_commitlint_config .)" || LOCAL_CONFIG=""
MAIN_CONFIG="$(find_commitlint_config "$MAIN_ROOT")" || MAIN_CONFIG=""

if [ -x "$COMMITLINT_BIN" ]; then
    report PASS commitlint "$COMMITLINT_BIN"
elif [ ! -x "$MAIN_ROOT/$COMMITLINT_BIN" ]; then
    missing_tool commitlint "미설치"
elif [ -z "$LOCAL_CONFIG" ] || [ -z "$MAIN_CONFIG" ]; then
    missing_tool commitlint "주 저장소에 설치는 있으나 설정 파일을 못 찾아 쓸 수 없다"
elif [ "$LOCAL_CONFIG" = "package.json" ] || [ "$MAIN_CONFIG" = "package.json" ]; then
    missing_tool commitlint "설정이 package.json 안에 있어 주 저장소의 설치를 빌려 쓸 수 없다"
elif ! cmp -s "$LOCAL_CONFIG" "$MAIN_CONFIG"; then
    missing_tool commitlint "이 worktree 의 설정이 주 저장소와 달라 빌려 쓰지 않는다. npm ci 를 여기서 돌린다"
else
    report NOTE commitlint "이 worktree 에는 없다. 주 저장소의 것을 쓴다: $MAIN_ROOT/$COMMITLINT_BIN"
fi

# --- 4. git 훅 ----------------------------------------------------------------

echo
echo "[4/4] git 훅"

# core.hooksPath 가 설정돼 있으면 .git/hooks 가 아니라 그쪽이 쓰인다.
HOOK_DIR="$(git config --get core.hooksPath 2> /dev/null)"
if [ -z "$HOOK_DIR" ]; then
    HOOK_DIR="$(git rev-parse --git-path hooks 2> /dev/null)"
fi

if [ -z "$HOOK_DIR" ] || [ ! -d "$HOOK_DIR" ]; then
    report SKIP hook-dir "$HOOK_DIR 가 없다. bash scripts/bootstrap.sh 를 돌린다"
else
    report PASS hook-dir "$HOOK_DIR"
    for hook in pre-commit commit-msg pre-push; do
        if [ ! -f "$HOOK_DIR/$hook" ]; then
            report SKIP "$hook" "미설치. bash scripts/bootstrap.sh 를 돌린다"
        elif grep -q 'prek' "$HOOK_DIR/$hook" 2> /dev/null; then
            report PASS "$hook" "prek 훅"
        else
            report NOTE "$hook" "prek 가 깐 훅이 아니다. 내용을 확인한다"
        fi
    done
fi

echo
echo "결과: PASS $pass_count, FAIL $fail_count, SKIP $skip_count, NOTE $note_count"

if [ "$skip_count" -gt 0 ] && [ "${CI:-}" != "true" ]; then
    echo
    echo "SKIP 은 도구가 없다는 뜻이다. bash scripts/bootstrap.sh 로 한 번에 깐다"
fi

if [ "$fail_count" -gt 0 ]; then
    exit 1
fi
exit 0
