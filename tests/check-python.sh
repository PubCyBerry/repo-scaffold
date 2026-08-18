#!/usr/bin/env bash
# 파이썬 정적 분석, 형식, 타입 검사.
#
# 검사 단계. --only 로 고른다. 기본은 전부다.
#   lint    ruff check    정적 분석
#   format  ruff format   형식. 파일을 바꾸지 않고 어긋난 파일만 알린다
#   type    mypy          타입
#
# 대상은 추적 중인 *.py, *.pyi 전부다. 하나도 없으면 SKIP 하고 0 으로 끝난다.
# 이 스크립트는 언어 감지와 무관하게 항상 배치된다. 배치를 감지로 막으면
# "파이썬 없음" 이 깨끗한 SKIP 대신 매 커밋 No such file 훅 에러가 된다.
#
# pyproject.toml 과 uv.lock 과 uv 가 모두 있으면 uv run --frozen 으로 부른다.
# 그래야 훅과 CI 와 손으로 돌릴 때가 잠긴 같은 버전을 쓴다. 셋 중 하나라도 없으면
# PATH 에서 찾는다.
#
# 한도를 여기에 적지 않는다. 한도는 pyproject.toml 이 갖고 그 근거는
# docs/standards/code-quality.md 다. 이 스크립트는 실행과 집계만 한다.
#
# 도구가 없으면 로컬에서는 SKIP, CI(환경변수 CI=true)에서는 FAIL 이다.
# 로컬에서 커밋을 막으면 --no-verify 가 습관이 되므로 막지 않고, CI 에서 잡는다.
#
# 이 스크립트는 모든 검사를 돌려 결과를 모으므로 set -e 를 쓰지 않는다.
# 예외 근거는 docs/standards/shell.md 에 있다.
#
# 사용법:
#   bash tests/check-python.sh                    # 전체 검사
#   bash tests/check-python.sh --only lint        # 한 단계만
#   bash tests/check-python.sh --only lint,type   # 여러 단계
#
# 종료 코드: FAIL 이 하나라도 있으면 1, 알 수 없는 옵션이면 2, 아니면 0

set -uo pipefail

# cd 뒤에는 상대 경로인 BASH_SOURCE 가 안 풀린다. --help 가 자기 파일을 읽으므로 먼저 절대 경로로 잡는다.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SELF="$SCRIPT_DIR/$(basename "${BASH_SOURCE[0]}")"

ALL_PHASES="lint format type"
PHASES="$ALL_PHASES"

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
        *)
            echo "알 수 없는 옵션: $1" >&2
            exit 2
            ;;
    esac
done

# 스크립트 위치가 아니라 git 이 루트를 정한다. tests/ 를 옮겨도 따라온다.
REPO_ROOT="$(git rev-parse --show-toplevel 2> /dev/null)" || {
    echo "FAIL: git 저장소가 아니다" >&2
    exit 1
}
cd "$REPO_ROOT" || exit 1

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

# 잠긴 버전으로 도구를 부를 수 있으면 그렇게 한다. 훅과 CI 와 사람이 같은 버전을
# 쓰게 하는 유일한 방법이다. 셋 중 하나라도 없으면 PATH 로 물러선다.
# 빈 배열을 확장하면 set -u 에서 터지므로 PATH 쪽에는 무해한 command 를 둔다.
RUNNER=(command)
RUNNER_LABEL="PATH"
if [ -f pyproject.toml ] && [ -f uv.lock ] && command -v uv > /dev/null 2>&1; then
    RUNNER=(uv run --frozen)
    RUNNER_LABEL="uv run --frozen"
fi

# 도구가 있으면 0, 없으면 판정을 남기고 1. CI 에서는 없는 것이 FAIL 이다.
require_tool() {
    # $1: 명령
    "${RUNNER[@]}" "$1" --version > /dev/null 2>&1 && return 0
    if [ "${CI:-}" = "true" ]; then
        report FAIL "$1" "미설치. CI 에서는 필수다"
    else
        report SKIP "$1" "미설치"
    fi
    bash scripts/tool-help.sh "$1"
    return 1
}

FILES=()
while IFS= read -r f; do
    FILES[${#FILES[@]}]="$f"
done < <(git ls-files -- '*.py' '*.pyi' | sort)

if [ "${#FILES[@]}" -eq 0 ]; then
    echo "SKIP 추적 중인 파이썬 파일이 없다"
    exit 0
fi

echo "대상 파일: ${#FILES[@]}개"
echo "실행 경로: $RUNNER_LABEL"
if [ ! -f pyproject.toml ]; then
    echo "주의: pyproject.toml 이 없다. 도구가 기본 설정으로 돌아 code-quality.md 의 한도가 걸리지 않는다"
fi

# ---------------------------------------------------------------- 정적 분석

if phase_on lint; then
    banner "ruff check"
    if require_tool ruff; then
        if out="$("${RUNNER[@]}" ruff check --output-format=concise "${FILES[@]}" 2>&1)"; then
            report PASS "ruff check" "지적 없음"
        else
            printf '%s\n' "$out"
            report FAIL "ruff check" "자동으로 고칠 수 있는 것은 just fix 로 고친다"
        fi
    fi
fi

# ---------------------------------------------------------------- 형식

if phase_on format; then
    banner "ruff format"
    if require_tool ruff; then
        # --check 는 파일을 바꾸지 않는다. 고치는 것은 scripts/fmt.sh 의 일이다.
        # 훅이 파일을 몰래 고치면 커밋한 내용과 검사한 내용이 갈린다.
        if out="$("${RUNNER[@]}" ruff format --check "${FILES[@]}" 2>&1)"; then
            report PASS "ruff format" "형식 일치"
        else
            printf '%s\n' "$out"
            report FAIL "ruff format" "형식 불일치. just fmt 로 고친다"
        fi
    fi
fi

# ---------------------------------------------------------------- 타입

if phase_on type; then
    banner "mypy"
    if require_tool mypy; then
        # 같은 이름의 .py 와 .pyi 를 같이 넘기면 mypy 가 중복 모듈로 보고 죽는다.
        # 스텁이 있으면 mypy 가 알아서 그쪽을 먼저 읽으므로 짝이 있는 .pyi 는 뺀다.
        TYPE_FILES=()
        for f in "${FILES[@]}"; do
            case "$f" in
                *.pyi)
                    [ -f "${f%i}" ] && continue
                    ;;
            esac
            TYPE_FILES[${#TYPE_FILES[@]}]="$f"
        done

        if out="$("${RUNNER[@]}" mypy "${TYPE_FILES[@]}" 2>&1)"; then
            report PASS mypy "타입 지적 없음"
        else
            printf '%s\n' "$out"
            report FAIL mypy "이미 있는 코드에 처음 켜는 절차는 docs/standards/python.md 에 있다"
        fi
    fi
fi

echo
echo "결과: PASS $pass_count, FAIL $fail_count, SKIP $skip_count"

if [ "$fail_count" -gt 0 ]; then
    echo
    echo "규약: docs/standards/python.md" >&2
    exit 1
fi
exit 0
