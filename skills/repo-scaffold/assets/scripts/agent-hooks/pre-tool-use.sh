#!/usr/bin/env bash
# PreToolUse 훅. 도구 호출을 실행 전에 막는다.
#
# 여기 있는 규칙은 커밋 산출물을 봐서는 잡히지 않는 것들뿐이다. 어떤 도구를 골랐는지,
# 어떤 게이트를 껐는지는 diff 에 남지 않는다. prek 훅과 CI 는 이 규칙을 볼 수 없다.
#
# 이미 검사기가 있는 규칙은 여기서 다시 구현하지 않는다. 그쪽은 scripts/agent-hooks/
# post-tool-use.sh 가 tests/*.sh 를 부르는 것으로 끝낸다. 규칙 하나에 검사기 하나라는
# 계약은 ADR 0007 에 있고, 이 파일은 그 계약의 반대쪽이다. 여기서만 정의되는 규칙이다.
#
# 검사하는 것:
#   셸       재귀 grep 과 find, --no-verify, 기본 브랜치 push, force push,
#            uv 아닌 파이썬 환경 관리자, .env 값 출력
#   파일     last_reviewed 자동 갱신, docs/generated/ 손편집, edit_policy: generated,
#            AGENTS.md 의 생성 구간
#
# 오탐 하나가 하네스 전체를 끈다. --no-verify 가 습관이 되는 것과 같은 실패 모드다.
# 그래서 규칙은 전부 좁게 잡았다. 파이프 뒤의 grep 은 막지 않는다. 코드 탐색이 아니라
# 출력 거르기이고, 그것까지 막으면 하루에 열 번씩 걸린다.
#
# 규약: docs/standards/agent-harness.md
#
# 사용법:
#   echo '<payload>' | bash scripts/agent-hooks/pre-tool-use.sh
#
# 종료 코드: 차단이면 2, 아니면 0

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

# 명령 문자열이 정규식에 걸리는가.
cmd_has() {
    # $1: 확장 정규식
    printf '%s' "$HOOK_COMMAND" | grep -Eq "$1"
}

# 명령의 첫 자리에 오는 이름인가. 파이프와 세미콜론 뒤도 첫 자리로 친다.
cmd_starts_with() {
    # $1: 명령 이름 정규식
    printf '%s' "$HOOK_COMMAND" | grep -Eq "(^|[;&|(]|&&|\|\|)[[:space:]]*($1)[[:space:]]"
}

default_branch() {
    local ref
    if ref="$(git symbolic-ref --short refs/remotes/origin/HEAD 2> /dev/null)"; then
        printf '%s' "${ref#origin/}"
        return 0
    fi
    printf 'main'
}

# ---------------------------------------------------------------- 셸 규칙

if hook_is_shell_tool && [ -n "$HOOK_COMMAND" ]; then

    # 코드 탐색 도구. 재귀 검색만 본다. 파이프 뒤에서 출력을 거르는 grep 은 대상이 아니다.
    if cmd_starts_with 'grep|egrep|fgrep' \
        && cmd_has '(^|[[:space:]])(-[a-zA-Z]*[rR][a-zA-Z]*|--recursive|--include|--exclude-dir)([[:space:]=]|$)'; then
        hook_deny "재귀 grep. 저장소 탐색은 rg 가 한다" \
            "rg -n 'pattern'. 구조를 찾으면 ast-grep --pattern"
    fi

    if cmd_starts_with 'find' \
        && cmd_has '(^|[[:space:]])-(name|iname|path|ipath|type)([[:space:]]|$)'; then
        hook_deny "find 로 파일을 찾는다" \
            "fd 'pattern'. 확장자면 fd --extension py"
    fi

    # 커밋 게이트. 이것 하나로 훅 전체가 꺼진다.
    if cmd_has '(^|[[:space:]])--no-verify([[:space:]]|$)'; then
        hook_deny "--no-verify 는 훅 전체를 끈다" \
            "검사를 통과시킨다. 도구가 없으면 just doctor 가 무엇이 없는지 말한다"
    fi

    if cmd_has '(^|[[:space:]])git[[:space:]]+commit([[:space:]]|$)' \
        && cmd_has '(^|[[:space:]])-n([[:space:]]|$)'; then
        hook_deny "git commit -n 은 --no-verify 와 같다" \
            "검사를 통과시킨다"
    fi

    # push 정책.
    if cmd_has '(^|[;&|]|&&)[[:space:]]*git[[:space:]]+push([[:space:]]|$)'; then
        if cmd_has '(^|[[:space:]])(--force|-f)([[:space:]]|$)'; then
            hook_deny "force push 는 리뷰가 읽은 커밋을 지운다" \
                "--force-with-lease 를 쓴다. 리뷰가 시작된 뒤라면 후속 커밋을 쌓는다"
        fi

        current="$(git symbolic-ref --short HEAD 2> /dev/null || printf '')"
        default="$(default_branch)"
        if [ -n "$current" ] && [ "$current" = "$default" ]; then
            hook_deny "기본 브랜치에서 직접 push 한다: $default" \
                "git switch -c <branch> 로 갈라서 PR 을 연다"
        fi
        if cmd_has "(^|[[:space:]])(HEAD:)?(refs/heads/)?$default([[:space:]]|$)"; then
            hook_deny "기본 브랜치를 직접 밀고 있다: $default" \
                "브랜치를 갈라서 PR 을 연다"
        fi
    fi

    # 파이썬 환경 관리자. uv 만 쓴다. uv 를 앞에 둔 호출은 대상이 아니다.
    SAFE_COMMAND="$(printf '%s' "$HOOK_COMMAND" \
        | sed -E 's/(^|[^[:alnum:]_-])uv[[:space:]]+(pip|run|tool|sync|add|remove|lock|venv|python)/\1uvok /g')"
    if printf '%s' "$SAFE_COMMAND" \
        | grep -Eq '(^|[;&|(]|&&)[[:space:]]*(pip[0-9]*[[:space:]]+install|python[0-9.]*[[:space:]]+-m[[:space:]]+(pip|venv)|virtualenv|poetry|pipenv|conda)([[:space:]]|$)'; then
        hook_deny "uv 가 아닌 환경 관리자를 부른다" \
            "uv add, uv sync, uv run. 도구 설치는 uv tool install"
    fi

    # 자격 증명. .env 값은 화면에도 로그에도 남기지 않는다.
    if cmd_has '(^|[;&|(]|&&)[[:space:]]*(cat|less|more|head|tail|bat|strings|xxd|od)[[:space:]]+[^|;&]*\.env([[:space:]]|$)' \
        && ! cmd_has '\.env\.example'; then
        hook_deny ".env 값을 출력한다" \
            "키 이름만 필요하면 bash tests/check-env.sh 가 값 없이 대조한다"
    fi
fi

# ---------------------------------------------------------------- 편집 규칙

if hook_is_edit_tool; then
    while IFS= read -r target; do
        [ -n "$target" ] || continue
        rel="${target#"$PWD"/}"

        case "$rel" in
            docs/generated/* | */docs/generated/*)
                hook_deny "$rel 은 생성 산출물이다" \
                    "원본을 고치고 생성기를 다시 돌린다. 원본은 front matter 의 generated_from 에 있다"
                ;;
        esac

        if [ -f "$rel" ] && head -n 30 "$rel" | grep -q '^edit_policy:[[:space:]]*generated'; then
            hook_deny "$rel 은 edit_policy: generated 다" \
                "손으로 고치지 않는다. 생성기를 다시 돌린다"
        fi

        added="$(hook_added_lines "$rel")"

        if printf '%s\n' "$added" | grep -q '^[[:space:]]*last_reviewed:'; then
            hook_deny "last_reviewed 를 도구가 올린다" \
                "그 값은 사람이 문서를 다시 읽었다는 뜻이다. 사람이 손으로 올린다"
        fi

        case "$rel" in
            *AGENTS.md)
                if printf '%s\n' "$added" | grep -q 'DOC-INDEX:\(START\|END\)\|Docs Index\]|root:'; then
                    hook_deny "AGENTS.md 의 문서 인덱스 구간을 손으로 고친다" \
                        "그 구간은 커밋 직전에 scripts/gen-doc-index.sh 가 통째로 다시 쓴다"
                fi
                ;;
        esac
    done <<< "$HOOK_FILES"
fi

exit 0
