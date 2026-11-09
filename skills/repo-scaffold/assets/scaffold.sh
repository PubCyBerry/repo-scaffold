#!/usr/bin/env bash
# 대상 저장소에 에이전트용 문서 체계를 깐다. 파일을 복사할 뿐이고 기존 파일은 덮어쓰지 않는다.
# 사용법은 usage가 출력한다. 스크립트 출력이므로 영어로 쓴다.

set -uo pipefail

usage() {
    cat << 'EOF'
usage: bash scaffold.sh [--dry-run] [--forge github|gitlab] [--init] TARGET

  TARGET      root of the target repository
  --dry-run   print the plan without writing anything
  --forge     layout of the PR template, issue templates, and CI job.
              Defaults to gitlab when the origin URL contains "gitlab",
              otherwise github. Gitea and Forgejo read the github layout.
  --init      run git init when TARGET is not a git repository

verdicts: ADD created, PLAN would create, SKIP already exists,
          NOTE needs a manual step, FAIL failed
exit status: 1 when anything failed, 2 on a usage error
EOF
}

ASSETS="$(cd "$(dirname "$0")" && pwd)"
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
                usage >&2
                exit 2
            }
            FORGE="$2"
            shift
            ;;
        -h | --help)
            usage
            exit 0
            ;;
        -*)
            echo "unknown option: $1" >&2
            usage >&2
            exit 2
            ;;
        *) TARGET="$1" ;;
    esac
    shift
done

case "$FORGE" in
    "" | github | gitlab) ;;
    *)
        echo "--forge must be github or gitlab: $FORGE" >&2
        exit 2
        ;;
esac
[ -n "$TARGET" ] || {
    usage >&2
    exit 2
}
[ -d "$TARGET" ] || {
    echo "FAIL: no such directory: $TARGET" >&2
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
        echo "FAIL: not the repository root: $TARGET" >&2
        exit 2
    fi
elif [ "$INIT" -eq 0 ]; then
    echo "FAIL: not a git repository: $TARGET (pass --init to create one)" >&2
    exit 1
elif [ "$DRY_RUN" -eq 1 ]; then
    report PLAN "git init"
elif git -C "$TARGET" init -q; then
    report ADD "git init"
else
    echo "FAIL: git init failed: $TARGET" >&2
    exit 1
fi

if [ -z "$FORGE" ]; then
    case "$(git -C "$TARGET" remote get-url origin 2> /dev/null)" in
        *gitlab*) FORGE=gitlab ;;
        *) FORGE=github ;;
    esac
fi
echo "target: $TARGET"
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

# place SRC DEST [FILTER]: SRC는 assets 기준, DEST는 대상 저장소 기준 경로다.
# 새로 만들었을 때만 0을 돌려준다.
place() {
    local src="$ASSETS/$1" rel="$2" filter="${3:-cat}" dest="$TARGET/$2"
    if through_symlink "$rel"; then
        report FAIL "$rel" "refused: the path goes through a symlink"
        return 1
    fi
    if [ -e "$dest" ]; then
        report SKIP "$rel"
        return 1
    fi
    if [ ! -f "$src" ]; then
        report FAIL "$rel" "missing source: $src"
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
    report FAIL "$rel" "write failed"
    return 1
}

# 이미 있으면 사람이 합쳐야 하는 설정 파일. 필요한 내용이 이미 들어 있으면 SKIP이다.
# place_or_note SRC DEST NEEDLE
place_or_note() {
    if [ -f "$TARGET/$2" ] && ! through_symlink "$2"; then
        if grep -qF -- "$3" "$TARGET/$2"; then
            report SKIP "$2"
        else
            report NOTE "$2" "already exists; merge $ASSETS/$1 into it by hand"
        fi
        return
    fi
    place "$1" "$2"
}

# 템플릿 디렉터리에 이 스크립트가 깔지 않은 파일이 있으면 용도가 겹치는지 사람이 확인한다.
# note_foreign DIR OWN_NAMES_REGEX
note_foreign() {
    local f
    for f in "$TARGET/$1"/*; do
        [ -e "$f" ] || continue
        if ! printf '%s\n' "${f##*/}" | grep -qxE "$2"; then
            report NOTE "$1" "other templates exist; remove the ones that serve the same purpose"
            return
        fi
    done
}

# GitLab은 이슈 템플릿의 front matter를 읽지 않는다. 지우고 labels를 /label 빠른 동작으로 옮긴다.
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
echo "[docs and checks]"
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
    # Windows는 실행 비트를 기록하지 못한다. 그대로 두면 다른 운영체제에서 hook이 실행되지 않으므로
    # git 인덱스에 직접 기록한다.
    git -C "$TARGET" add --chmod=+x -- .githooks/pre-commit \
        && printf '     %s\n' "staged to record the executable bit"
fi

hooks_path="$(git -C "$TARGET" config --get core.hooksPath 2> /dev/null)"
if [ "$hooks_path" = .githooks ]; then
    report SKIP "core.hooksPath=.githooks"
elif [ -n "$hooks_path" ] || [ -e "$TARGET/.pre-commit-config.yaml" ] || [ -e "$TARGET/.husky" ] \
    || [ -e "$TARGET/lefthook.yml" ] \
    || (cd "$TARGET" && [ -e "$(git rev-parse --git-path hooks/pre-commit 2> /dev/null)" ]); then
    report NOTE "core.hooksPath" "another hook setup exists, so it was left alone; call bash .githooks/pre-commit from its pre-commit hook"
elif [ "$DRY_RUN" -eq 1 ]; then
    report PLAN "core.hooksPath=.githooks"
elif git -C "$TARGET" config core.hooksPath .githooks; then
    report ADD "core.hooksPath=.githooks"
else
    report FAIL "core.hooksPath" "git config failed"
fi

if [ "$agents_without_markers" -eq 1 ]; then
    report NOTE "AGENTS.md" "no place for the docs index; merge the sections of $ASSETS/AGENTS.md, then run bash scripts/doc-index.sh"
fi
if [ -e "$TARGET/CLAUDE.md" ]; then
    report NOTE "CLAUDE.md" "Claude Code reads AGENTS.md only when CLAUDE.md is absent; move its content into AGENTS.md and delete it"
fi
if [ -n "$had_docs" ] && [ "$first_run" -eq 1 ]; then
    report NOTE "docs/" "existing documents found; add front matter to them, then run bash scripts/doc-index.sh"
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
    echo "result: PLAN $adds, SKIP $skips, NOTE $notes, FAIL $fails"
    echo "run again without --dry-run to apply"
else
    echo "result: ADD $adds, SKIP $skips, NOTE $notes, FAIL $fails"
    cat << 'EOF'

next steps:
  1. Describe the repository in the first paragraph of AGENTS.md.
  2. Resolve the NOTE items.
  3. Create the troubleshooting label on the remote once; see docs/standards/troubleshooting.md.
  4. Run bash scripts/doc-index.sh --check.
EOF
fi
[ "$fails" -eq 0 ]
