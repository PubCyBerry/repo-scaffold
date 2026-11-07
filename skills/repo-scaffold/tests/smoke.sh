#!/usr/bin/env bash
# scaffold.sh와 doc-index.sh가 약속한 대로 동작하는지 임시 저장소에서 확인한다.
#
#   bash skills/repo-scaffold/tests/smoke.sh

set -euo pipefail

ASSETS="$(cd "$(dirname "$0")/../assets" && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# 사용자의 전역 git 설정(hook 경로, 서명, 줄바꿈 변환)이 결과를 바꾸지 않게 막는다.
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
export GIT_AUTHOR_NAME=smoke GIT_AUTHOR_EMAIL=smoke@example.com
export GIT_COMMITTER_NAME=smoke GIT_COMMITTER_EMAIL=smoke@example.com

passed=0
ok() {
    passed=$((passed + 1))
    echo "ok   $*"
}
fail() {
    echo "FAIL $*" >&2
    exit 1
}

new_repo() {
    git init -q "$WORK/$1"
    echo "$WORK/$1"
}

# 출력은 $WORK/log에 남는다. 실패 원인은 fail 메시지에 함께 나온다.
scaffold() {
    bash "$ASSETS/scaffold.sh" "$@" > "$WORK/log" 2>&1
}

check_docs() {
    (cd "$1" && bash scripts/doc-index.sh --check) > "$WORK/check.log" 2>&1
}

fingerprint() {
    (cd "$1" && find . -path ./.git -prune -o -type f -print | LC_ALL=C sort | while IFS= read -r f; do cksum "$f"; done)
}

to_crlf() {
    awk '{ printf "%s\r\n", $0 }' "$1" > "$WORK/crlf" && cat "$WORK/crlf" > "$1"
}

# --- 빈 저장소, github 형식 --------------------------------------------------------

gh="$(new_repo gh)"
scaffold "$gh" || fail "could not scaffold an empty repository: $(cat "$WORK/log")"
for f in AGENTS.md docs/index.md docs/decisions/index.md docs/standards/index.md \
    docs/standards/decisions.md docs/standards/documentation.md \
    docs/standards/issues-and-pull-requests.md docs/standards/troubleshooting.md \
    docs/standards/writing-style.md scripts/doc-index.sh .githooks/pre-commit .gitattributes \
    .github/pull_request_template.md .github/ISSUE_TEMPLATE/bug.md \
    .github/ISSUE_TEMPLATE/feature.md .github/ISSUE_TEMPLATE/troubleshooting.md \
    .github/workflows/docs.yml; do
    [ -f "$gh/$f" ] || fail "github layout: $f is missing"
done
[ ! -e "$gh/CLAUDE.md" ] || fail "created CLAUDE.md"
[ ! -e "$gh/.gitlab" ] && [ ! -e "$gh/.gitlab-ci.yml" ] || fail "created GitLab files in a github repository"
[ "$(git -C "$gh" config core.hooksPath)" = .githooks ] || fail "core.hooksPath was not set"
[ "$(git -C "$gh" ls-files -s .githooks/pre-commit | cut -c1-6)" = 100755 ] \
    || fail "the hook's executable bit is not in the git index"
check_docs "$gh" || fail "a fresh scaffold fails the docs check: $(cat "$WORK/check.log")"
ok "scaffolds an empty repository in the github layout and passes the docs check"

before="$(fingerprint "$gh")"
scaffold "$gh" || fail "the second run failed: $(cat "$WORK/log")"
if grep -q '^ADD' "$WORK/log"; then fail "the second run created something"; fi
[ "$before" = "$(fingerprint "$gh")" ] || fail "the second run changed files"
ok "a second run changes nothing"

mkdir "$gh/sub"
if scaffold "$gh/sub"; then fail "scaffolded a directory below the repository root"; fi
ok "stops when the target is not the repository root"

# --- doc-index.sh ---------------------------------------------------------------

printf '# Deploy\n' > "$gh/docs/deploy.md"
if check_docs "$gh"; then fail "accepted a document without front matter"; fi
grep -qF 'docs/deploy.md: missing front matter' "$WORK/check.log" || fail "did not report the missing front matter"

cat > "$gh/docs/deploy.md" << 'EOF'
---
type: Guide
title: "Deploy: staging"
description: How to deploy to staging. # comment
status: draft
---

# Deploy
EOF
if check_docs "$gh"; then fail "accepted a stale index"; fi
(cd "$gh" && bash scripts/doc-index.sh) > /dev/null || fail "could not regenerate the index"
check_docs "$gh" || fail "the regenerated index fails the check: $(cat "$WORK/check.log")"
grep -qxF '* [Deploy: staging](deploy.md) - How to deploy to staging. (draft)' "$gh/docs/index.md" \
    || fail "the root index.md does not list the new document"
grep -qF '|.:{deploy.md,index.md}|' "$gh/AGENTS.md" || fail "the AGENTS.md index does not list the new document"
ok "checks front matter and regenerates index.md and the AGENTS.md index"

for f in docs/deploy.md docs/index.md AGENTS.md; do to_crlf "$gh/$f"; done
check_docs "$gh" || fail "treated files that differ only in CRLF as stale: $(cat "$WORK/check.log")"
ok "accepts files checked out with CRLF line endings"

# --- pre-commit hook -------------------------------------------------------------

cat > "$gh/docs/standards/release.md" << 'EOF'
---
type: Standard
title: Release
description: How releases are cut.
---
EOF
git -C "$gh" add -A
if git -C "$gh" commit -q -m "docs: add release" > /dev/null 2>&1; then fail "committed with a stale index"; fi
grep -qF '(release.md)' "$gh/docs/standards/index.md" || fail "the hook did not regenerate the index"
git -C "$gh" add -A
git -C "$gh" commit -q -m "docs: add release" > /dev/null 2>&1 || fail "the commit is still blocked after the index was regenerated"
ok "the pre-commit hook regenerates a stale index and stops the commit once"

# --- gitlab 형식 -------------------------------------------------------------------

gl="$(new_repo gl)"
git -C "$gl" remote add origin https://gitlab.example.com/team/app.git
scaffold "$gl" || fail "could not scaffold a GitLab repository: $(cat "$WORK/log")"
for f in .gitlab/merge_request_templates/Default.md .gitlab/issue_templates/Bug.md \
    .gitlab/issue_templates/Feature.md .gitlab/issue_templates/Troubleshooting.md .gitlab-ci.yml; do
    [ -f "$gl/$f" ] || fail "gitlab layout: $f is missing"
done
[ ! -e "$gl/.github" ] || fail "created .github in a GitLab repository"
[ "$(head -n 1 "$gl/.gitlab/issue_templates/Bug.md")" = "## 현상" ] \
    || fail "front matter is left in a GitLab issue template"
[ "$(tail -n 1 "$gl/.gitlab/issue_templates/Troubleshooting.md")" = "/label ~troubleshooting" ] \
    || fail "a GitLab issue template has no /label quick action"
check_docs "$gl" || fail "a GitLab repository fails the docs check"
ok "uses the gitlab layout when origin points at GitLab"

# --- 기존 파일이 있는 저장소 ------------------------------------------------------------

old="$(new_repo existing)"
printf 'mine\n' > "$old/AGENTS.md"
printf 'old\n' > "$old/CLAUDE.md"
mkdir -p "$old/.github/ISSUE_TEMPLATE"
printf 'name: Bug\n' > "$old/.github/ISSUE_TEMPLATE/bug_report.yml"
touch "$old/.pre-commit-config.yaml"
scaffold "$old" || fail "failed on a repository with existing files: $(cat "$WORK/log")"
[ "$(cat "$old/AGENTS.md")" = mine ] || fail "overwrote AGENTS.md"
for target in AGENTS.md CLAUDE.md .github/ISSUE_TEMPLATE core.hooksPath; do
    grep -qE "^NOTE +$target" "$WORK/log" || fail "no NOTE for $target"
done
[ -z "$(git -C "$old" config core.hooksPath || true)" ] || fail "changed core.hooksPath despite another hook setup"
if check_docs "$old"; then fail "accepted an AGENTS.md without a place for the index"; fi
ok "keeps existing files and reports what needs a manual step"

# --- dry-run과 --init ------------------------------------------------------------

dry="$(new_repo dry)"
scaffold --dry-run "$dry" || fail "dry-run failed: $(cat "$WORK/log")"
grep -q '^PLAN' "$WORK/log" || fail "dry-run printed no plan"
[ -z "$(find "$dry" -mindepth 1 -maxdepth 1 ! -name .git)" ] || fail "dry-run created files"
[ -z "$(git -C "$dry" config core.hooksPath || true)" ] || fail "dry-run changed core.hooksPath"
ok "dry-run writes nothing"

mkdir "$WORK/plain"
if scaffold "$WORK/plain"; then fail "went ahead in a directory that is not a git repository"; fi
scaffold --init "$WORK/plain" || fail "--init failed: $(cat "$WORK/log")"
git -C "$WORK/plain" rev-parse --git-dir > /dev/null 2>&1 || fail "--init did not run git init"
ok "stops outside a git repository, and --init creates one"

# --- 심링크 ------------------------------------------------------------------------

link="$(new_repo link)"
mkdir "$WORK/outside"
if ln -s "$WORK/outside" "$link/docs" 2> /dev/null && [ -L "$link/docs" ]; then
    if scaffold "$link"; then fail "reported success with a symlink in the path"; fi
    [ -z "$(ls -A "$WORK/outside")" ] || fail "followed a symlink and wrote outside the target"
    ok "does not follow symlinks out of the target"
else
    echo "skip symlinks cannot be created here"
fi

echo "PASS: $passed"
