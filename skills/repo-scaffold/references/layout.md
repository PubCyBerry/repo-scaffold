# 무엇을 왜 두는가

각 항목이 막는 실패를 적는다. 항목을 빼자는 요구가 나오면 여기 적힌 실패를 감수하는지 확인한다.

## 에이전트 진입점

| 파일 | 막는 실패 |
| --- | --- |
| `AGENTS.md` | 에이전트가 저장소 구조를 추측한다. 있지도 않은 경로를 읽으려 하거나, 규칙 문서를 못 찾고 사전학습 기억으로 답한다 |
| `CLAUDE.md` | 도구마다 다른 파일명을 본다. `@AGENTS.md` 한 줄로 포인터만 두어 내용을 두 벌 유지하지 않는다 |
| `.claude/settings.json` | 매 세션 같은 명령에 권한 프롬프트가 뜬다. `.env` 읽기 deny 로 자격 증명 노출 경로를 하나 줄인다 |

### 문서 인덱스가 AGENTS.md 안에 있는 이유

에이전트는 세션 시작 시 AGENTS.md 를 읽는다. 인덱스를 별도 파일로 빼면 한 번 더 읽어야 하고,
그 한 번을 건너뛰면 탐색이 추측으로 바뀐다.
디렉터리별로 묶어 `|` 로 이은 한 줄 형식은 같은 정보를 트리 형태보다 적은 토큰으로 담는다.

인덱스는 **파일명만** 담는다. 설명은 각 디렉터리 `index.md` 에 있다.
두 층으로 나눠야 인덱스가 커지지 않는다.

### AGENTS.md 에 코드 탐색 도구를 박아 두는 이유

`rg`, `fd`, `ast-grep` 선택 규칙은 규약 문서가 아니라 AGENTS.md 본문에 있다.
에이전트는 탐색을 시작하기 전에 규약 문서를 열어 보지 않는다.
세션마다 읽는 파일에 있어야 실제로 적용된다.
같은 이유로 글쓰기 규약은 AGENTS.md 에서 포인터 한 줄로 가리킨다.
내용은 문서에 두고 진입점만 항상 보이게 한다.

## 문서 체계

| 대상 | 막는 실패 |
| --- | --- |
| `docs/standards/` | 규칙이 코드 리뷰 코멘트로만 존재한다. 근거를 댈 문서가 없어 매번 같은 논쟁을 한다 |
| `docs/guides/` | 절차가 사람 머릿속에만 있다. 실행할 때마다 결과가 달라진다 |
| `docs/references/` | 인프라 주소와 계정 체계를 매번 물어본다 |
| `docs/generated/` | 손으로 쓴 문서와 생성물이 섞인다. 어느 쪽이 원본인지 모른 채 생성물을 고친다 |
| `docs/architecture/` | 왜 이렇게 만들었는지가 아무 데도 안 남는다. 다음 사람이 분석을 다시 하거나, 무엇을 지키던 결정인지 모른 채 뒤집는다 |
| front matter 7개 필수 키 | 본문을 다 읽어야 이 문서가 필요한지 판단이 된다. `summary` 와 `read_when` 이 그 판단을 앞당긴다 |
| `id` 기반 `related` | 파일을 옮기면 참조가 깨진다. `id` 는 경로와 독립이라 안 깨진다 |
| 문서 기준 상대 링크 | 링크 대상과 앵커가 조용히 깨진다. 루트 기준으로 쓰면 검사기가 앵커를 아예 못 본다 |

디렉터리명과 `type` 이 1:1 인 것이 중요하다. 위치만 보고 성격을 알 수 있어야 인덱스 한 줄로 탐색이 끝난다.

### 규약 문서를 14종 미리 까는 이유

빈 `standards/` 는 채워지지 않는다. 규칙을 처음부터 쓰게 하면 아무도 안 쓴다.
문서 작성, 글쓰기, 코드 품질, 테스트, 코드 리뷰, 리뷰 피드백, 커밋, 셸, 파이썬,
GitHub Actions, 이슈 수명주기, 분류 라벨, PR 수명주기, GitHub 강제는
저장소 종류와 무관하게 필요하다. 안 맞는 문서는 지우는 편이 없는 문서를 쓰는 것보다 싸다.

파이썬 문서만 예외처럼 보이지만 아니다. 문서 검사기 자체가 파이썬 파일이라
**모든 스캐폴딩 저장소가 파이썬 파일을 갖는다.** 언어 감지가 거르는 것은 `pyproject.toml`
같은 도구 설정뿐이다.

리뷰 규약을 둘로 나눈 것도 검색 때문이다. `code-review.md` 는 리뷰를 **수행하는** 순서이고
`review-feedback.md` 는 받은 지적을 **분류하고 처리하는** 절차다. 읽는 시점이 다르다.

글쓰기 규약을 문서 작성 규약에서 떼어낸 것은 검색 때문이다.
`documentation.md` 의 `scope` 는 `docs/**` 라 보고서나 코드 주석을 쓰는 상황에는 걸리지 않는다.
`writing-style.md` 는 `scope` 가 전체이고 `read_when` 이 "보고서", "커밋 메시지",
"코드 주석" 을 직접 부른다. 같은 내용이라도 언제 읽어야 하는지가 다르면 문서를 나눈다.

## 명령 레이어

| 파일 | 막는 실패 |
| --- | --- |
| `Justfile` | 무엇을 돌려야 하는지가 사람마다 다르다. 에이전트는 다섯 개를 외우지 못하고 셋만 돌린 뒤 끝났다고 보고한다. 공개 API 를 하나로 줄여 `just verify` 하나가 Definition of Done 이 된다 |
| `scripts/run-all.sh` | just 는 레시피 줄마다 셸을 새로 띄우고 **첫 실패에서 멈춘다.** 그러면 세 줄짜리 `lint` 가 첫 지적만 보여주고, 전부 돌려 집계하는 이 저장소의 관용이 깨진다 |
| `tools.txt` | 도구 버전이 사람마다 다르다. 어제 통과한 것이 오늘 실패하는 이유를 아무도 못 찾는다 |
| `scripts/bootstrap.sh` | 설치 절차가 README 산문에만 있으면 사람마다 다른 상태가 된다. 특히 훅 세 종류 중 하나를 빠뜨린 채 몇 달이 간다 |
| `scripts/doctor.sh` | 무엇이 없어서 SKIP 이 났는지 스스로 물어봐야 한다. 진단이 없으면 SKIP 을 통과로 읽는다 |
| `scripts/tool-help.sh` | 미설치 판정만 나오고 다음 절차가 없다. 사람마다 다른 경로로 도구를 깔아 `tools.txt` 의 고정이 무너진다 |
| `scripts/fmt.sh`, `scripts/fix.sh` | 파일을 바꾸는 명령과 안 바꾸는 명령이 섞인다. 훅이 형식을 고쳐버리면 커밋된 내용이 사람이 본 내용과 달라진다 |
| `package.json`, `commitlint.config.mjs` | 커밋 메시지 규격이 문서에만 있고 아무도 강제하지 않는다 |
| `pyproject.toml` | ruff 와 mypy 한도가 사람마다 다르다. 한도는 `code-quality.md` 의 hard limit 을 기계로 옮긴 것이지 발명한 것이 아니다 |

### 훅 entry 에 `just` 를 넣지 않는 이유

Git 은 prek 를 부르고 prek 는 `tests/*.sh` 를 직접 부른다. 훅 `entry:` 에 `just` 가 들어가면
`prek → just → prek` 순환이 된다. 규약을 주석으로만 두면 다음 사람이 깨므로
`tests/check-hooks.sh` 가 `.pre-commit-config.yaml` 의 `entry:` 를 기계로 검사한다.

같은 이유로 `just verify` 는 prek 를 거치지 않는다. `prek install` 을 안 한 새 클론에서도
Definition of Done 이 돌아야 한다. prek 를 부르는 것은 `check` 계열 둘뿐이다.
`just check` 가 훅 전체이고 `just check-fast` 가 `slow` 그룹을 뺀 것이다.

## 검증

| 파일 | 막는 실패 |
| --- | --- |
| `scripts/gen-doc-index.sh` | 인덱스를 손으로 갱신하면 반드시 낡는다. 낡은 인덱스는 없는 것보다 나쁘다. 에이전트가 그것을 사실로 믿는다 |
| `tests/check-docs.sh` | title 과 본문 H1 이 갈린다. 문서가 위치와 맞지 않는 `type` 을 달고 남는다. 저장소 경로를 백틱으로 써서 링크 검사가 닿지 않는다 |
| `tests/check-docs-metadata.sh` | 규약에 없는 키가 오타로 들어가도 아무도 모른다. 문서가 서술하는 코드가 바뀌어도 문서는 그대로 남아 읽는 사람을 속인다 |
| `schemas/docs-frontmatter.schema.json` | front matter 계약이 검사 스크립트의 정규식 안에만 있다. 기계가 읽을 계약이 없으면 다른 도구가 같은 규약을 재구현한다 |
| `scripts/docs_freshness.py` | 문서가 시간이 지나 낡은 것과 서술 대상이 바뀌어 낡은 것을 구분하지 못한다. 둘은 조치가 다르다 |
| `scripts/docs_graph.py` | `related` 가 없는 id 를 가리키고, 아무도 링크하지 않는 고아 문서가 남는다 |
| `tests/check-markdown.sh` | 제목 구조와 줄 길이가 문서마다 갈린다. 링크 대상과 앵커가 조용히 깨진다 |
| `tests/check-prose.sh` | 같은 것을 두 이름으로 부르고 문체가 문서마다 갈린다. 리뷰로는 매번 다시 지적해야 한다 |
| `tests/check-shell.sh` | 셸 스크립트가 조용히 실패한다. 인용 누락과 미검사 exit code 는 리뷰로 잡히지 않는다 |
| `tests/check-python.sh` | 복잡도와 인자 개수 한도가 문서에만 있다. 리뷰어가 매번 손으로 센다 |
| `tests/run-tests.sh` | 테스트 갈래마다 실행 방법이 달라진다. 훅과 CI 와 사람이 서로 다른 것을 돌린다 |
| `tests/check-yaml.sh` | YAML 형식이 파일마다 갈리고, 워크플로의 키 오타는 push 한 뒤 GitHub 이 알려준다 |
| `tests/check-workflows.sh` | 워크플로가 저장소 자격 증명을 들고 아무도 안 보는 머신에서 돈다. 태그 고정은 업스트림이 태그를 옮기면 무너진다 |
| `tests/check-hooks.sh` | 훅이 `just` 를 불러 순환이 되거나, `default_install_hook_types` 에 없는 스테이지를 선언해 그 훅이 영원히 안 돈다 |
| `tests/check-env.sh` | 키를 추가한 사람만 돌고 다른 사람 환경에서 실행이 깨진다. 원인이 `.env` 라는 것을 찾는 데 시간이 든다 |
| `tests/check-secrets.sh` | 토큰이 커밋에 들어간다. 커밋에 한 번 들어간 값은 이력에 영구히 남는다. 되돌리기가 아니라 폐기가 유일한 대응이다 |
| `tests/check-commit-msg.sh` | 커밋 제목이 사람마다 다른 형식이 된다. 이력에서 무엇이 기능이고 무엇이 수정인지 기계로 고를 수 없다 |
| `tests/check-links-external.sh` | 문서가 가리키는 바깥 페이지가 사라져도 아무도 모른다. 링크는 조용히 죽는다 |
| `.pre-commit-config.yaml` | 검증 스크립트가 있어도 아무도 안 돌린다 |

### 훅을 세 스테이지로 나누는 이유

`default_install_hook_types: [pre-commit, commit-msg, pre-push]` 한 줄이 이 설계에서 가장
조용한 실패 지점이다. 없으면 `prek install` 이 pre-commit 만 깔고 commitlint 와 pre-push
훅 다섯이 몇 달간 한 번도 안 돈다. `tests/check-hooks.sh` 가 이 키와 실제 쓰인 `stages:` 를
대조한다.

pre-push 로 미룬 것은 느려서가 아니다. mypy, 단위 테스트, 문서 그래프, source drift 는
**부분 검사가 틀린 답을 낸다.** 고친 파일만 봐서는 그 파일을 부르는 쪽이 깨진 것을 못 본다.
반대로 `doc-index` 는 파일을 스테이징하므로 pre-commit 이어야 하고, `env-sync` 와
`secret-scan` 은 `.env` 가 gitignore 대상이라 prek 가 변경을 볼 수 없어 `always_run` 이다.

### 실행기가 pre-commit 이 아니라 prek 인 이유

pre-commit 은 파이썬 런타임과 가상환경을 요구한다. 그래서 설치 안내가 `uv venv` 부터 시작하고,
`.venv/Scripts` 와 `.venv/bin` 이 갈리고, 저장소 안에 가상환경이 하나 생긴다.
prek 은 런타임 의존이 없는 단일 바이너리이고 `.pre-commit-config.yaml` 을 그대로 읽는다.
설정을 바꾸지 않고 실행기만 갈아 끼울 수 있다.

### 미설치 판정에 문서 주소와 설치 명령을 함께 내는 이유

판정만 내면 읽는 쪽이 도구 이름으로 검색을 시작하고, 그 검색은 매번 다른 설치 방법으로 끝난다.
그러면 `tools.txt` 가 고정한 버전이 사람마다 갈리고 `doctor.sh` 가 NOTE 로 그것을 보고한다.

`scripts/tool-help.sh` 하나가 도구 이름을 받아 문서 주소와 설치 명령 한두 줄을 낸다.
검사 스크립트는 그것을 부르기만 한다. 안내 문구가 검사 스크립트마다 흩어지면
같은 도구에 서로 다른 설치 명령이 붙는다.

버전은 여기 적지 않고 `tools.txt` 에서 읽는다. 두 곳에 적으면 Renovate 가 한쪽만 올린다.

### 도구가 없을 때 로컬에서 SKIP 하는 이유

`shellcheck`, `shfmt`, `actionlint`, `zizmor`, `rumdl`, `vale`, `yamllint`, `check-jsonschema`,
`ruff`, `mypy` 는 저장소가 배포하는 파일이 아니라 각자 설치하는 도구다.
없다고 커밋을 막으면 그 사람은 `--no-verify` 를 배우고, 그다음부터 모든 훅이 무력화된다.
그래서 로컬에서는 SKIP 으로 보이게만 하고 `CI=true` 인 환경에서 FAIL 로 막는다.
막는 지점을 커밋에서 머지로 옮긴 것이지, 검사를 포기한 것이 아니다.

버전은 `tools.txt` 가 갖고 `scripts/doctor.sh` 가 `uv tool list` 와 대조한다.
**실행 파일의 `--version` 과 대조하지 않는다.** `shellcheck-py==0.11.0.1` 이 까는 바이너리는
자기 버전을 `0.11.0` 이라 답해서 영구 오탐이 된다. uv 밖에서 깐 도구는 고정이 안 걸리고
`doctor.sh` 가 경로만 보고한다. CI 는 전부 uv 로 까므로 CI 는 고정된다.

### `shfmt` 에 형식 플래그를 주지 않는 이유

`shfmt` 는 형식 플래그가 하나라도 붙으면 `.editorconfig` 를 통째로 무시한다.
훅에서 `-i 4`, CI 에서 다른 값을 주면 두 곳의 기준이 조용히 갈린다.
플래그를 아무 데서도 주지 않으면 기준이 `.editorconfig` 하나로 고정된다.

### 훅을 전부 `repo: local` 로 두는 이유

prek 도 pre-commit 과 마찬가지로 `repo:` 에 적힌 훅 저장소를 clone 한다.
커밋마다 원격을 타는 구조를 만들지 않는다. 실제로 도는 코드가 저장소 안에 있으면
리뷰를 받고 버전이 고정되고, 훅이 실패했을 때 무엇을 읽어야 하는지가 파일 경로로 나온다.

`shellcheck` 계열 도구도 같은 이유로 훅 저장소가 아니라 로컬 바이너리로 부른다.
버전은 `tools.txt` 하나가 갖는다.

URL 검사는 훅에서 뺐다. 네트워크 대기가 커밋 체감 속도를 망치면 `--no-verify` 로 이어진다.

**Vale 은 이 보장의 예외다.** PyPI 래퍼가 첫 실행에 GitHub Releases 에서 진짜 실행 파일을 받는다.
그 전에는 `repo: local` 의 보장이 "훅이 항상 **돈다**" 이지 "훅이 항상 **작동한다**" 는
아니게 된다. `tests/check-prose.sh` 가 로컬 SKIP, CI FAIL 로 처리한다.

**commitlint 도 같은 예외다.** `node_modules` 가 없으면 형식 검사가 계속 SKIP 된다.
그래서 `tests/check-commit-msg.sh` 는 두 단계로 나뉜다. 형식은 commitlint 가 보고, 제목의 금지
문자는 bash 가 직접 본다. 뒤쪽은 도구가 없어도 돌아서 규약 하나는 살아 있다.
훅은 `node_modules/.bin/commitlint` 를 직접 부른다. `npx` 는 커밋마다 네트워크를 타고
그때마다 무엇이 실행될지가 원격에 달려 있다.

### gitleaks 와 lychee 를 로컬에 요구하지 않는 이유

둘 다 PyPI 밖 도구라 `uv tool install` 로 깔리지 않고, 권위 있는 답을 내려면 전체 이력이나
네트워크가 필요하다. 개발자 머신에 요구하면 `just verify` 가 각자 손으로 깐 도구에 의존하게 된다.
CI 에 두면 버전이 고정되고 실행 환경이 하나다.

설정 파일은 그래도 저장소에 둔다. `.gitleaks.toml` 과 `lychee.toml` 이 없으면 CI 가 기본 설정으로
돌고, 그러면 예외 목록이 워크플로 파일 안에 흩어져 로컬에서 재현할 수 없게 된다.

로컬이 비는 것은 아니다. 자격 증명은 의존성 없는 `tests/check-secrets.sh` 가 매 커밋 보고,
`gitleaks` 가 어쩌다 PATH 에 있으면 같은 스크립트가 한 층 더 얹는다.
없다고 FAIL 로 올리지 않는다. 그 자리는 CI 의 전용 잡이 채운다.

### 링크를 문서 기준 상대 경로로 쓰는 이유

rumdl 의 cross-file 앵커 검사(MD051)는 링크 대상을 링크가 있는 문서의 디렉터리 기준으로만 해석한다.
설정으로 바꿀 수 없고, 대상 파일을 못 찾으면 조용히 건너뛴다. 저장소 루트 기준으로 쓰면
루트 문서 밖에서는 앵커 검사가 영원히 0% 이고, 그 사실이 출력에 드러나지도 않는다.
대가는 문서를 옮길 때 링크를 같이 고쳐야 하는 것이고, 그것은 검사가 잡아준다.

같은 이유로 `tests/check-markdown.sh` 는 바뀐 파일이 아니라 저장소 전체를 rumdl 에 넘긴다.
파일 하나만 넘기면 색인에 그 파일뿐이라 cross-file 앵커가 전부 미검사가 된다.

### Vale 규칙을 언어별 디렉터리로 나누는 이유

`styles/Project/` 는 문자 규칙이라 정규식이 `raw` 이고 언어와 무관하다.
낱말 규칙은 다르다. `styles/English/` 를 한국어 문서에 걸면 이 저장소의 명령 실행기 이름인
`just` 가 영어 완충어 목록에 있어 매 커밋 오탐이 난다. 어느 파일에 어느 스타일을 거는지는
`.vale.ini` 가 정한다.

한국어 규칙은 전부 `nonword: true` 또는 `raw:` 를 쓴다. Vale 의 기본 낱말 경계는 ASCII 전용이라
조사가 붙은 형태에서 발화하지 않는다. 빠뜨리면 초록 불이 곧 미검사라는 뜻이 된다.

### `doc-index` 훅이 커밋을 실패시키는 이유

pre-commit 프레임워크 규약이다. 훅이 파일을 고쳤으면 커밋 내용이 사용자가 확인한 것과 달라진다.
조용히 통과시키면 무엇이 커밋됐는지 모르게 된다. 그대로 다시 커밋하면 된다.

## GitHub

| 파일 | 막는 실패 |
| --- | --- |
| `.github/workflows/{quality,test,security,docs-health}.yml` | 훅을 안 깐 사람과 `--no-verify` 를 쓴 사람의 변경이 아무 검사도 없이 머지된다. CI 는 훅을 신뢰하지 않고 독립 재검증한다 |
| `.github/workflows/pr-policy.yml` | squash 머지가 **PR 제목으로 커밋을 합성**하므로 commitlint 가 그 문자열을 영원히 못 본다. 그 구멍을 PR 제목 재검사로 막는다 |
| `.github/workflows/stale-needs-info.yml` | 정보를 기다리는 이슈가 영원히 열려 있고, 무엇이 살아 있는 작업인지 목록만 봐서는 알 수 없다 |
| `.github/labels.yml` | 라벨이 없으면 **Issue Form 이 라벨을 조용히 버린다.** 수명주기가 아예 시작되지 않고 아무 경고도 없다 |
| `.github/ISSUE_TEMPLATE/` | 이슈에 재현 절차와 범위가 빠진 채 들어온다. 되묻는 왕복이 기본값이 된다 |
| `.github/pull_request_template.md` | PR 본문이 사람마다 다르다. 리뷰어가 무엇을 봐야 하는지 매번 물어본다 |
| `.github/CODEOWNERS.example` | 리뷰 요청이 아무에게도 안 간다. 예제로만 까는 것은 실제 핸들을 스크립트가 알 수 없기 때문이다 |
| `.github/rulesets/` | 규칙이 저장소 설정 화면 안에만 있어 이력도 리뷰도 없다. 기본 예제가 1인 저장소를 가정하는 이유는 team 설정이 **1인 저장소에서 본인 PR 을 영원히 못 머지하게** 만들기 때문이다 |
| `renovate.json` | 의존성이 고정된 채 썩는다. Dependabot 은 Alerts 만 켜고 갱신 PR 은 Renovate 하나가 낸다. 둘 다 켜면 같은 갱신에 PR 이 두 개 온다 |

룰셋과 CODEOWNERS 와 라벨은 **원격을 바꾸는 일**이라 스캐폴딩이 직접 하지 않는다.
`scripts/apply-github-*.sh` 는 인자 없이 부르면 dry-run 이고 `--apply` 를 줘야 실제로 바꾼다.
잘못 걸면 기본 브랜치가 잠기는데, 그 복구는 사람만 할 수 있다.

## 파일 형식과 도구 설정

| 파일 | 막는 실패 |
| --- | --- |
| `.gitattributes` | Windows 와 리눅스가 섞인 팀에서 줄바꿈 때문에 전체 파일 diff 가 뜬다. CRLF 로 저장된 `.sh` 는 실행이 깨진다 |
| `.editorconfig` | 커밋 시점은 `.gitattributes` 가 잡지만 편집 시점은 못 잡는다. 저장할 때마다 왕복 변환이 일어난다. `shfmt` 의 형식 기준도 여기서 읽는다 |
| `.gitignore` | `.env` 가 커밋된다. 빌드 산출물이 diff 를 덮는다 |
| `.env.example` | 어떤 환경변수가 필요한지 아무도 모른다. 새로 합류한 사람이 실행에 실패한다 |
| `SECURITY.md` | 자격 증명 취급 판단이 사람마다 다르다. 에이전트도 근거 없이 추측한다 |
| `.shellcheckrc` | 셸 검사 강도가 사람마다 다르다. CI 에서만 나는 지적이 생긴다 |
| `.yamllint.yaml` | YAML 형식 기준이 없어 들여쓰기와 줄 길이가 파일마다 갈린다 |
| `.rumdl.toml` | 마크다운 기준이 도구 기본값이 된다. 줄 길이 80 과 `.editorconfig` 의 100 이 어긋난다 |
| `.vale.ini`, `styles/` | 산문 규칙이 리뷰 코멘트로만 존재한다. 같은 지적을 사람이 매번 다시 한다 |
| `.gitleaks.toml`, `lychee.toml` | 도구는 CI 전용인데 설정이 없으면 워크플로 안에 예외 목록이 흩어져 로컬에서 재현할 수 없다 |

`.env.example` 에 값을 적지 않는 것이 규칙이다. 커밋되는 파일이라 값을 적는 순간 유출이다.
`check-env.sh` 가 `TOKEN`, `KEY`, `SECRET`, `PASSWORD` 계열 키의 값이 비어 있는지 본다.

`.shellcheckrc` 에 `enable=quote-safe-variables` 를 **일부러 넣지 않았다.** 신규 템플릿은 전부
통과하지만 기존 저장소의 셸이 SC2248 로 도배돼 첫날부터 `just lint` 가 빨개진다.
그 상태는 규칙을 지키게 만들지 않고 검사를 끄게 만든다. 켜고 싶으면 나중에 켠다.

## 알려진 한계

이 설계가 못 하는 것들이다. 모르고 부딪히는 것보다 적어두는 편이 싸다.

| 한계 | 무슨 일이 일어나나 |
| --- | --- |
| `just verify` 와 훅이 갈릴 수 있다 | `verify` 가 prek 를 우회하므로 어느 한쪽에만 있는 검사가 생길 수 있다. `just check` 로 대조한다. 자동 parity 검사는 넣지 않았다 |
| uv 밖에서 깐 도구는 버전이 안 잡힌다 | `apt install shellcheck` 는 `uv tool list` 에 없어 `doctor.sh` 가 경로만 보고하고 통과시킨다 |
| Windows 는 Git Bash 가 필수다 | Git for Windows 기본 설치는 `Git\cmd` 만 PATH 에 넣고 `bash.exe` 가 없다. `doctor.sh` 가 해석된 bash 를 출력한다 |
| `node_modules` 가 없으면 commitlint 는 SKIP 이다 | `repo: local` 의 보장은 "훅이 항상 **돈다**" 이지 "항상 **작동한다**" 가 아니다. Vale 도 같은 예외다 |
| 한국어 맞춤법은 검사하지 않는다 | Vale 로 불가능함이 소스 수준에서 확인됐다. `writing-style.md` 가 사람용 정책으로 남는다 |
