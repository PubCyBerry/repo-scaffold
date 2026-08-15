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
expect_failure "$TMP_ROOT/missing-timeout.log" bash "$REPO/tests/check-docs.sh" --timeout

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
run_self_check check-docs.sh --no-net
run_self_check check-shell.sh
run_self_check check-workflows.sh
run_self_check check-env.sh
run_self_check check-secrets.sh

# --help 은 헤더 주석만 낸다. 저장소 루트가 아닌 곳에서 상대 경로로 불러도 자기 파일을 찾아야 한다.
# 스크립트가 REPO_ROOT 로 cd 한 뒤 상대 BASH_SOURCE 를 읽으면 여기서 걸린다.
for script in check-docs.sh check-shell.sh check-workflows.sh check-env.sh check-secrets.sh; do
    if ! (cd "$REPO/docs" && bash "../tests/$script" --help) > "$TMP_ROOT/help-$script.log" 2>&1; then
        cat "$TMP_ROOT/help-$script.log"
        fail "$script --help 가 실패함"
    fi
    if ! grep -q '^# 종료 코드' "$TMP_ROOT/help-$script.log"; then
        cat "$TMP_ROOT/help-$script.log"
        fail "$script --help 가 헤더 주석을 출력하지 못함"
    fi
    if grep -q 'set -uo pipefail' "$TMP_ROOT/help-$script.log"; then
        fail "$script --help 가 헤더 주석을 넘어 코드까지 출력함"
    fi
done

echo "PASS repo-scaffold smoke"
