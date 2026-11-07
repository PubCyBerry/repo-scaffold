#!/usr/bin/env bash
# PostToolUse 훅. 방금 고친 파일을 그 자리에서 검사한다.
#
# 규칙을 하나도 정의하지 않는다. 파일 확장자를 보고 tests/*.sh 를 부르는 것이 전부다.
# 규칙 하나에 검사기 하나이고, 그 검사기는 이미 커밋 훅과 CI 가 부르는 것과 같은 파일이다.
# 여기서 다시 구현하면 두 곳이 갈리고, 갈린 것을 아무도 보고하지 않는다. 근거는 ADR 0007 다.
#
# 이 훅이 바꾸는 것은 트리거뿐이다. 커밋 때 처음 알던 위반을 편집 직후에 안다.
# 문서 스무 편을 고치고 커밋에서 한 번에 스무 건을 받는 것과, 한 편마다 한 건을 받는 것은
# 고치는 비용이 다르다.
#
# 대상과 검사기:
#   docs/ 아래 .md   tests/check-docs.sh
#   모든 .md         tests/check-prose.sh
#   .sh .bash        tests/check-shell.sh
#   .py .pyi         tests/check-python.sh --only lint,format
#   워크플로 .yml     tests/check-workflows.sh
#
# rumdl 은 여기서 부르지 않는다. cross-file 앵커 검사가 저장소 전체 색인을 필요로 해서
# 파일 하나만 넘기면 조용히 미검사가 된다. 근거는 docs/standards/documentation.md 에 있다.
#
# Definition of Done 표시도 여기서 한다. 파일이 바뀌면 표시를 남기고, just verify 가
# 실패 없이 끝나면 지운다. 그 표시를 scripts/agent-hooks/stop.sh 가 본다.
#
# 규약: docs/standards/agent-harness.md
#
# 사용법:
#   echo '<payload>' | bash scripts/agent-hooks/post-tool-use.sh
#
# 종료 코드: 검사가 실패하면 2, 아니면 0

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SELF="$SCRIPT_DIR/$(basename "${BASH_SOURCE[0]}")"

case "${1:-}" in
    -h | --help)
        sed -n '2,/^$/p' "$SELF"
        exit 0
        ;;
esac

# shellcheck source=scripts/agent-hooks/lib.sh
. "$SCRIPT_DIR/lib.sh"

hook_read_payload
hook_cd_repo_root

MARKER_DIR="$(git rev-parse --git-dir)/agent-hooks"
MARKER="$MARKER_DIR/verify-pending"

# ---------------------------------------------------------------- 셸 이후

if hook_is_shell_tool; then
    # just verify 가 실패 없이 끝났으면 Definition of Done 표시를 지운다.
    if printf '%s' "$HOOK_COMMAND" | grep -Eq '(^|[;&]|&&)[[:space:]]*just[[:space:]]+verify([[:space:]]|$)'; then
        if [ -f "$MARKER" ] && ! printf '%s' "$HOOK_RESPONSE" | grep -q 'FAIL'; then
            rm -f "$MARKER"
        fi
    fi
    exit 0
fi

hook_is_edit_tool || exit 0

# ---------------------------------------------------------------- 편집 이후

mkdir -p "$MARKER_DIR"
: > "$MARKER"

status=0

run_check() {
    # $1: 사람이 읽을 이름, 나머지: 명령
    local label="$1"
    shift
    local out
    if out="$("$@" 2>&1)"; then
        return 0
    fi
    echo "검사 실패: $label" >&2
    printf '%s\n' "$out" >&2
    status=2
}

while IFS= read -r target; do
    [ -n "$target" ] || continue
    rel="${target#"$PWD"/}"
    [ -f "$rel" ] || continue

    case "$rel" in
        .github/workflows/*.yml | .github/workflows/*.yaml)
            run_check "$rel 워크플로" bash tests/check-workflows.sh
            continue
            ;;
    esac

    case "$rel" in
        docs/*.md | docs/*.mdx)
            run_check "$rel 문서 규약" bash tests/check-docs.sh --only title,placement,paths "$rel"
            ;;
    esac

    case "$rel" in
        *.md | *.mdx)
            run_check "$rel 산문" bash tests/check-prose.sh "$rel"
            ;;
        *.sh | *.bash)
            run_check "$rel 셸" bash tests/check-shell.sh "$rel"
            ;;
        *.py | *.pyi)
            run_check "$rel 파이썬" bash tests/check-python.sh --only format,lint "$rel"
            ;;
    esac
done <<< "$HOOK_FILES"

exit "$status"
