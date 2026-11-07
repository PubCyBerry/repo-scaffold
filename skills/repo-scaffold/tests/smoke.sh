#!/usr/bin/env bash
# scaffold.sh 와 doc-index.sh 가 약속한 대로 동작하는지 임시 저장소에서 확인한다.
#
#   bash skills/repo-scaffold/tests/smoke.sh

set -euo pipefail

ASSETS="$(cd "$(dirname "$0")/../assets" && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# 사용자의 전역 git 설정(훅 경로, 서명, 줄바꿈 변환)이 결과를 바꾸지 않게 막는다.
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

# 출력은 $WORK/log 에 남긴다. 실패 원인을 보려면 그 파일을 읽는다.
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
scaffold "$gh" || fail "빈 저장소에 깔지 못했다: $(cat "$WORK/log")"
for f in AGENTS.md docs/index.md docs/decisions/index.md docs/standards/index.md \
    docs/standards/decisions.md docs/standards/documentation.md \
    docs/standards/issues-and-pull-requests.md docs/standards/troubleshooting.md \
    docs/standards/writing-style.md scripts/doc-index.sh .githooks/pre-commit .gitattributes \
    .github/pull_request_template.md .github/ISSUE_TEMPLATE/bug.md \
    .github/ISSUE_TEMPLATE/feature.md .github/ISSUE_TEMPLATE/troubleshooting.md \
    .github/workflows/docs.yml; do
    [ -f "$gh/$f" ] || fail "github: $f 가 없다"
done
[ ! -e "$gh/CLAUDE.md" ] || fail "CLAUDE.md 를 만들었다"
[ ! -e "$gh/.gitlab" ] && [ ! -e "$gh/.gitlab-ci.yml" ] || fail "github 저장소에 gitlab 파일을 만들었다"
[ "$(git -C "$gh" config core.hooksPath)" = .githooks ] || fail "core.hooksPath 를 설정하지 않았다"
[ "$(git -C "$gh" ls-files -s .githooks/pre-commit | cut -c1-6)" = 100755 ] \
    || fail "훅의 실행 비트가 git 인덱스에 없다"
check_docs "$gh" || fail "갓 깐 저장소가 검사를 통과하지 못했다: $(cat "$WORK/check.log")"
ok "빈 저장소에 github 형식으로 깔고 문서 검사를 통과한다"

before="$(fingerprint "$gh")"
scaffold "$gh" || fail "두 번째 실행이 실패했다: $(cat "$WORK/log")"
if grep -q '^ADD' "$WORK/log"; then fail "두 번째 실행이 무언가를 만들었다"; fi
[ "$before" = "$(fingerprint "$gh")" ] || fail "두 번째 실행이 파일을 바꿨다"
ok "다시 실행해도 아무것도 바뀌지 않는다"

mkdir "$gh/sub"
if scaffold "$gh/sub"; then fail "저장소 루트가 아닌 곳에 깔았다"; fi
ok "저장소 루트가 아니면 멈춘다"

# --- doc-index.sh ---------------------------------------------------------------

printf '# Deploy\n' > "$gh/docs/deploy.md"
if check_docs "$gh"; then fail "front matter 가 없는 문서를 통과시켰다"; fi
grep -qF 'docs/deploy.md: front matter' "$WORK/check.log" || fail "front matter 누락을 알리지 않았다"

cat > "$gh/docs/deploy.md" << 'EOF'
---
type: Guide
title: "Deploy: staging"
description: How to deploy to staging. # comment
status: draft
---

# Deploy
EOF
if check_docs "$gh"; then fail "낡은 인덱스를 통과시켰다"; fi
(cd "$gh" && bash scripts/doc-index.sh) > /dev/null || fail "인덱스를 다시 만들지 못했다"
check_docs "$gh" || fail "다시 만든 인덱스가 검사를 통과하지 못했다: $(cat "$WORK/check.log")"
grep -qxF '* [Deploy: staging](deploy.md) - How to deploy to staging. (draft)' "$gh/docs/index.md" \
    || fail "루트 index.md 에 새 문서가 없다"
grep -qF '|.:{deploy.md,index.md}|' "$gh/AGENTS.md" || fail "AGENTS.md 인덱스에 새 문서가 없다"
ok "front matter 를 검사하고 index.md 와 AGENTS.md 인덱스를 다시 만든다"

for f in docs/deploy.md docs/index.md AGENTS.md; do to_crlf "$gh/$f"; done
check_docs "$gh" || fail "CRLF 줄바꿈만 다른 파일을 낡은 것으로 봤다: $(cat "$WORK/check.log")"
ok "CRLF 로 체크아웃된 파일도 내용이 같으면 통과한다"

# --- pre-commit 훅 ---------------------------------------------------------------

cat > "$gh/docs/standards/release.md" << 'EOF'
---
type: Standard
title: Release
description: How releases are cut.
---
EOF
git -C "$gh" add -A
if git -C "$gh" commit -q -m "docs: add release" > /dev/null 2>&1; then fail "낡은 인덱스로 커밋이 됐다"; fi
grep -qF '(release.md)' "$gh/docs/standards/index.md" || fail "훅이 인덱스를 고치지 않았다"
git -C "$gh" add -A
git -C "$gh" commit -q -m "docs: add release" > /dev/null 2>&1 || fail "인덱스를 고친 뒤에도 커밋이 막혔다"
ok "pre-commit 훅이 낡은 인덱스를 고쳐 놓고 커밋을 한 번 멈춘다"

# --- gitlab 형식 -------------------------------------------------------------------

gl="$(new_repo gl)"
git -C "$gl" remote add origin https://gitlab.example.com/team/app.git
scaffold "$gl" || fail "gitlab 저장소에 깔지 못했다: $(cat "$WORK/log")"
for f in .gitlab/merge_request_templates/Default.md .gitlab/issue_templates/Bug.md \
    .gitlab/issue_templates/Feature.md .gitlab/issue_templates/Troubleshooting.md .gitlab-ci.yml; do
    [ -f "$gl/$f" ] || fail "gitlab: $f 가 없다"
done
[ ! -e "$gl/.github" ] || fail "gitlab 저장소에 .github 를 만들었다"
[ "$(head -n 1 "$gl/.gitlab/issue_templates/Bug.md")" = "## What happened" ] \
    || fail "GitLab 이슈 템플릿에 front matter 가 남았다"
[ "$(tail -n 1 "$gl/.gitlab/issue_templates/Troubleshooting.md")" = "/label ~troubleshooting" ] \
    || fail "GitLab 이슈 템플릿에 라벨 빠른 동작이 없다"
check_docs "$gl" || fail "gitlab 저장소가 문서 검사를 통과하지 못했다"
ok "origin 이 GitLab 이면 .gitlab 형식으로 깐다"

# --- 기존 파일이 있는 저장소 ------------------------------------------------------------

old="$(new_repo existing)"
printf 'mine\n' > "$old/AGENTS.md"
printf 'old\n' > "$old/CLAUDE.md"
mkdir -p "$old/.github/ISSUE_TEMPLATE"
printf 'name: Bug\n' > "$old/.github/ISSUE_TEMPLATE/bug_report.yml"
touch "$old/.pre-commit-config.yaml"
scaffold "$old" || fail "기존 파일이 있는 저장소에서 실패했다: $(cat "$WORK/log")"
[ "$(cat "$old/AGENTS.md")" = mine ] || fail "AGENTS.md 를 덮어썼다"
for target in AGENTS.md CLAUDE.md .github/ISSUE_TEMPLATE core.hooksPath; do
    grep -qE "^NOTE +$target" "$WORK/log" || fail "$target 에 대한 NOTE 가 없다"
done
[ -z "$(git -C "$old" config core.hooksPath || true)" ] || fail "다른 훅 관리자가 있는데 훅 경로를 바꿨다"
if check_docs "$old"; then fail "인덱스 자리가 없는 AGENTS.md 를 통과시켰다"; fi
ok "기존 파일을 덮어쓰지 않고 손볼 곳을 NOTE 로 알린다"

# --- dry-run 과 --init -------------------------------------------------------------

dry="$(new_repo dry)"
scaffold --dry-run "$dry" || fail "dry-run 이 실패했다: $(cat "$WORK/log")"
grep -q '^PLAN' "$WORK/log" || fail "dry-run 이 계획을 출력하지 않았다"
[ -z "$(find "$dry" -mindepth 1 -maxdepth 1 ! -name .git)" ] || fail "dry-run 이 파일을 만들었다"
[ -z "$(git -C "$dry" config core.hooksPath || true)" ] || fail "dry-run 이 훅 경로를 바꿨다"
ok "dry-run 은 아무것도 쓰지 않는다"

mkdir "$WORK/plain"
if scaffold "$WORK/plain"; then fail "git 저장소가 아닌데 진행했다"; fi
scaffold --init "$WORK/plain" || fail "--init 이 실패했다: $(cat "$WORK/log")"
git -C "$WORK/plain" rev-parse --git-dir > /dev/null 2>&1 || fail "--init 이 git init 하지 않았다"
ok "git 저장소가 아니면 멈추고, --init 이면 만들고 진행한다"

# --- 심링크 ------------------------------------------------------------------------

link="$(new_repo link)"
mkdir "$WORK/outside"
if ln -s "$WORK/outside" "$link/docs" 2> /dev/null && [ -L "$link/docs" ]; then
    if scaffold "$link"; then fail "심링크 경로가 있는데 성공으로 끝났다"; fi
    [ -z "$(ls -A "$WORK/outside")" ] || fail "심링크를 따라 대상 밖에 썼다"
    ok "심링크를 따라 대상 밖에 쓰지 않는다"
else
    echo "skip 심링크를 만들 수 없는 환경이다"
fi

echo "PASS: $passed"
