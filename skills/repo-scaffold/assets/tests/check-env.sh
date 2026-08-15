#!/usr/bin/env bash
# .env 와 .env.example 의 키 동기화 검증 스크립트.
#
# 저장소의 모든 *.env.example 을 찾아 같은 디렉터리의 .env 와 짝지어 검사한다.
# 저장소 루트와 하위 컴포넌트를 모두 덮는다.
#
# 검사 대상:
#   1. 파일 안 키 중복
#   2. .env.example 과 .env 의 키 집합 일치
#   3. .env.example 의 비밀 키(TOKEN/KEY/SECRET/PASSWORD 등) 값이 비어 있는지
#
# 값은 어디에도 출력하지 않는다. 키 이름만 다룬다. 규약: SECURITY.md
#
# 사용법:
#   bash tests/check-env.sh          # 전체 검사
#   bash tests/check-env.sh --strict # .env 가 없으면 SKIP 이 아니라 FAIL
#
# 종료 코드: FAIL 이 하나라도 있으면 1, 아니면 0

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# 값이 비어 있어야 하는 키. .env.example 은 커밋되므로 실값이 들어가면 유출이다.
SECRET_KEY_PATTERN='(TOKEN|KEY|SECRET|PASSWORD|PASSWD|CREDENTIAL|APIKEY)'

STRICT=0

while [ $# -gt 0 ]; do
    case "$1" in
        --strict)  STRICT=1; shift ;;
        -h|--help) sed -n '2,20p' "${BASH_SOURCE[0]}"; exit 0 ;;
        *)         echo "알 수 없는 옵션: $1" >&2; exit 2 ;;
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
    printf '%-4s %-44s %s\n' "$1" "$2" "${3:-}"
}

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

# 파일에서 키 이름만 뽑는다. 주석과 값은 버린다. `export KEY=` 형태도 받는다.
keys_of() {
    tr -d '\r' < "$1" \
        | sed -n 's/^[[:space:]]*\(export[[:space:]]\{1,\}\)\{0,1\}\([A-Za-z_][A-Za-z0-9_]*\)=.*/\2/p'
}

# 값이 비었는지 판정. 따옴표만 있는 값("" '')도 빈 값으로 본다. 값은 출력하지 않는다.
value_empty() {
    # $1: 파일, $2: 키
    local raw
    raw="$(tr -d '\r' < "$1" \
        | sed -n "s/^[[:space:]]*\(export[[:space:]]\{1,\}\)\{0,1\}$2=//p" | head -1)"
    [ -z "$(printf '%s' "$raw" | tr -d "[:space:]\"'")" ]
}

EXAMPLES=()
while IFS= read -r example; do
    EXAMPLES[${#EXAMPLES[@]}]="$example"
done < <(git -C "$REPO_ROOT" ls-files -- '*.env.example' | sort)

if [ "${#EXAMPLES[@]}" -eq 0 ]; then
    echo "SKIP 추적 중인 .env.example 이 없다. 검사할 대상이 없다"
    exit 0
fi

echo "대상 쌍: ${#EXAMPLES[@]}개"

# ---------------------------------------------------------------- 키 중복

echo
echo "[1/3] 키 중복"
for ex in "${EXAMPLES[@]}"; do
    env_file="$(dirname "$ex")/.env"
    env_file="${env_file#./}"
    for f in "$ex" "$env_file"; do
        [ -f "$REPO_ROOT/$f" ] || continue
        dup="$(keys_of "$REPO_ROOT/$f" | sort | uniq -d | tr '\n' ' ')"
        if [ -n "${dup// /}" ]; then
            report FAIL "$f" "키 중복: $dup"
        else
            report PASS "$f"
        fi
    done
done

# ---------------------------------------------------------------- 키 집합 일치

echo
echo "[2/3] 키 집합 일치"
for ex in "${EXAMPLES[@]}"; do
    env_file="$(dirname "$ex")/.env"
    env_file="${env_file#./}"

    if [ ! -f "$REPO_ROOT/$env_file" ]; then
        if [ "$STRICT" -eq 1 ]; then
            report FAIL "$env_file" "없음. cp $ex $env_file 로 만든다"
        else
            report SKIP "$env_file" "없음 (cp $ex $env_file)"
        fi
        continue
    fi

    keys_of "$REPO_ROOT/$ex"       | sort -u > "$TMP_DIR/example.keys"
    keys_of "$REPO_ROOT/$env_file" | sort -u > "$TMP_DIR/env.keys"

    missing="$(comm -23 "$TMP_DIR/example.keys" "$TMP_DIR/env.keys" | tr '\n' ' ')"
    extra="$(comm -13 "$TMP_DIR/example.keys" "$TMP_DIR/env.keys" | tr '\n' ' ')"

    if [ -n "${missing// /}" ]; then
        report FAIL "$env_file" "$ex 에 있고 여기 없음: $missing"
    fi
    if [ -n "${extra// /}" ]; then
        report FAIL "$ex" "$env_file 에 있고 여기 없음: $extra"
    fi
    if [ -z "${missing// /}" ] && [ -z "${extra// /}" ]; then
        report PASS "$ex <-> $env_file" "키 $(wc -l < "$TMP_DIR/example.keys" | tr -d ' ')개 일치"
    fi
done

# ---------------------------------------------------------------- 비밀값 비움

echo
echo "[3/3] .env.example 비밀값 비움"
for ex in "${EXAMPLES[@]}"; do
    leaked=""
    while IFS= read -r key; do
        [ -n "$key" ] || continue
        printf '%s\n' "$key" | grep -qE "$SECRET_KEY_PATTERN" || continue
        value_empty "$REPO_ROOT/$ex" "$key" || leaked="$leaked $key"
    done < <(keys_of "$REPO_ROOT/$ex" | sort -u)

    if [ -n "${leaked// /}" ]; then
        report FAIL "$ex" "값이 채워진 비밀 키:$leaked"
    else
        report PASS "$ex"
    fi
done

echo
echo "결과: PASS $pass_count, FAIL $fail_count, SKIP $skip_count"

if [ "$fail_count" -gt 0 ]; then
    echo
    echo "키를 추가하면 .env 와 .env.example 양쪽에 넣는다. 규약: SECURITY.md" >&2
    exit 1
fi
exit 0
