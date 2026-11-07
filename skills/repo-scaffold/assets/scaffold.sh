#!/usr/bin/env bash
# 대상 저장소에 에이전트용 문서 체계를 깐다. 파일을 복사할 뿐이고 기존 파일은 덮어쓰지 않는다.
#
#   bash scaffold.sh [--dry-run] [--forge github|gitlab] [--init] TARGET
#
#   TARGET      대상 저장소 루트
#   --dry-run   쓰지 않고 계획만 출력한다
#   --forge     PR/MR 템플릿, 이슈 템플릿, CI 의 형식. 생략하면 origin 주소에 gitlab 이
#               들어 있을 때 gitlab, 아니면 github 다. Gitea 와 Forgejo 는 github 형식을 읽는다
#   --init      TARGET 이 git 저장소가 아니면 git init 한다
#
# 판정: ADD 만들었다 / PLAN 만들 예정이다 / SKIP 이미 있다 / NOTE 손으로 할 일이 있다 / FAIL 실패
# 종료 코드: FAIL 이 있으면 1, 사용법이 틀렸으면 2

set -uo pipefail

ASSETS="$(cd "$(dirname "$0")" && pwd)"
USAGE="사용법: bash scaffold.sh [--dry-run] [--forge github|gitlab] [--init] TARGET"
TARGET=""
FORGE=""
DRY_RUN=0
INIT=0

while [ $# -gt 0 ]; do
    case "$1" in
        --dry-run) DRY_RUN=1 ;;
        --init) INIT=1 ;;
        --forge)
            [ $# -ge 2 ] || {
                echo "$USAGE" >&2
                exit 2
            }
            FORGE="$2"
            shift
            ;;
        -h | --help)
            sed -n '2,/^$/s/^# \{0,1\}//p' "$0"
            exit 0
            ;;
        -*)
            echo "알 수 없는 옵션: $1" >&2
            echo "$USAGE" >&2
            exit 2
            ;;
        *) TARGET="$1" ;;
    esac
    shift
done

case "$FORGE" in
    "" | github | gitlab) ;;
    *)
        echo "--forge 는 github 또는 gitlab 이다: $FORGE" >&2
        exit 2
        ;;
esac
[ -n "$TARGET" ] || {
    echo "$USAGE" >&2
    exit 2
}
[ -d "$TARGET" ] || {
    echo "FAIL: 디렉터리가 없다: $TARGET" >&2
    exit 2
}
TARGET="$(cd "$TARGET" && pwd -P)"

adds=0 skips=0 notes=0 fails=0
report() {
    case "$1" in
        ADD | PLAN) adds=$((adds + 1)) ;;
        SKIP) skips=$((skips + 1)) ;;
        NOTE) notes=$((notes + 1)) ;;
        FAIL) fails=$((fails + 1)) ;;
    esac
    printf '%-4s %s\n' "$1" "$2"
    [ -z "${3:-}" ] || printf '     %s\n' "$3"
}

# --- git 저장소 ----------------------------------------------------------------

if prefix="$(git -C "$TARGET" rev-parse --show-prefix 2> /dev/null)"; then
    if [ -n "$prefix" ]; then
        echo "FAIL: 저장소 루트가 아니다: $TARGET" >&2
        exit 2
    fi
elif [ "$INIT" -eq 0 ]; then
    echo "FAIL: git 저장소가 아니다: $TARGET (새로 만들려면 --init)" >&2
    exit 1
elif [ "$DRY_RUN" -eq 1 ]; then
    report PLAN "git init"
elif git -C "$TARGET" init -q; then
    report ADD "git init"
else
    echo "FAIL: git init 에 실패했다: $TARGET" >&2
    exit 1
fi

if [ -z "$FORGE" ]; then
    case "$(git -C "$TARGET" remote get-url origin 2> /dev/null)" in
        *gitlab*) FORGE=gitlab ;;
        *) FORGE=github ;;
    esac
fi
echo "대상: $TARGET"
echo "forge: $FORGE"

# --- 배치 도구 ------------------------------------------------------------------

# 대상 밖에 쓰지 않는다. 경로 중간이나 끝이 심링크면 따라가지 않는다.
through_symlink() {
    local path="$TARGET" part IFS=/
    for part in $1; do
        path="$path/$part"
        [ -L "$path" ] && return 0
    done
    return 1
}

# place SRC DEST [FILTER]: SRC 는 assets 기준, DEST 는 대상 저장소 기준 경로다.
# 새로 만들었을 때만 0 을 돌려준다.
place() {
    local src="$ASSETS/$1" rel="$2" filter="${3:-cat}" dest="$TARGET/$2"
    if through_symlink "$rel"; then
        report FAIL "$rel" "경로에 심링크가 있어 쓰지 않았다"
        return 1
    fi
    if [ -e "$dest" ]; then
        report SKIP "$rel"
        return 1
    fi
    if [ ! -f "$src" ]; then
        report FAIL "$rel" "원본이 없다: $src"
        return 1
    fi
    if [ "$DRY_RUN" -eq 1 ]; then
        report PLAN "$rel"
        return 1
    fi
    # set -C(noclobber): 검사한 뒤에 다른 곳에서 만든 파일도 덮어쓰지 않는다.
    if mkdir -p "$(dirname "$dest")" && (set -C && "$filter" "$src" > "$dest") 2> /dev/null; then
        report ADD "$rel"
        return 0
    fi
    report FAIL "$rel" "쓰지 못했다"
    return 1
}

# 이미 있으면 사람이 합쳐야 하는 설정 파일. 필요한 내용이 이미 들어 있으면 SKIP 이다.
# place_or_note SRC DEST NEEDLE
place_or_note() {
    if [ -f "$TARGET/$2" ] && ! through_symlink "$2"; then
        if grep -qF -- "$3" "$TARGET/$2"; then
            report SKIP "$2"
        else
            report NOTE "$2" "이미 있다. $ASSETS/$1 의 내용을 손으로 합친다"
        fi
        return
    fi
    place "$1" "$2"
}

# 템플릿 디렉터리에 이 스크립트가 깔지 않은 파일이 있으면 겹치는지 사람이 본다.
# note_foreign DIR OWN_NAMES_REGEX
note_foreign() {
    local f
    for f in "$TARGET/$1"/*; do
        [ -e "$f" ] || continue
        if ! printf '%s\n' "${f##*/}" | grep -qxE "$2"; then
            report NOTE "$1" "기존 템플릿이 있다. 같은 용도의 템플릿이 겹치지 않게 정리한다"
            return
        fi
    done
}

# GitLab 은 이슈 템플릿의 front matter 를 읽지 않는다. 지우고 labels 를 /label 빠른 동작으로 옮긴다.
gitlab_template() {
    awk '
        NR == 1 && $0 == "---" { fm = 1; next }
        fm && $0 == "---" { fm = 0; drop_blank = 1; next }
        fm {
            if (sub(/^labels:[ \t]*/, "")) {
                gsub(/"/, ""); gsub(/\[/, ""); gsub(/\]/, ""); gsub(/ /, "")
                n = split($0, l, ",")
                for (i = 1; i <= n; i++) labels = labels " ~" l[i]
            }
            next
        }
        drop_blank && $0 == "" { drop_blank = 0; next }
        { drop_blank = 0; print }
        END { if (labels != "") printf "\n/label%s\n", labels }
    ' "$1"
}

# --- 문서와 검사 -----------------------------------------------------------------

echo
echo "[문서와 검사]"
first_run=1
[ -e "$TARGET/scripts/doc-index.sh" ] && first_run=0
had_docs="$(find "$TARGET/docs" -name '*.md' 2> /dev/null | head -n 1)"
agents_without_markers=0
if [ -f "$TARGET/AGENTS.md" ] && ! grep -qF '<!-- DOC-INDEX:START -->' "$TARGET/AGENTS.md"; then
    agents_without_markers=1
fi

place AGENTS.md AGENTS.md
while IFS= read -r f; do
    place "$f" "$f"
done < <(cd "$ASSETS" && find docs scripts -type f | LC_ALL=C sort)
place_or_note gitattributes .gitattributes '.githooks/* text eol=lf'

if place githooks/pre-commit .githooks/pre-commit; then
    chmod +x "$TARGET/.githooks/pre-commit"
    # Windows 는 실행 비트를 기록하지 못한다. 인덱스에 남겨야 다른 운영체제의 클론에서도 훅이 돈다.
    git -C "$TARGET" add --chmod=+x -- .githooks/pre-commit \
        && printf '     %s\n' "실행 비트를 기록하려고 이 파일을 스테이징했다"
fi

hooks_path="$(git -C "$TARGET" config --get core.hooksPath 2> /dev/null)"
if [ "$hooks_path" = .githooks ]; then
    report SKIP "core.hooksPath=.githooks"
elif [ -n "$hooks_path" ] || [ -e "$TARGET/.pre-commit-config.yaml" ] || [ -e "$TARGET/.husky" ] \
    || [ -e "$TARGET/lefthook.yml" ] \
    || (cd "$TARGET" && [ -e "$(git rev-parse --git-path hooks/pre-commit 2> /dev/null)" ]); then
    report NOTE "core.hooksPath" "다른 훅 설정이 있어 바꾸지 않았다. 그쪽 pre-commit 에서 bash .githooks/pre-commit 을 부른다"
elif [ "$DRY_RUN" -eq 1 ]; then
    report PLAN "core.hooksPath=.githooks"
elif git -C "$TARGET" config core.hooksPath .githooks; then
    report ADD "core.hooksPath=.githooks"
else
    report FAIL "core.hooksPath" "git config 에 실패했다"
fi

if [ "$agents_without_markers" -eq 1 ]; then
    report NOTE "AGENTS.md" "인덱스 자리가 없다. $ASSETS/AGENTS.md 의 문서 절과 규칙 절을 합치고 bash scripts/doc-index.sh 를 실행한다"
fi
if [ -e "$TARGET/CLAUDE.md" ]; then
    report NOTE "CLAUDE.md" "Claude Code 는 CLAUDE.md 가 없을 때만 AGENTS.md 를 읽는다. 내용을 AGENTS.md 로 옮기고 CLAUDE.md 를 지운다"
fi
if [ -n "$had_docs" ] && [ "$first_run" -eq 1 ]; then
    report NOTE "docs/" "기존 문서가 있다. front matter(type, title, description)를 넣고 bash scripts/doc-index.sh 를 실행한다"
fi

# --- 원격 저장소 템플릿과 CI ----------------------------------------------------------

echo
echo "[$FORGE]"
if [ "$FORGE" = gitlab ]; then
    place forge/pull-request.md .gitlab/merge_request_templates/Default.md
    place forge/issue/bug.md .gitlab/issue_templates/Bug.md gitlab_template
    place forge/issue/feature.md .gitlab/issue_templates/Feature.md gitlab_template
    place forge/issue/troubleshooting.md .gitlab/issue_templates/Troubleshooting.md gitlab_template
    note_foreign .gitlab/issue_templates 'Bug\.md|Feature\.md|Troubleshooting\.md'
    place_or_note forge/gitlab-ci.yml .gitlab-ci.yml 'scripts/doc-index.sh'
else
    place forge/pull-request.md .github/pull_request_template.md
    for t in bug feature troubleshooting; do
        place "forge/issue/$t.md" ".github/ISSUE_TEMPLATE/$t.md"
    done
    note_foreign .github/ISSUE_TEMPLATE 'bug\.md|feature\.md|troubleshooting\.md'
    place forge/github-workflow.yml .github/workflows/docs.yml
fi

# --- 마무리 ---------------------------------------------------------------------

echo
if [ "$DRY_RUN" -eq 1 ]; then
    echo "결과: PLAN $adds, SKIP $skips, NOTE $notes, FAIL $fails"
    echo "적용하려면 --dry-run 을 빼고 다시 실행한다."
else
    echo "결과: ADD $adds, SKIP $skips, NOTE $notes, FAIL $fails"
    cat << 'EOF'

다음 할 일:
  1. AGENTS.md 첫 문단에 이 저장소가 무엇인지 적는다.
  2. NOTE 항목을 처리한다.
  3. 원격 저장소에 troubleshooting 라벨을 한 번 만든다. 명령은 docs/standards/troubleshooting.md 에 있다.
  4. bash scripts/doc-index.sh --check 로 확인한다.
EOF
fi
[ "$fails" -eq 0 ]
