# 이 저장소의 공개 명령 인터페이스. 사람과 에이전트와 CI 가 모두 여기를 부른다.
#
# 레시피 본문은 스크립트 호출 한 줄이다. 로직은 tests/*.sh 와 scripts/*.sh 에 있다.
# 훅이 같은 스크립트를 직접 부르기 때문이다. 훅 entry 에 just 를 넣으면
# prek -> just -> prek 순환이 된다. tests/check-hooks.sh 가 그것을 기계로 막는다.
#
# just verify 가 Definition of Done 이다. verify 는 prek 를 거치지 않으므로
# prek install 을 하지 않은 새 클론에서도 그대로 돈다.
# prek 를 부르는 것은 check 와 check-fast 둘뿐이다. 그 둘을 check 계열이라 부른다.
#
# 자리표시자 규약: 이 파일에는 스캐폴딩 치환 키를 하나도 두지 않는다.
# just 보간과 치환 키가 같은 중괄호 두 개를 쓰기 때문이다. 보간은 반드시 안쪽에
# 공백을 넣어 쓰고, 중괄호 네 개 이스케이프는 쓰지 않는다.
# scripts/doctor.sh 가 남은 치환 키를 찾아 실패시킨다.
#
# 아직 도입하지 않은 레시피는 주석으로 남겼다. 도입할 때 주석만 벗긴다.
# scripts/run-all.sh 는 Justfile 에 없는 이름을 SKIP 으로 넘기므로
# verify 목록은 도입 전에도 그대로 둘 수 있다.

[unix]
set shell := ["bash", "-euo", "pipefail", "-c"]
[windows]
set shell := ["bash", "-euo", "pipefail", "-c"]

# .env 는 자격 증명 파일이다. 레시피 환경에 자동으로 풀지 않는다.
set dotenv-load := false
set ignore-comments := true
set positional-arguments := true

# scripts/run-all.sh 가 이 값으로 just 를 다시 부른다.
# PATH 에 just 가 없어도(uvx 실행 등) 중첩 호출이 깨지지 않는다.
export JUST := just_executable()

# 인자 없이 just 만 치면 레시피 목록이 나온다.
default:
    @"$JUST" --list --unsorted

# --- 환경 --------------------------------------------------------------------

# 도구, 의존성, git 훅을 설치한다. 클론마다 한 번.
bootstrap:
    bash scripts/bootstrap.sh

# 환경을 진단한다. 무엇이 없고 무엇이 어긋났는지 보고만 한다.
doctor:
    bash scripts/doctor.sh

# --- 고치기 ------------------------------------------------------------------

# 형식을 맞춘다. 파일을 바꾼다.
fmt:
    bash scripts/fmt.sh

# 자동으로 고칠 수 있는 지적을 고친다. 파일을 바꾼다.
fix:
    bash scripts/fix.sh

# --- 검사 --------------------------------------------------------------------

# 정적 분석 전체.
lint:
    bash scripts/run-all.sh lint-shell lint-python lint-yaml

lint-shell:
    bash tests/check-shell.sh

lint-python:
    bash tests/check-python.sh --only lint

lint-yaml:
    bash tests/check-yaml.sh

# 타입 검사. 저장소 전체를 봐야 답이 나오므로 pre-push 다.
type:
    bash tests/check-python.sh --only type

# 마크다운 구조와 형식.
markdown:
    bash tests/check-markdown.sh

# 산문, 용어, 문자 규칙.
prose:
    bash tests/check-prose.sh

# 문서 규약과 인덱스 최신 여부.
docs:
    bash scripts/run-all.sh doc-rules doc-index docs-metadata

doc-rules:
    bash tests/check-docs.sh --only title,placement,paths

doc-index:
    bash scripts/gen-doc-index.sh --check

# front matter 기계 계약, 문서 그래프, 수명주기.
docs-metadata:
    bash tests/check-docs-metadata.sh

# 외부 URL. 네트워크를 타므로 verify 에 넣지 않는다. lychee 는 CI 전용 도구다.
links-external:
    bash tests/check-links-external.sh

# 선언된 도구 버전이 파일마다 같은지.
tool-versions:
    bash tests/check-tool-versions.sh

# 훅 설정 규약.
hooks:
    bash tests/check-hooks.sh

# 브랜치 커밋 메시지 규약. 인자는 base..head 형태의 리비전 범위다.
# commit-msg 훅은 커밋마다 한 건을 보고 CI 는 PR 범위를 한 번에 본다.
# --no-verify 로 넘어간 커밋과 node_modules 가 없던 클론에서 넘어간 커밋이 여기서 걸린다.
# 전체 이력이 필요하므로 CI 는 checkout 에 fetch-depth: 0 을 준다.
commit-range range:
    bash tests/check-commit-msg.sh --range "$1"

# 워크플로 문법과 보안 감사.
workflow-check:
    bash tests/check-workflows.sh

# 라벨 정의와 원격의 드리프트. 읽기만 한다. 만드는 것은 --apply 를 준 같은 스크립트다.
# 네트워크와 gh 인증을 타므로 verify 에 넣지 않는다.
labels-check:
    bash scripts/apply-github-labels.sh --check

# 자격 증명과 .env 키.
security:
    bash scripts/run-all.sh secret-scan env-sync

secret-scan:
    bash tests/check-secrets.sh --all

env-sync:
    bash tests/check-env.sh

# --- 예약 실행 ----------------------------------------------------------------
#
# 달력과 남의 서버에 의존하는 검사다. 훅에도 verify 에도 넣지 않는다.
# 넣으면 자기 변경과 무관한 이유로 커밋과 머지가 막힌다. 예약 CI 가 부른다.

# 검토 주기를 넘긴 문서를 보고한다. WARN 이라 종료 코드를 바꾸지 않는다.
docs-freshness:
    bash tests/check-docs-metadata.sh --only time

# 예약 CI 의 문서 건강 검사. 외부 링크와 검토 주기를 함께 본다.
docs-health:
    bash scripts/run-all.sh links-external docs-freshness

# 테스트 전체. 갈래마다 디렉터리 하나다.
test:
    bash tests/run-tests.sh

test-unit:
    bash tests/run-tests.sh --only unit

test-integration:
    bash tests/run-tests.sh --only integration

test-e2e:
    bash tests/run-tests.sh --only e2e

# --- 묶음 --------------------------------------------------------------------

# Definition of Done. 이것이 통과해야 작업이 끝난 것이다.
verify:
    bash scripts/run-all.sh lint type markdown prose docs hooks tool-versions workflow-check security test

# 훅을 그대로 전부 돌린다. prek 를 부르는 것은 이 레시피와 아래 check-fast 둘뿐이다.
check:
    prek run --all-files

# 느린 훅을 뺀 빠른 확인.
check-fast:
    prek run --all-files --no-group slow
