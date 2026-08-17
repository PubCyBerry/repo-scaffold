#!/usr/bin/env bash
# AGENTS.md 의 문서 인덱스를 저장소 상태에서 다시 만든다.
#
# 알고리즘:
#   1. git index 에 있는 .md / .mdx 를 모은다 (커밋될 상태 = 인덱스)
#   2. 마지막 / 를 기준으로 디렉터리와 파일명을 분리해 디렉터리별로 묶는다
#   3. <directory>:{<file1>,<file2>,...} 형식으로 만들어 | 하나로 잇는다
#   4. AGENTS.md 의 마커 사이에 삽입한다
#
# 사용법:
#   bash scripts/gen-doc-index.sh            # 생성해서 AGENTS.md 에 반영
#   bash scripts/gen-doc-index.sh --stage    # 반영하고 바뀌었으면 git add. pre-commit 훅이 쓴다
#   bash scripts/gen-doc-index.sh --check    # 최신인지만 확인. 낡았으면 종료 코드 1
#   bash scripts/gen-doc-index.sh --print    # 표준 출력으로 인덱스만 출력
#
# gitignore 대상은 git ls-files 가 알아서 뺀다.
#
# 종료 코드: --check 가 낡음을 발견하거나 --stage 가 파일을 고쳤으면 1,
#            알 수 없는 옵션이면 2, 아니면 0

set -euo pipefail

# cd 뒤에는 상대 경로인 BASH_SOURCE 가 안 풀린다. --help 가 자기 파일을 읽으므로 먼저 절대 경로로 잡는다.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SELF="$SCRIPT_DIR/$(basename "${BASH_SOURCE[0]}")"

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

TARGET="AGENTS.md"
START='<!-- DOC-INDEX:START -->'
END='<!-- DOC-INDEX:END -->'
TITLE='[{{REPO_NAME}} Docs Index]'
NOTE='IMPORTANT: Prefer retrieval-led reasoning over pre-training-led reasoning for any tasks.'

MODE="write"
case "${1:-}" in
    --check) MODE="check" ;;
    --print) MODE="print" ;;
    --stage) MODE="stage" ;;
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

# --- 1. 대상 수집 -------------------------------------------------------------
# git ls-files 는 인덱스를 읽는다. 커밋될 상태를 그대로 반영한다.
#
# .agents/ 는 뺀다. 스킬 정의는 에이전트 런타임이 직접 읽으므로 인덱스에서 고를 대상이 아니다.
# .github/pull_request_template.md 도 뺀다. 읽을 문서가 아니라 GitHub 이 PR 본문에 붙이는
# 서식이고, 인덱스에 들어가면 에이전트가 읽을 문서로 착각한다.
# 다시 넣으려면 아래 제외 pathspec 을 지운다.
EXCLUDE=(':!.agents/*' ':!.github/pull_request_template.md')

FILES=()
while IFS= read -r f; do
    FILES[${#FILES[@]}]="$f"
done < <(git ls-files -- '*.md' '*.mdx' "${EXCLUDE[@]}" | sort)

if [ "${#FILES[@]}" -eq 0 ]; then
    echo "대상 문서가 없다" >&2
    exit 1
fi

# --- 2. 디렉터리별 그룹화 -----------------------------------------------------
parts=("$TITLE" "root: ." "$NOTE")
dir_count=0

while IFS= read -r group; do
    parts[${#parts[@]}]="$group"
    dir_count=$((dir_count + 1))
done < <(
    printf '%s\n' "${FILES[@]}" \
        | awk '{
            base = $0
            sub(/^.*\//, "", base)
            dir = $0
            if (dir == base) dir = "."
            else sub(/\/[^/]*$/, "", dir)
            print dir "\t" base
        }' \
        | sort \
        | awk -F '\t' '
            NR == 1 { dir = $1; files = $2; next }
            $1 != dir { print dir ":{" files "}"; dir = $1; files = $2; next }
            { files = files "," $2 }
            END { if (NR) print dir ":{" files "}" }
        '
)

# --- 3. 직렬화 ----------------------------------------------------------------
INDEX="$(
    printf '%s' "${parts[0]}"
    printf '|%s' "${parts[@]:1}"
)"

if [ "$MODE" = "print" ]; then
    printf '%s\n' "$INDEX"
    exit 0
fi

# --- 4. AGENTS.md 삽입 --------------------------------------------------------
if ! grep -qF "$START" "$TARGET" || ! grep -qF "$END" "$TARGET"; then
    echo "FAIL: $TARGET 에 마커가 없다. 다음 두 줄이 있어야 한다" >&2
    echo "  $START" >&2
    echo "  $END" >&2
    exit 1
fi

TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

INDEX_LINE="$INDEX" awk -v start="$START" -v end="$END" '
    BEGIN { index_line = ENVIRON["INDEX_LINE"] }
    # 마크다운 규칙상 코드 펜스는 앞뒤에 빈 줄이 있어야 하고 언어가 붙어야 한다.
    $0 == start { print; print ""; print "```text"; print index_line; print "```"; print ""; skip = 1; next }
    $0 == end   { skip = 0 }
    !skip       { print }
' "$TARGET" > "$TMP"

if cmp -s "$TARGET" "$TMP"; then
    [ "$MODE" = "check" ] || echo "문서 인덱스 최신 상태. 변경 없음"
    exit 0
fi

if [ "$MODE" = "check" ]; then
    echo "FAIL: 문서 인덱스가 저장소 상태와 다르다. bash scripts/gen-doc-index.sh 를 실행한다" >&2
    exit 1
fi

cat "$TMP" > "$TARGET"
echo "문서 인덱스 갱신: 디렉터리 ${dir_count}개, 문서 ${#FILES[@]}개"

if [ "$MODE" = "stage" ]; then
    git add "$TARGET"
    echo "$TARGET 를 스테이징했다. 커밋을 다시 실행한다"
    # pre-commit 프레임워크 규약대로 실패로 끝낸다. 커밋 내용이 바뀌었음을 사용자가 알아야 한다.
    exit 1
fi
