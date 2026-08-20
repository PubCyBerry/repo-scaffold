#!/usr/bin/env bash
# 에이전트 하네스 훅이 함께 쓰는 페이로드 정규화 계층.
#
# Claude Code 와 Codex 는 같은 모양의 lifecycle 훅을 제공한다. 이벤트 이름, stdin JSON,
# exit 2 차단, hookSpecificOutput 이 같다. 다른 것은 도구 이름뿐이다.
#
#   파일 편집   Claude: Edit, Write, MultiEdit, NotebookEdit   Codex: apply_patch
#   셸         Claude: Bash                                    Codex: Bash
#
# 그 차이를 여기서 흡수한다. 훅 본체는 아래 변수만 보고 어느 에이전트인지 모른다.
# 두 에이전트에 규칙을 각각 구현하면 한쪽만 고쳤을 때 조용히 갈린다.
#
#   HOOK_EVENT       hook_event_name
#   HOOK_TOOL        tool_name
#   HOOK_COMMAND     셸 명령. 셸 도구가 아니면 빈 문자열
#   HOOK_FILES       편집 대상 경로. 줄 하나에 하나. 없으면 빈 문자열
#   HOOK_TEXT        편집 페이로드 전체. 키를 못 찾으면 tool_input 전체 JSON
#   HOOK_OLD         편집 전 내용. 알 수 없으면 빈 문자열
#   HOOK_NEW         편집 후 내용. 알 수 없으면 빈 문자열
#   HOOK_RESPONSE    tool_response 를 문자열로 편 것. PostToolUse 에서만 채워진다
#   HOOK_CWD         cwd
#   HOOK_TRANSCRIPT  transcript_path
#   HOOK_STOP_ACTIVE stop_hook_active. true 면 이미 훅이 한 번 막은 뒤다
#
# HOOK_TEXT 가 tool_input 전체로 떨어지는 것은 의도한 안전판이다. 모르는 키 이름 때문에
# 검사가 조용히 아무것도 안 보는 것보다, 넓게 보고 오탐을 감수하는 쪽이 낫다.
#
# jq 가 없으면 훅은 아무것도 하지 않고 통과시킨다. 훅이 항상 도는 것과 훅이 항상
# 동작하는 것은 다르고, 도구가 없는 기계에서 에이전트를 세우면 훅 자체가 꺼진다.
# 같은 처리를 tests/check-commit-msg.sh 가 commitlint 에 하고 있다.
#
# 이 파일은 단독으로 실행하지 않는다. source 로만 쓴다.

# shellcheck shell=bash

HOOK_EVENT=""
HOOK_TOOL=""
HOOK_COMMAND=""
HOOK_FILES=""
HOOK_TEXT=""
HOOK_OLD=""
HOOK_NEW=""
HOOK_RESPONSE=""
HOOK_CWD=""
HOOK_TRANSCRIPT=""
HOOK_STOP_ACTIVE="false"

# 훅을 조용히 통과시킨다. 차단할 근거가 없을 때의 유일한 종료 경로다.
hook_allow() {
    exit 0
}

# 모델에게 사유를 보이고 도구 호출을 막는다. exit 2 가 두 에이전트 공통의 차단 신호다.
hook_deny() {
    # $1: 무엇을 막았는지, $2: 대신 할 것
    echo "차단: $1" >&2
    if [ -n "${2:-}" ]; then
        echo "대신: $2" >&2
    fi
    exit 2
}

# HOOK_ 변수는 이 파일이 채우고 source 로 받은 훅이 읽는다. 이 파일 안에서 읽는 곳은 없다.
# shellcheck disable=SC2034
# stdin 의 JSON 을 읽어 위 변수를 채운다. jq 가 없으면 그대로 통과시킨다.
hook_read_payload() {
    command -v jq > /dev/null 2>&1 || hook_allow

    local payload
    payload="$(cat)"
    [ -n "$payload" ] || hook_allow

    HOOK_EVENT="$(printf '%s' "$payload" | jq -r '.hook_event_name // ""')"
    HOOK_TOOL="$(printf '%s' "$payload" | jq -r '.tool_name // ""')"
    HOOK_RESPONSE="$(printf '%s' "$payload" | jq -r '.tool_response // "" | if type == "string" then . else tostring end')"
    HOOK_CWD="$(printf '%s' "$payload" | jq -r '.cwd // ""')"
    HOOK_TRANSCRIPT="$(printf '%s' "$payload" | jq -r '.transcript_path // ""')"
    HOOK_STOP_ACTIVE="$(printf '%s' "$payload" | jq -r '.stop_hook_active // false')"
    HOOK_COMMAND="$(printf '%s' "$payload" | jq -r '.tool_input.command // ""')"

    # 편집 페이로드. Claude 의 Write 와 Edit, Codex 의 apply_patch 가 키가 다르다.
    # 어느 것도 아니면 tool_input 을 통째로 문자열로 본다.
    HOOK_TEXT="$(printf '%s' "$payload" | jq -r '
        .tool_input // {}
        | if type != "object" then tostring
          elif has("input") then .input
          elif has("patch") then .patch
          elif has("content") then .content
          elif has("new_string") then ((.old_string // "") + "\n" + .new_string)
          elif has("edits") then ([.edits[]? | (.old_string // "") + "\n" + (.new_string // "")] | join("\n"))
          elif has("new_source") then .new_source
          else tostring
          end
    ')"

    HOOK_OLD="$(printf '%s' "$payload" | jq -r '.tool_input.old_string // .tool_input.old_source // ""')"

    HOOK_NEW="$(printf '%s' "$payload" | jq -r '
        .tool_input // {}
        | if type != "object" then ""
          elif has("new_string") then .new_string
          elif has("new_source") then .new_source
          elif has("content") then .content
          elif has("edits") then ([.edits[]? | .new_string // ""] | join("\n"))
          else ""
          end
    ')"

    HOOK_FILES="$(printf '%s' "$payload" | jq -r '.tool_input.file_path // .tool_input.notebook_path // ""')"

    # Codex 의 apply_patch 는 경로가 패치 본문 안에 있다.
    if [ -z "$HOOK_FILES" ] && [ -n "$HOOK_TEXT" ]; then
        HOOK_FILES="$(printf '%s\n' "$HOOK_TEXT" \
            | sed -n 's/^\*\*\* \(Add\|Update\|Delete\) File: //p' \
            | sed 's/[[:space:]]*$//')"
    fi
}

# 셸 도구인가. 두 에이전트 모두 Bash 다.
hook_is_shell_tool() {
    case "$HOOK_TOOL" in
        Bash | bash | shell) return 0 ;;
        *) return 1 ;;
    esac
}

# 파일을 쓰는 도구인가.
hook_is_edit_tool() {
    case "$HOOK_TOOL" in
        Edit | Write | MultiEdit | NotebookEdit | apply_patch) return 0 ;;
        *) return 1 ;;
    esac
}

# 패치 형식 페이로드인가. Codex 의 apply_patch 가 이 모양이다.
hook_is_patch_payload() {
    printf '%s\n' "$HOOK_TEXT" | grep -q '^\*\*\* \(Add\|Update\|Delete\) File: '
}

# 이번 편집으로 새로 들어가는 줄만 낸다. 규칙은 대부분 추가된 내용에만 걸린다.
# 원래 그 줄을 갖고 있던 파일을 다른 이유로 고칠 때 훅이 막으면 오탐이고,
# 오탐 한 번이 하네스 전체를 끄게 만든다.
#
# 판정 근거는 셋이다. 앞의 것부터 쓴다.
#   1. 패치 본문의 + 줄         Codex 의 apply_patch
#   2. new_string 에만 있는 줄   Claude 의 Edit
#   3. 디스크의 파일에 없는 줄    Claude 의 Write
hook_added_lines() {
    # $1: 편집 대상 경로. 없어도 된다
    local target="${1:-}"

    if hook_is_patch_payload; then
        printf '%s\n' "$HOOK_TEXT" | sed -n 's/^+//p'
        return 0
    fi

    if [ -n "$HOOK_OLD" ]; then
        printf '%s\n' "$HOOK_OLD" > "$HOOK_TMP/old"
        printf '%s\n' "$HOOK_NEW" | grep -Fxv -f "$HOOK_TMP/old" || true
        return 0
    fi

    if [ -n "$HOOK_NEW" ] && [ -n "$target" ] && [ -f "$target" ]; then
        printf '%s\n' "$HOOK_NEW" | grep -Fxv -f "$target" || true
        return 0
    fi

    printf '%s\n' "${HOOK_NEW:-$HOOK_TEXT}"
}

# 훅이 쓰는 임시 디렉터리. 종료할 때 지운다.
HOOK_TMP="$(mktemp -d)"
trap 'rm -rf "$HOOK_TMP"' EXIT

# 저장소 루트로 옮긴다. 저장소 밖이면 검사할 규칙이 없으므로 통과시킨다.
hook_cd_repo_root() {
    local root
    root="$(git rev-parse --show-toplevel 2> /dev/null)" || hook_allow
    cd "$root" || hook_allow
}
