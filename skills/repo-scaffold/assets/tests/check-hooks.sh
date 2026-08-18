#!/usr/bin/env bash
# 훅 설정 규약 검증. 대상은 .pre-commit-config.yaml 이다.
#
# 검사 대상:
#   1. 순환 방지    훅 entry 에 just 가 없다
#   2. 스테이지     쓰인 stage 가 default_install_hook_types 안에 있다
#   3. entry 대상   bash 로 부르는 스크립트가 실재한다
#   4. 훅 저장소    repo 가 전부 local 이다
#
# 1번이 이 저장소 구조의 핵심 제약이다. Justfile 은 훅 스크립트를 부르고 훅은
# 스크립트를 직접 부른다. 훅 entry 에 just 를 넣으면 prek -> just -> prek 가 되어
# 커밋마다 훅이 자기를 다시 부른다. 규약을 주석이 아니라 검사로 고정한다.
#
# 2번이 가장 조용한 실패 지점이다. default_install_hook_types 가 없으면 prek install
# 이 pre-commit 만 깔고 commit-msg 와 pre-push 훅은 몇 달간 한 번도 돌지 않는다.
#
# 도구를 쓰지 않는다. grep 과 awk 만으로 돈다.
#
# 이 스크립트는 모든 검사를 돌려 결과를 모으므로 set -e 를 쓰지 않는다.
# 예외 근거는 docs/standards/shell.md 에 있다.
#
# 사용법:
#   bash tests/check-hooks.sh
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

REPO_ROOT="$(git rev-parse --show-toplevel 2> /dev/null)" || {
    echo "FAIL: git 저장소가 아니다" >&2
    exit 1
}
cd "$REPO_ROOT" || exit 1

CONFIG=".pre-commit-config.yaml"

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
    printf '%-4s %-34s %s\n' "$1" "$2" "${3:-}"
}

if [ ! -f "$CONFIG" ]; then
    echo "FAIL: $CONFIG 가 없다" >&2
    exit 1
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

# 주석 줄을 뺀 설정. 아직 켜지 않은 훅은 주석으로 남아 있으므로 검사 대상이 아니다.
grep -vE '^[[:space:]]*#' "$CONFIG" > "$TMP_DIR/live"

# YAML 목록 값을 한 줄에 하나씩 낸다. flow([a, b])와 block(- a) 양쪽을 받는다.
# 값에 따옴표나 중첩 구조를 쓰지 않는 전제다. 훅 설정의 stage 목록에는 충분하다.
yaml_list() {
    # $1: 키 이름, $2: 대상 파일
    awk -v key="$1" '
        {
            pat = "^[ \t]*" key ":[ \t]*"
            if ($0 ~ pat) {
                rest = $0
                sub(pat, "", rest)
                sub(/[ \t]*#.*$/, "", rest)
                if (rest ~ /^\[/) {
                    gsub(/^\[|\][ \t]*$/, "", rest)
                    n = split(rest, item, ",")
                    for (i = 1; i <= n; i++) {
                        gsub(/^[ \t]+|[ \t]+$/, "", item[i])
                        if (item[i] != "") print item[i]
                    }
                    inlist = 0
                } else if (rest == "") {
                    inlist = 1
                } else {
                    gsub(/^[ \t]+|[ \t]+$/, "", rest)
                    print rest
                    inlist = 0
                }
                next
            }
            if (inlist && $0 ~ /^[ \t]*-[ \t]*/) {
                one = $0
                sub(/^[ \t]*-[ \t]*/, "", one)
                sub(/[ \t]*#.*$/, "", one)
                gsub(/^[ \t]+|[ \t]+$/, "", one)
                if (one != "") print one
                next
            }
            inlist = 0
        }
    ' "$2"
}

# ---------------------------------------------------------------- 순환 방지

echo "[1/4] 순환 방지"
# 주석 처리된 훅까지 본다. 나중에 주석만 벗겼을 때 순환이 살아나면 안 된다.
# 줄 첫머리의 entry 키만 본다. 산문 안의 just 는 대상이 아니다.
if grep -nE '^[[:space:]]*#?[[:space:]]*entry:.*\bjust\b' "$CONFIG" > "$TMP_DIR/just.out" 2>&1; then
    cat "$TMP_DIR/just.out"
    report FAIL "$CONFIG" "훅 entry 가 just 를 부른다. prek -> just -> prek 순환이다"
else
    report PASS "$CONFIG" "훅 entry 에 just 없음"
fi

# ---------------------------------------------------------------- 스테이지

echo
echo "[2/4] 스테이지"
yaml_list default_install_hook_types "$TMP_DIR/live" | sort -u > "$TMP_DIR/declared"

if [ ! -s "$TMP_DIR/declared" ]; then
    report FAIL default_install_hook_types \
        "없다. prek install 이 pre-commit 만 깔고 나머지 스테이지 훅은 영영 안 돈다"
else
    report PASS default_install_hook_types "$(tr '\n' ' ' < "$TMP_DIR/declared")"

    {
        yaml_list stages "$TMP_DIR/live"
        yaml_list default_stages "$TMP_DIR/live"
    } | sort -u > "$TMP_DIR/used"

    if [ ! -s "$TMP_DIR/used" ]; then
        report SKIP stages "쓰인 stage 가 없다"
    else
        while IFS= read -r stage; do
            [ -n "$stage" ] || continue
            if grep -qxF "$stage" "$TMP_DIR/declared"; then
                report PASS "stage: $stage" "설치 대상에 들어 있다"
            else
                report FAIL "stage: $stage" "default_install_hook_types 에 없다. 이 훅은 설치되지 않는다"
            fi
        done < "$TMP_DIR/used"
    fi
fi

# ---------------------------------------------------------------- entry 대상

echo
echo "[3/4] entry 대상"
sed -n 's/^[[:space:]]*entry:[[:space:]]*//p' "$TMP_DIR/live" \
    | sed 's/[[:space:]]*$//' \
    | sort -u > "$TMP_DIR/entries"

if [ ! -s "$TMP_DIR/entries" ]; then
    report SKIP entry "정의된 훅이 없다"
else
    while IFS= read -r entry; do
        [ -n "$entry" ] || continue
        case "$entry" in
            # .github/ 도 저장소 안이다. 저장소 전용 훅이 거기 스크립트를 부르는 일이
            # 흔한데, 빼두면 그 훅만 "저장소 안 스크립트 호출이 아니다" 로 SKIP 된다.
            # 사실이 아닌 SKIP 이라 스크립트가 없어져도 아무도 모른다.
            "bash tests/"* | "bash scripts/"* | "bash .github/"*)
                target="${entry#bash }"
                target="${target%% *}"
                if [ -f "$target" ]; then
                    report PASS "$target" "실재한다"
                else
                    report FAIL "$target" "훅이 부르는 스크립트가 없다. 매 커밋 실패한다"
                fi
                ;;
            *)
                report SKIP "$entry" "저장소 안 스크립트 호출이 아니다"
                ;;
        esac
    done < "$TMP_DIR/entries"
fi

# ---------------------------------------------------------------- 훅 저장소

echo
echo "[4/4] 훅 저장소"
sed -n 's/^[[:space:]]*-\{0,1\}[[:space:]]*repo:[[:space:]]*//p' "$TMP_DIR/live" \
    | sed 's/[[:space:]]*$//' \
    | sort -u > "$TMP_DIR/repos"

if [ ! -s "$TMP_DIR/repos" ]; then
    report FAIL repo "repo 항목이 없다"
else
    while IFS= read -r repo; do
        [ -n "$repo" ] || continue
        if [ "$repo" = "local" ]; then
            report PASS "repo: $repo" "외부 의존 없음"
        else
            report FAIL "repo: $repo" "외부 저장소를 받는다. 커밋마다 clone 이 필요하고 도는 코드가 저장소 밖에 있다"
        fi
    done < "$TMP_DIR/repos"
fi

echo
echo "결과: PASS $pass_count, FAIL $fail_count, SKIP $skip_count"

if [ "$fail_count" -gt 0 ]; then
    echo
    echo "규약: 훅은 tests/*.sh 와 scripts/*.sh 를 직접 부른다. Justfile 을 거치지 않는다" >&2
    exit 1
fi
exit 0
