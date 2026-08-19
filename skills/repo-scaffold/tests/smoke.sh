#!/usr/bin/env bash

set -euo pipefail

if [ "${REPO_SCAFFOLD_SED_WRAPPER:-0}" -eq 1 ]; then
    for arg in "$@"; do
        case "$arg" in
            */assets/scripts/gen-doc-index.sh)
                : > "$RACE_READY"
                while [ ! -e "$RACE_GO" ]; do sleep 0.01; done
                ;;
        esac
    done
    exec "$REAL_SED" "$@"
fi

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCAFFOLD="$SKILL_DIR/assets/scaffold.sh"
SMOKE="$SKILL_DIR/tests/smoke.sh"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

new_repo() {
    REPO="$TMP_ROOT/$1"
    mkdir -p "$REPO"
    git -C "$REPO" init -q
}

expect_failure() {
    local log="$1"
    shift
    if "$@" > "$log" 2>&1; then
        fail "실패해야 하는 명령이 성공함: $*"
    fi
}

# SKIP 된 generator와 AGENTS.md는 실행하거나 바꾸지 않는다.
new_repo existing
mkdir -p "$REPO/scripts"
printf '%s\n' '#!/usr/bin/env bash' "touch \"\$PWD/executed\"" > "$REPO/scripts/gen-doc-index.sh"
printf '%s\n' '기존 AGENTS 유지' > "$REPO/AGENTS.md"
cp "$REPO/AGENTS.md" "$TMP_ROOT/AGENTS.expected"
bash "$SCAFFOLD" --target "$REPO" > "$TMP_ROOT/existing.log"
[ ! -e "$REPO/executed" ] || fail "SKIP 된 generator를 실행함"
cmp -s "$REPO/AGENTS.md" "$TMP_ROOT/AGENTS.expected" || fail "SKIP 된 AGENTS.md를 변경함"

# 목적지 자체와 목적지 상위의 심링크를 모두 거부한다.
new_repo parent-symlink
mkdir -p "$TMP_ROOT/outside-docs"
ln -s "$TMP_ROOT/outside-docs" "$REPO/docs"
if [ -L "$REPO/docs" ]; then
    expect_failure "$TMP_ROOT/parent-symlink.log" bash "$SCAFFOLD" --target "$REPO"
    [ -z "$(find "$TMP_ROOT/outside-docs" -mindepth 1 -print -quit)" ] \
        || fail "심링크 밖에 파일을 생성함"
else
    echo "SKIP native symlink를 만들 수 없어 symlink fixture를 건너뜀"
fi

new_repo destination-symlink
printf '%s\n' '외부 AGENTS 유지' > "$TMP_ROOT/outside-AGENTS.md"
cp "$TMP_ROOT/outside-AGENTS.md" "$TMP_ROOT/outside-AGENTS.expected"
ln -s "$TMP_ROOT/outside-AGENTS.md" "$REPO/AGENTS.md"
if [ -L "$REPO/AGENTS.md" ]; then
    expect_failure "$TMP_ROOT/destination-symlink.log" bash "$SCAFFOLD" --target "$REPO"
    cmp -s "$TMP_ROOT/outside-AGENTS.md" "$TMP_ROOT/outside-AGENTS.expected" \
        || fail "심링크 목적지를 변경함"
else
    echo "SKIP native symlink를 만들 수 없어 destination fixture를 건너뜀"
fi

# 검사 뒤 목적지가 생겨도 기존 파일을 덮어쓰지 않는다.
new_repo publish-race
mkdir -p "$REPO/scripts" "$TMP_ROOT/race-bin"
# 이 파일 자신을 sed 래퍼로 쓴다. 심링크가 아니라 복사본에 실행 권한을 직접 준다.
# 심링크는 Windows 에서 만들어지지 않고, 리눅스에서는 원본의 커밋된 실행 권한에
# 의존해서 두 환경의 결과가 갈린다.
cp "$SMOKE" "$TMP_ROOT/race-bin/sed"
chmod +x "$TMP_ROOT/race-bin/sed"
REAL_SED="$(command -v sed)" \
RACE_READY="$TMP_ROOT/race-ready" RACE_GO="$TMP_ROOT/race-go" \
REPO_SCAFFOLD_SED_WRAPPER=1 PATH="$TMP_ROOT/race-bin:$PATH" \
    bash "$SCAFFOLD" --target "$REPO" > "$TMP_ROOT/publish-race.log" &
race_pid=$!
while [ ! -e "$TMP_ROOT/race-ready" ]; do
    kill -0 "$race_pid" 2> /dev/null || {
        wait "$race_pid" || true
        fail "race 주입 전 종료됨"
    }
done
printf '%s\n' '경쟁 생성 파일 유지' > "$REPO/scripts/gen-doc-index.sh"
: > "$TMP_ROOT/race-go"
wait "$race_pid"
grep -Fqx '경쟁 생성 파일 유지' "$REPO/scripts/gen-doc-index.sh" || fail "경쟁 생성 파일을 덮어씀"
grep -q '^SKIP scripts/gen-doc-index.sh' "$TMP_ROOT/publish-race.log" || fail "경쟁 생성을 SKIP으로 보고하지 않음"

# sed replacement 메타문자는 그대로 보존하고 CR/LF는 쓰기 전에 거부한다.
new_repo special
name='repo & tools \ path | safe'
desc='R&D \ pipeline | safe'
bash "$SCAFFOLD" --target "$REPO" --name "$name" --desc "$desc" > "$TMP_ROOT/special.log"
grep -Fqx "# $name" "$REPO/README.md" || fail "특수문자 이름 치환 실패"
grep -Fqx "$desc" "$REPO/README.md" || fail "특수문자 설명 치환 실패"
grep -Fq "[$name Docs Index]" "$REPO/AGENTS.md" || fail "인덱스 특수문자 보존 실패"

new_repo line-break
for bad in $'두 줄\n설명' $'CR\r설명'; do
    expect_failure "$TMP_ROOT/line-break.log" bash "$SCAFFOLD" --target "$REPO" --desc "$bad"
    [ ! -e "$REPO/README.md" ] || fail "줄바꿈 입력으로 파일을 생성함"
done

new_repo missing-value
expect_failure "$TMP_ROOT/missing-value.log" bash "$SCAFFOLD" --target "$REPO" --name
[ ! -e "$REPO/README.md" ] || fail "옵션 값 누락 후 파일을 생성함"

# 같은 저장소에 두 번 실행해도 worktree 결과가 같아야 한다.
new_repo twice
printf '%s\n' '기존 미추적 문서' > "$REPO/notes.md"
bash "$SCAFFOLD" --target "$REPO" > "$TMP_ROOT/twice-first.log"
if git -C "$REPO" ls-files --error-unmatch notes.md > /dev/null 2>&1; then
    fail "이번 실행에서 만들지 않은 경로를 git index에 등록함"
fi
git -C "$REPO" status --porcelain=v1 -uall > "$TMP_ROOT/status.before"
git -C "$REPO" diff --binary > "$TMP_ROOT/diff.before"
bash "$SCAFFOLD" --target "$REPO" > "$TMP_ROOT/twice-second.log"
git -C "$REPO" status --porcelain=v1 -uall > "$TMP_ROOT/status.after"
git -C "$REPO" diff --binary > "$TMP_ROOT/diff.after"
cmp -s "$TMP_ROOT/status.before" "$TMP_ROOT/status.after" || fail "두 번째 실행이 상태를 변경함"
cmp -s "$TMP_ROOT/diff.before" "$TMP_ROOT/diff.after" || fail "두 번째 실행이 파일을 변경함"
grep -q '결과: ADD 0,' "$TMP_ROOT/twice-second.log" || fail "두 번째 실행에서 파일을 추가함"

# 스캐폴딩 결과가 스스로 배포한 검증을 통과해야 한다.
# 템플릿을 고치고 검증 스크립트를 안 고치면 여기서 잡힌다.
run_self_check() {
    # $1: 검증 스크립트 이름, $2...: 인자
    local name="$1"
    shift
    if ! (cd "$REPO" && bash "tests/$name" "$@") > "$TMP_ROOT/self-$name.log" 2>&1; then
        cat "$TMP_ROOT/self-$name.log"
        fail "스캐폴딩 결과가 $name 을 통과하지 못함"
    fi
}

new_repo self-check
bash "$SCAFFOLD" --target "$REPO" --name SELFCHECK > "$TMP_ROOT/self-check.log"
run_self_check check-docs.sh
run_self_check check-docs.sh --only title,placement,paths
run_self_check check-docs-metadata.sh
run_self_check check-markdown.sh
run_self_check check-prose.sh
run_self_check check-shell.sh
run_self_check check-yaml.sh
run_self_check check-workflows.sh
run_self_check check-hooks.sh
run_self_check check-tool-versions.sh
run_self_check check-env.sh
run_self_check check-secrets.sh
# 커밋 중이 아니면 검사할 메시지가 없다. SKIP 으로 통과해야 한다.
run_self_check check-commit-msg.sh
# 파이썬이 없는 저장소에서도 SKIP 으로 통과해야 한다. FAIL 이면 훅이 매 커밋 막는다.
run_self_check check-python.sh
run_self_check run-tests.sh

# 모르는 검사 단계는 돌기 전에 거절한다.
expect_failure "$TMP_ROOT/bad-phase.log" bash "$REPO/tests/check-docs.sh" --only nosuchphase
expect_failure "$TMP_ROOT/missing-only.log" bash "$REPO/tests/check-docs.sh" --only

# 링크 규약은 rumdl 이 본다. 저장소 루트 기준 링크와 절대 경로 링크는 둘 다 FAIL 이다.
# 규약이 뒤집힌 채로 남아 있는지, 그리고 배포되는 rumdl.toml 이 MD057 을 실제로 켜는지
# 기계로 확인한다. absolute-links 를 켜지 않으면 절대 경로가 조용히 통과한다.
# git 으로 되돌리지 않는다. 생성 파일은 add -N 상태라 checkout 하면 빈 파일이 된다.
if command -v rumdl > /dev/null 2>&1; then
    cp "$REPO/docs/standards/shell.md" "$TMP_ROOT/shell.md.orig"
    for bad in 'docs/standards/testing.md' '/docs/standards/testing.md'; do
        cp "$TMP_ROOT/shell.md.orig" "$REPO/docs/standards/shell.md"
        printf '\n- [bad link](%s)\n' "$bad" >> "$REPO/docs/standards/shell.md"
        # 저장소 안에서 돌려야 한다. 밖에서 부르면 git 이 이 스킬 저장소를 루트로 잡는다.
        if (cd "$REPO" && bash tests/check-markdown.sh) > "$TMP_ROOT/bad-link.log" 2>&1; then
            cat "$TMP_ROOT/bad-link.log"
            fail "rumdl 이 '$bad' 를 FAIL 로 잡지 못함"
        fi
        grep -q 'MD057' "$TMP_ROOT/bad-link.log" \
            || fail "'$bad' 를 MD057 로 지적하지 않음"
    done
    cp "$TMP_ROOT/shell.md.orig" "$REPO/docs/standards/shell.md"
    run_self_check check-markdown.sh
else
    echo "SKIP rumdl 을 찾을 수 없어 링크 규약 검사를 건너뜀"
fi

# 커밋 메시지 표기 검사는 도구를 쓰지 않는다. node_modules 가 없어도 실제 결함을 잡아야 한다.
printf '%s\n' 'feat(docs): 셸·YAML 설정 정리' > "$TMP_ROOT/msg.bad"
if (cd "$REPO" && bash tests/check-commit-msg.sh "$TMP_ROOT/msg.bad" --only notation) \
    > "$TMP_ROOT/commit-msg-notation.log" 2>&1; then
    cat "$TMP_ROOT/commit-msg-notation.log"
    fail "제목의 금지 문자를 FAIL 로 잡지 못함"
fi
grep -q '^FAIL interpunct' "$TMP_ROOT/commit-msg-notation.log" \
    || fail "금지 문자를 그 이유로 지적하지 않음"

printf '%s\n' 'feat(docs): 셸과 YAML 설정 정리' > "$TMP_ROOT/msg.good"
run_self_check check-commit-msg.sh "$TMP_ROOT/msg.good" --only notation

# fixup! 제목은 원문을 그대로 옮긴 것이다. 여기서 막으면 git rebase --autosquash 가 깨진다.
printf '%s\n' 'fixup! feat(docs): 셸·YAML 설정 정리' > "$TMP_ROOT/msg.fixup"
run_self_check check-commit-msg.sh "$TMP_ROOT/msg.fixup" --only notation

# 도구가 없을 때의 판정. 로컬은 SKIP 으로 넘기고 CI 는 FAIL 로 막는다.
# 도구가 실제로 깔린 환경에서는 그 판정이 나오지 않으므로 건너뛴다.
expect_missing_tool_verdict() {
    # $1: 도구가 있으면 1 없으면 0, $2: 도구 이름, $3: 로그 라벨, $4...: 스크립트와 인자
    local present="$1" tool="$2" label="$3"
    shift 3
    if [ "$present" -eq 1 ]; then
        echo "SKIP $tool 이 설치돼 있어 미설치 판정 검사를 건너뜀"
        return
    fi
    if ! (cd "$REPO" && CI=false bash "$@") > "$TMP_ROOT/$label-local.log" 2>&1; then
        cat "$TMP_ROOT/$label-local.log"
        fail "$tool 미설치를 로컬에서 SKIP 으로 넘기지 못함"
    fi
    if (cd "$REPO" && CI=true bash "$@") > "$TMP_ROOT/$label-ci.log" 2>&1; then
        cat "$TMP_ROOT/$label-ci.log"
        fail "$tool 미설치를 CI 에서 FAIL 로 올리지 못함"
    fi
}

lychee_present=0
if command -v lychee > /dev/null 2>&1; then
    lychee_present=1
fi
expect_missing_tool_verdict "$lychee_present" lychee links-external \
    tests/check-links-external.sh

# commitlint 는 PATH 가 아니라 node_modules 를 본다. 스캐폴딩은 그것을 만들지 않는다.
commitlint_present=0
if [ -x "$REPO/node_modules/.bin/commitlint" ]; then
    commitlint_present=1
fi
expect_missing_tool_verdict "$commitlint_present" commitlint commit-msg \
    tests/check-commit-msg.sh "$TMP_ROOT/msg.good" --only conventional

# Justfile 은 스캐폴딩 치환 키를 하나도 갖지 않는다. 남으면 just 가 파싱 단계에서 죽는다.
if grep -nE '\{\{[A-Z][A-Z0-9_]*\}\}' "$REPO/Justfile" > "$TMP_ROOT/justfile-placeholders.log" 2>&1; then
    cat "$TMP_ROOT/justfile-placeholders.log"
    fail "Justfile 에 치환되지 않은 자리표시자가 남음"
fi

# doctor 는 환경에 따라 SKIP 과 FAIL 이 갈린다. 렌더 결과에 대한 판정만 본다.
(cd "$REPO" && CI=false bash scripts/doctor.sh) > "$TMP_ROOT/self-doctor.log" 2>&1 || true
if ! grep -q '^PASS Justfile' "$TMP_ROOT/self-doctor.log"; then
    cat "$TMP_ROOT/self-doctor.log"
    fail "doctor.sh 가 Justfile 자리표시자 검사를 통과하지 못함"
fi

# 렌더된 Justfile 이 실제로 파싱되는지 본다. 렌더링 버그를 사용자보다 한 층 앞에서 잡는다.
JUST_BIN="${JUST:-}"
if [ -z "$JUST_BIN" ] && command -v just > /dev/null 2>&1; then
    JUST_BIN="just"
fi
if [ -n "$JUST_BIN" ]; then
    if ! (cd "$REPO" && "$JUST_BIN" --summary) > "$TMP_ROOT/just-summary.log" 2>&1; then
        cat "$TMP_ROOT/just-summary.log"
        fail "렌더된 Justfile 을 just 가 파싱하지 못함"
    fi
    summary=" $(tr '\n' ' ' < "$TMP_ROOT/just-summary.log") "
    for recipe in bootstrap doctor fmt fix lint lint-python type markdown prose docs links-external hooks tool-versions commit-range labels-check security test test-unit verify check; do
        case "$summary" in
            *" $recipe "*) ;;
            *) fail "just --summary 에 $recipe 레시피가 없음" ;;
        esac
    done
    # Justfile 에 없는 이름은 FAIL 이 아니라 SKIP 이다. verify 목록을 도입 전에 적어둘 수 있다.
    if ! (cd "$REPO" && JUST="$JUST_BIN" bash scripts/run-all.sh not-a-real-recipe) \
        > "$TMP_ROOT/run-all-skip.log" 2>&1; then
        cat "$TMP_ROOT/run-all-skip.log"
        fail "run-all.sh 가 없는 레시피를 FAIL 로 처리함"
    fi
    grep -q '^SKIP not-a-real-recipe' "$TMP_ROOT/run-all-skip.log" \
        || fail "run-all.sh 가 없는 레시피를 SKIP 으로 보고하지 않음"
else
    echo "SKIP just 를 찾을 수 없어 Justfile 파싱 검사를 건너뜀 (JUST=/path/to/just 로 지정한다)"
fi

# --help 은 헤더 주석만 낸다. 저장소 루트가 아닌 곳에서 상대 경로로 불러도 자기 파일을 찾아야 한다.
# 스크립트가 REPO_ROOT 로 cd 한 뒤 상대 BASH_SOURCE 를 읽으면 여기서 걸린다.
for script in tests/check-docs.sh tests/check-docs-metadata.sh tests/check-markdown.sh \
    tests/check-prose.sh tests/check-shell.sh tests/check-yaml.sh tests/check-workflows.sh \
    tests/check-hooks.sh tests/check-env.sh tests/check-secrets.sh tests/check-tool-versions.sh \
    tests/check-commit-msg.sh tests/check-links-external.sh \
    tests/check-python.sh tests/run-tests.sh \
    scripts/gen-doc-index.sh \
    scripts/run-all.sh scripts/bootstrap.sh scripts/doctor.sh scripts/fmt.sh scripts/fix.sh \
    scripts/tool-help.sh \
    scripts/apply-github-labels.sh scripts/apply-github-repository-settings.sh; do
    log="$TMP_ROOT/help-$(basename "$script").log"
    if ! (cd "$REPO/docs" && bash "../$script" --help) > "$log" 2>&1; then
        cat "$log"
        fail "$script --help 가 실패함"
    fi
    if ! grep -q '^# 종료 코드' "$log"; then
        cat "$log"
        fail "$script --help 가 헤더 주석을 출력하지 못함"
    fi
    if grep -q 'set -uo pipefail' "$log"; then
        fail "$script --help 가 헤더 주석을 넘어 코드까지 출력함"
    fi
done

# PEP-723 문서 검사기는 argparse 로 --help 를 낸다. 헤더 주석 규약은 셸 스크립트의 것이다.
# uv 가 없으면 훅과 CI 가 SKIP 으로 넘기므로 여기서도 넘긴다.
if command -v uv > /dev/null 2>&1; then
    for script in docs_freshness.py docs_graph.py check_pr_metadata.py; do
        log="$TMP_ROOT/help-$script.log"
        if ! (cd "$REPO" && uv run --script "scripts/$script" --help) > "$log" 2>&1; then
            cat "$log"
            fail "scripts/$script --help 가 실패함"
        fi
        grep -q -- '--only' "$log" || fail "scripts/$script --help 가 사용법을 내지 못함"
    done

    # 검사기가 실제 결함을 잡는지 본다. 조용히 통과하는 검사기의 초록 불은 미검사와 같다.
    cp "$REPO/docs/standards/shell.md" "$TMP_ROOT/shell.md.orig"
    sed 's/^id: standard-shell$/id: standard-testing/' "$TMP_ROOT/shell.md.orig" \
        > "$REPO/docs/standards/shell.md"
    if (cd "$REPO" && bash tests/check-docs-metadata.sh --only graph) \
        > "$TMP_ROOT/duplicate-id.log" 2>&1; then
        cat "$TMP_ROOT/duplicate-id.log"
        fail "중복 id 를 FAIL 로 잡지 못함"
    fi
    grep -q '2개 문서에 있다' "$TMP_ROOT/duplicate-id.log" \
        || fail "중복 id 를 그 이유로 지적하지 않음"
    cp "$TMP_ROOT/shell.md.orig" "$REPO/docs/standards/shell.md"
    run_self_check check-docs-metadata.sh --only graph

    # PR 계약 검사기. squash 커밋 제목이 PR 제목에서 합성되므로 제목 검사가 핵심이다.
    # 통과 경로와 실패 경로를 둘 다 확인한다. 조용히 통과하는 검사기는 미검사와 같다.
    PR_BODY_GOOD="$TMP_ROOT/pr-body.good"
    : > "$PR_BODY_GOOD"
    for section in "Summary" "Motivation" "Linked issue" "Changes" "Scope / Non-goals" \
        "Validation" "Risk / Compatibility" "Documentation" "Reviewer focus"; do
        printf '## %s\n\n' "$section" >> "$PR_BODY_GOOD"
        if [ "$section" = "Linked issue" ]; then
            printf 'Closes #12\n\n' >> "$PR_BODY_GOOD"
        else
            printf 'content\n\n' >> "$PR_BODY_GOOD"
        fi
    done

    pr_policy() {
        # $1: 제목, $2: 본문 파일, $3...: 추가 인자
        local title="$1" body="$2"
        shift 2
        (cd "$REPO" && uv run --script scripts/check_pr_metadata.py \
            --title "$title" --body-file "$body" "$@")
    }

    if ! pr_policy 'feat(policy): add a governance gate' "$PR_BODY_GOOD" \
        > "$TMP_ROOT/pr-policy-good.log" 2>&1; then
        cat "$TMP_ROOT/pr-policy-good.log"
        fail "올바른 PR 을 check_pr_metadata.py 가 막음"
    fi

    if pr_policy 'feat(policy): Add a governance gate' "$PR_BODY_GOOD" \
        > "$TMP_ROOT/pr-policy-title.log" 2>&1; then
        cat "$TMP_ROOT/pr-policy-title.log"
        fail "대문자로 시작하는 PR 제목을 FAIL 로 잡지 못함"
    fi
    grep -q '소문자로 시작한다' "$TMP_ROOT/pr-policy-title.log" \
        || fail "대문자 제목을 그 이유로 지적하지 않음"

    grep -v '^## Validation$' "$PR_BODY_GOOD" > "$TMP_ROOT/pr-body.missing"
    if pr_policy 'feat(policy): add a governance gate' "$TMP_ROOT/pr-body.missing" \
        > "$TMP_ROOT/pr-policy-section.log" 2>&1; then
        cat "$TMP_ROOT/pr-policy-section.log"
        fail "빠진 필수 절을 FAIL 로 잡지 못함"
    fi
    grep -q '필수 절이 없다' "$TMP_ROOT/pr-policy-section.log" \
        || fail "빠진 절을 그 이유로 지적하지 않음"

    # 절은 남기고 닫는 키워드만 없앤다. 줄째로 지우면 절이 비어서 다른 검사에 걸린다.
    sed 's/^Closes #12$/no issue for this one/' "$PR_BODY_GOOD" > "$TMP_ROOT/pr-body.noissue"
    if pr_policy 'feat(policy): add a governance gate' "$TMP_ROOT/pr-body.noissue" \
        > "$TMP_ROOT/pr-policy-issue.log" 2>&1; then
        cat "$TMP_ROOT/pr-policy-issue.log"
        fail "이슈 미연결을 FAIL 로 잡지 못함"
    fi
    grep -q '이슈를 걸거나' "$TMP_ROOT/pr-policy-issue.log" \
        || fail "이슈 미연결을 그 이유로 지적하지 않음"

    # 면제 라벨이 있으면 같은 본문이 통과해야 한다. 없으면 사소한 PR 이 전부 막힌다.
    if ! pr_policy 'feat(policy): add a governance gate' "$TMP_ROOT/pr-body.noissue" \
        --label policy/skip-issue > "$TMP_ROOT/pr-policy-skip.log" 2>&1; then
        cat "$TMP_ROOT/pr-policy-skip.log"
        fail "policy/skip-issue 라벨로 면제되지 않음"
    fi

    # 배포한 PR 템플릿을 그대로 낸 PR 은 통과하면 안 된다.
    if pr_policy 'feat(policy): add a governance gate' \
        "$REPO/.github/pull_request_template.md" \
        > "$TMP_ROOT/pr-policy-template.log" 2>&1; then
        cat "$TMP_ROOT/pr-policy-template.log"
        fail "빈 템플릿 본문을 FAIL 로 잡지 못함"
    fi
else
    echo "SKIP uv 를 찾을 수 없어 문서 수명주기 검사기 확인을 건너뜀"
fi

# commitlint 이 링크된 git worktree 에서 실제로 도는지 본다.
# node_modules 는 gitignore 대상이라 링크된 worktree 에 체크아웃되지 않는다. 주 저장소의
# 것을 못 찾으면 형식 검사가 조용히 SKIP 되고, 이 저장소가 문서로 지시하는 병렬 작업
# 방식이 곧 커밋 규약이 아무 데서도 걸리지 않는 방식이 된다.
new_repo worktree-commitlint
bash "$SCAFFOLD" --target "$REPO" > "$TMP_ROOT/worktree-scaffold.log"
git_commit() {
    # $1...: git commit 인자. 훅은 이 저장소에 깔려 있지 않지만 명시해 둔다.
    git -C "$REPO" -c user.name=smoke -c user.email=smoke@example.invalid \
        commit -q --no-verify "$@"
}
git -C "$REPO" add -A
git_commit -m 'chore: seed'

# commitlint 과 node 를 흉내 낸다. 이 검사가 보는 것은 경로 해석이지 commitlint 판정이 아니다.
mkdir -p "$REPO/node_modules/.bin" "$TMP_ROOT/wt-bin"
# --config 이 없으면 실패한다. 진짜 commitlint 이 그때 MODULE_NOT_FOUND 로 죽는 것과
# 같은 자리다. 인자를 grep 하는 것만으로는 그 회귀를 못 잡는다.
cat > "$REPO/node_modules/.bin/commitlint" << 'STUB'
#!/usr/bin/env bash
printf '%s\n' "$@" > "${COMMITLINT_ARGV:-/dev/null}"
if [ "${COMMITLINT_STUB_NEEDS_CONFIG:-0}" -eq 1 ]; then
    case " $* " in
        *" --config "*) ;;
        *)
            echo 'Error: Cannot find module "@commitlint/config-conventional"' >&2
            exit 1
            ;;
    esac
fi
exit 0
STUB
chmod +x "$REPO/node_modules/.bin/commitlint"
printf '%s\n' '#!/usr/bin/env bash' 'exit 0' > "$TMP_ROOT/wt-bin/node"
chmod +x "$TMP_ROOT/wt-bin/node"

git -C "$REPO" worktree add -q "$TMP_ROOT/linked-wt" -b smoke-worktree

# worktree 안에서 스크립트를 돌린다. node 와 commitlint 은 흉내 낸 것을 쓴다.
run_in_worktree() {
    # $1: 로그 이름, $2...: 스크립트 인자
    local label="$1"
    shift
    (cd "$TMP_ROOT/linked-wt" \
        && COMMITLINT_ARGV="$TMP_ROOT/commitlint.argv" \
            COMMITLINT_STUB_NEEDS_CONFIG=1 \
            PATH="$TMP_ROOT/wt-bin:$PATH" \
            bash tests/check-commit-msg.sh "$@") > "$TMP_ROOT/$label.log" 2>&1
}

if ! run_in_worktree worktree-conventional "$TMP_ROOT/msg.good" --only conventional; then
    cat "$TMP_ROOT/worktree-conventional.log"
    fail "링크된 worktree 에서 commitlint 단계가 실패함"
fi
if ! grep -q '^PASS commitlint' "$TMP_ROOT/worktree-conventional.log"; then
    cat "$TMP_ROOT/worktree-conventional.log"
    fail "링크된 worktree 에서 commitlint 이 SKIP 됨"
fi
grep -Fqx -- '--config' "$TMP_ROOT/commitlint.argv" \
    || fail "주 저장소의 commitlint 설정을 --config 로 넘기지 않음"
grep -Fq 'commitlint.config.mjs' "$TMP_ROOT/commitlint.argv" \
    || fail "--config 값이 주 저장소의 설정 파일이 아님"

# 브랜치가 규칙을 고쳤으면 주 저장소의 규칙으로 통과시키면 안 된다. commitlint 은
# extends 를 설정 파일이 있는 디렉터리에서 풀기 때문에 이 worktree 의 설정을 넘길 수
# 없고, 주 저장소의 설정을 넘기면 브랜치가 선언한 규칙이 아니다. 그래서 검사하지 않는다.
cp "$TMP_ROOT/linked-wt/commitlint.config.mjs" "$TMP_ROOT/wt-config.orig"
printf '%s\n' '// 브랜치가 규칙을 고쳤다' >> "$TMP_ROOT/linked-wt/commitlint.config.mjs"
if ! CI=false run_in_worktree worktree-mismatch-local "$TMP_ROOT/msg.good" --only conventional; then
    cat "$TMP_ROOT/worktree-mismatch-local.log"
    fail "설정 불일치를 로컬에서 SKIP 으로 넘기지 못함"
fi
grep -q 'commitlint(mismatch)' "$TMP_ROOT/worktree-mismatch-local.log" \
    || fail "설정 불일치를 그 이유로 보고하지 않음"
if CI=true run_in_worktree worktree-mismatch-ci "$TMP_ROOT/msg.good" --only conventional; then
    cat "$TMP_ROOT/worktree-mismatch-ci.log"
    fail "설정 불일치를 CI 에서 FAIL 로 올리지 못함"
fi
cp "$TMP_ROOT/wt-config.orig" "$TMP_ROOT/linked-wt/commitlint.config.mjs"

# 주 저장소에 설치는 있는데 설정이 없는 상태. 실행 파일 미설치와 다른 판정이어야 한다.
mv "$REPO/commitlint.config.mjs" "$TMP_ROOT/main-config.orig"
if CI=true run_in_worktree worktree-noconfig "$TMP_ROOT/msg.good" --only conventional; then
    cat "$TMP_ROOT/worktree-noconfig.log"
    fail "설정 파일 없음을 CI 에서 FAIL 로 올리지 못함"
fi
grep -q 'commitlint(config)' "$TMP_ROOT/worktree-noconfig.log" \
    || fail "설정 파일 없음을 실행 파일 미설치와 구분해 보고하지 않음"
mv "$TMP_ROOT/main-config.orig" "$REPO/commitlint.config.mjs"

# CI 범위 모드. 훅이 아니라 CI 가 브랜치 커밋 전부를 다시 보는 경로다.
git_commit --allow-empty -m 'feat(docs): 셸·YAML 설정 정리'
if (cd "$REPO" && bash tests/check-commit-msg.sh --range HEAD~1..HEAD --only notation) \
    > "$TMP_ROOT/commit-range-bad.log" 2>&1; then
    cat "$TMP_ROOT/commit-range-bad.log"
    fail "범위 안의 잘못된 커밋 제목을 FAIL 로 잡지 못함"
fi
grep -q '^FAIL interpunct' "$TMP_ROOT/commit-range-bad.log" \
    || fail "범위 모드가 금지 문자를 그 이유로 지적하지 않음"

git_commit --allow-empty -m 'feat(docs): 셸과 YAML 설정 정리'
if ! (cd "$REPO" && bash tests/check-commit-msg.sh --range HEAD~1..HEAD --only notation) \
    > "$TMP_ROOT/commit-range-good.log" 2>&1; then
    cat "$TMP_ROOT/commit-range-good.log"
    fail "범위 모드가 올바른 커밋 제목을 막음"
fi

# 범위 모드의 conventional 단계. 커밋마다 검사기를 부르는지 본다.
if ! (cd "$REPO" && COMMITLINT_ARGV="$TMP_ROOT/commitlint.argv" PATH="$TMP_ROOT/wt-bin:$PATH" \
    bash tests/check-commit-msg.sh --range HEAD~2..HEAD --only conventional) \
    > "$TMP_ROOT/commit-range-conventional.log" 2>&1; then
    cat "$TMP_ROOT/commit-range-conventional.log"
    fail "범위 모드의 commitlint 단계가 실패함"
fi
if [ "$(grep -c '^PASS ' "$TMP_ROOT/commit-range-conventional.log")" -ne 2 ]; then
    cat "$TMP_ROOT/commit-range-conventional.log"
    fail "범위 모드가 커밋마다 commitlint 을 부르지 않음"
fi

# 빈 범위는 집계에 잡히는 SKIP 이어야 한다. 직접 출력하면 결과 줄에 안 나온다.
if ! (cd "$REPO" && bash tests/check-commit-msg.sh --range HEAD..HEAD --only notation) \
    > "$TMP_ROOT/commit-range-empty.log" 2>&1; then
    cat "$TMP_ROOT/commit-range-empty.log"
    fail "빈 범위를 통과시키지 못함"
fi
grep -q 'SKIP 1' "$TMP_ROOT/commit-range-empty.log" \
    || fail "빈 범위 SKIP 이 결과 집계에 잡히지 않음"

echo "PASS repo-scaffold smoke"
