#!/usr/bin/env bash
# Stop 훅. 턴을 끝내려는 순간에 두 가지를 본다.
#
#   1. Definition of Done   파일을 고쳤는데 just verify 가 통과한 적이 없다
#   2. 답변의 표기 규칙      이번 턴 답변에 금칙 문자가 있다
#
# 2번이 여기 있는 이유는 커밋 훅이 그 산출물을 볼 수 없어서다.
# docs/standards/writing-style.md 의 scope 에는 에이전트가 만든 보고서와 채팅 답변이
# 들어 있는데, Vale 은 마크다운 파일만 읽는다. 파일로 남지 않는 산출물에는 커버리지가
# 없다. 답변을 볼 수 있는 자리는 이 훅뿐이다.
#
# 문자 규칙만 본다. Vale 의 Project.Punctuation 과 같은 다섯 항목이다. 어조와 표현은
# 여기서 보지 않는다. 정규식으로 어조를 판정하면 오탐이 나고, 오탐 한 번이 하네스
# 전체를 끈다. 같은 판단을 tests/check-commit-msg.sh 가 본문에 대해 내리고 있다.
#
# 코드 블록과 인라인 코드는 뺀다. 명령과 도구 출력은 그대로 옮기는 것이 규칙이다.
#
# 이번 턴만 본다. 마지막 사용자 메시지 뒤의 답변만 읽는다. 이전 턴 답변까지 보면
# 이미 지나간 문장 때문에 매 턴 막힌다.
#
# stop_hook_active 가 true 면 이미 한 번 막은 뒤다. 그때는 통과시킨다. 그러지 않으면
# 같은 지적으로 무한히 막힌다.
#
# 규약: docs/standards/agent-harness.md
#
# 사용법:
#   echo '<payload>' | bash scripts/agent-hooks/stop.sh
#
# 종료 코드: 막으면 2, 아니면 0

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

if [ "$HOOK_STOP_ACTIVE" = "true" ]; then
    exit 0
fi

MARKER="$(git rev-parse --git-dir)/agent-hooks/verify-pending"

findings=""

# ---------------------------------------------------------------- 표기 규칙

# 이번 턴의 답변만 뽑는다. 형식이 다르면 아무것도 안 나오고 검사는 조용히 건너뛴다.
if [ -n "$HOOK_TRANSCRIPT" ] && [ -f "$HOOK_TRANSCRIPT" ]; then
    jq -s -r '
        (map(.type? // "") | rindex("user")) as $i
        | (if $i == null then . else .[$i + 1:] end)
        | map(select((.type? // "") == "assistant"))
        | [.. | objects | select((.type? // "") == "text") | .text? // empty]
        | .[]
    ' "$HOOK_TRANSCRIPT" > "$HOOK_TMP/answers" 2> /dev/null || : > "$HOOK_TMP/answers"

    # 코드 블록과 인라인 코드를 뺀다.
    awk '
        /^[[:space:]]*```/ { fence = !fence; next }
        !fence { gsub(/`[^`]*`/, ""); print }
    ' "$HOOK_TMP/answers" > "$HOOK_TMP/prose" 2> /dev/null || : > "$HOOK_TMP/prose"

    if [ -s "$HOOK_TMP/prose" ]; then
        hits="$(grep -n -e '·' -e '—' -e '–' -e '〃' -e ' -- ' "$HOOK_TMP/prose" | head -5 || true)"
        if [ -n "$hits" ]; then
            findings="$findings답변에 금칙 문자가 있다. 가운뎃점은 쉼표나 '와', 줄표와 두 줄표는 콜론으로 바꾼다\n$hits\n"
        fi
    fi
fi

# ---------------------------------------------------------------- 완료 정의

if [ -f "$MARKER" ]; then
    findings="$findings파일을 고친 뒤 just verify 가 통과한 적이 없다. 그것이 Definition of Done 이다\n"
fi

if [ -n "$findings" ]; then
    printf '%b' "$findings" >&2
    exit 2
fi

exit 0
