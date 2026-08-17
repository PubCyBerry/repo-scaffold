#!/usr/bin/env bash
# 개발 환경을 세운다. 클론마다 한 번 돌린다.
#
# 하는 일:
#   1. tools.txt 의 도구를 uv tool install 로 깐다
#   2. pyproject.toml 이 있으면 uv sync
#   3. package-lock.json 이 있으면 npm ci
#   4. prek 로 git 훅 세 종류를 깐다
#
# uv tool install 은 인자를 하나만 받으므로 한 줄씩 돈다. 같은 버전이 이미 있으면
# 넘어가고 다른 버전이 있으면 갈아끼운다. 여러 번 돌려도 결과가 같다.
#
# 이 스크립트는 모든 단계를 돌려 결과를 모으므로 set -e 를 쓰지 않는다.
# 예외 근거는 docs/standards/shell.md 에 있다.
#
# 사용법:
#   bash scripts/bootstrap.sh
#   bash scripts/bootstrap.sh --dry-run   # 설치하지 않고 계획만 출력한다
#
# 종료 코드: FAIL 이 하나라도 있으면 1, 알 수 없는 옵션이면 2, 아니면 0

set -uo pipefail

# cd 뒤에는 상대 경로인 BASH_SOURCE 가 안 풀린다. --help 가 자기 파일을 읽으므로 먼저 절대 경로로 잡는다.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SELF="$SCRIPT_DIR/$(basename "${BASH_SOURCE[0]}")"

DRY_RUN=0

case "${1:-}" in
    --dry-run) DRY_RUN=1 ;;
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

TOOLS_FILE="tools.txt"
HOOK_TYPES=(pre-commit commit-msg pre-push)

pass_count=0
fail_count=0
skip_count=0

report() {
    # $1: 판정, $2: 대상, $3: 사유
    case "$1" in
        PASS | PLAN) pass_count=$((pass_count + 1)) ;;
        FAIL) fail_count=$((fail_count + 1)) ;;
        SKIP) skip_count=$((skip_count + 1)) ;;
    esac
    printf '%-4s %-26s %s\n' "$1" "$2" "${3:-}"
}

# 명령을 돌린다. --dry-run 이면 계획만 남긴다.
run_step() {
    # $1: 대상 이름, $2...: 명령
    local name="$1" out
    shift
    if [ "$DRY_RUN" -eq 1 ]; then
        report PLAN "$name" "$*"
        return 0
    fi
    if out="$("$@" 2>&1)"; then
        report PASS "$name"
        return 0
    fi
    printf '%s\n' "$out"
    report FAIL "$name" "$* 실패"
    return 1
}

[ "$DRY_RUN" -eq 1 ] && echo "모드: dry-run. 아무것도 설치하지 않는다"

# --- 1. uv 도구 ---------------------------------------------------------------

echo "[1/4] uv 도구 (tools.txt)"

if [ ! -f "$TOOLS_FILE" ]; then
    report FAIL "$TOOLS_FILE" "없다. 도구 버전의 단일 출처다"
elif [ "$DRY_RUN" -eq 0 ] && ! command -v uv > /dev/null 2>&1; then
    report FAIL uv "미설치. 먼저 uv 를 깐다. https://docs.astral.sh/uv"
else
    while read -r spec source binary; do
        [ -n "$spec" ] || continue
        case "$spec" in \#*) continue ;; esac
        binary="${binary:-${spec%%==*}}"

        if [ "$source" != "uv" ]; then
            report SKIP "$binary" "출처 $source. 손으로 설치한다 ($spec)"
            continue
        fi
        run_step "$binary" uv tool install "$spec"
    done < "$TOOLS_FILE"
fi

# --- 2. Python 의존성 ---------------------------------------------------------

echo
echo "[2/4] Python 의존성"

if [ ! -f "pyproject.toml" ]; then
    report SKIP pyproject.toml "없다. 이 저장소는 Python 의존성을 쓰지 않는다"
elif [ "$DRY_RUN" -eq 0 ] && ! command -v uv > /dev/null 2>&1; then
    report FAIL uv "미설치. uv sync 를 돌릴 수 없다"
else
    run_step "uv sync" uv sync
fi

# --- 3. Node 의존성 -----------------------------------------------------------

echo
echo "[3/4] Node 의존성"

if [ ! -f "package-lock.json" ]; then
    report SKIP package-lock.json "없다. 이 저장소는 Node 의존성을 쓰지 않는다"
elif ! command -v npm > /dev/null 2>&1; then
    report SKIP npm "미설치. Node 를 쓰는 훅은 로컬에서 SKIP 되고 CI 에서 FAIL 이다"
else
    run_step "npm ci" npm ci
fi

# --- 4. git 훅 ----------------------------------------------------------------

echo
echo "[4/4] git 훅"

if [ ! -f ".pre-commit-config.yaml" ]; then
    report FAIL .pre-commit-config.yaml "없다. 깔 훅이 정의되지 않았다"
elif [ "$DRY_RUN" -eq 0 ] && ! command -v prek > /dev/null 2>&1; then
    # dry-run 이면 여기서 막지 않는다. 실제 실행이었다면 [1/4] 가 prek 를 먼저 깐다.
    report FAIL prek "미설치. 훅을 깔 수 없다. 설치: uv tool install prek"
else
    INSTALL_ARGS=(install)
    for hook in "${HOOK_TYPES[@]}"; do
        INSTALL_ARGS[${#INSTALL_ARGS[@]}]="--hook-type"
        INSTALL_ARGS[${#INSTALL_ARGS[@]}]="$hook"
    done
    if ! run_step "prek install" prek "${INSTALL_ARGS[@]}"; then
        echo
        echo "전역 core.hooksPath 때문에 거부됐다면 그 확인만 우회한다. 전역 설정은 바뀌지 않는다:" >&2
        echo "  GIT_CONFIG_GLOBAL=/dev/null prek ${INSTALL_ARGS[*]}" >&2
    fi
fi

echo
if [ "$DRY_RUN" -eq 1 ]; then
    echo "결과: PLAN $pass_count, FAIL $fail_count, SKIP $skip_count"
    echo "실제로 설치하려면 --dry-run 을 뺀다"
else
    echo "결과: PASS $pass_count, FAIL $fail_count, SKIP $skip_count"
fi

if [ "$fail_count" -gt 0 ]; then
    exit 1
fi

if [ "$DRY_RUN" -eq 0 ]; then
    echo
    echo "다음: bash scripts/doctor.sh 로 확인하고 just verify 를 돌린다"
fi
exit 0
