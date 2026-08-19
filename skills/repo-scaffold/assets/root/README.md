# {{REPO_NAME}}

{{REPO_DESC}}

## 구성

```text
{{REPO_NAME}}/
├── docs/                  규칙, 절차, 참고 자료. 영어로 쓴다
│   ├── standards/         지켜야 하는 작업 규칙
│   ├── guides/            작업 절차
│   ├── references/        사실 조회용 자료
│   ├── generated/         코드나 스키마에서 생성한 정보
│   └── architecture/      시스템 구조. adr/ 는 결정 기록
├── schemas/               front matter 의 기계 계약 (JSON Schema)
├── styles/                Vale 산문 규칙. Project(문자), English, Korean
├── tests/
│   ├── check-docs.sh      title 과 H1, 위치와 type, 백틱 경로 검증
│   ├── check-docs-metadata.sh  front matter 스키마, 문서 그래프, 수명주기
│   ├── check-links-external.sh 외부 URL. 네트워크를 탄다
│   ├── check-markdown.sh  마크다운 구조와 형식
│   ├── check-prose.sh     산문, 용어, 문자 규칙
│   ├── check-shell.sh     셸 스크립트 shellcheck, shfmt 검사
│   ├── check-yaml.sh      YAML yamllint, 워크플로와 Renovate 스키마 검사
│   ├── check-workflows.sh 워크플로 actionlint, zizmor 검사
│   ├── check-hooks.sh     훅 설정 규약 검증
│   ├── check-tool-versions.sh  선언된 도구 버전 대조
│   ├── check-commit-msg.sh 커밋 메시지 규약 검증
│   ├── check-env.sh       .env 와 .env.example 키 동기화 검증
│   ├── check-secrets.sh   커밋 대상 자격 증명 스캔
│   └── unit/              문서 검사기 단위 테스트와 fixture
├── scripts/
│   ├── bootstrap.sh       도구, 의존성, git 훅 설치
│   ├── doctor.sh          환경 진단
│   ├── tool-help.sh       도구별 문서 주소와 설치 명령
│   ├── fmt.sh             형식 정리
│   ├── fix.sh             자동 수정
│   ├── run-all.sh         레시피 여러 개를 끝까지 돌리고 집계
│   ├── gen-doc-index.sh   AGENTS.md 문서 인덱스 생성
│   ├── docs_freshness.py  문서 수명주기. 시간과 source drift
│   ├── docs_graph.py      문서 그래프. id, 참조, 대체 관계, 고아 문서
│   ├── check_pr_metadata.py  PR 제목, 필수 절, 이슈 연결 계약
│   ├── apply-github-labels.sh  라벨 반영. 기본은 dry-run
│   └── apply-github-repository-settings.sh  머지 설정 반영. 기본은 dry-run
├── .github/
│   ├── workflows/         CI. 잡 이름이 룰셋의 required check 이름이다
│   ├── ISSUE_TEMPLATE/    이슈 폼 3종과 설정
│   ├── pull_request_template.md  PR 필수 9개 절
│   ├── labels.yml         라벨 정의의 단일 출처
│   ├── CODEOWNERS.example 복사해서 실제 핸들로 바꾼다
│   └── rulesets/          기본 브랜치 룰셋 예제. 기본값과 team
├── Justfile                 명령 인터페이스. `just verify` 가 Definition of Done
├── tools.txt                개발 도구와 버전의 단일 출처
├── package.json  package-lock.json  commitlint 하나. Node 는 도구 의존성이다
├── commitlint.config.mjs    커밋 메시지 형식 규칙
├── .pre-commit-config.yaml  커밋과 푸시 직전 검증
├── .rumdl.toml              마크다운 구조와 형식 규칙
├── .vale.ini                산문과 용어 규칙
├── .editorconfig            편집기와 shfmt 의 형식 기준
├── .shellcheckrc            shellcheck 의 source 해석 설정
├── .yamllint.yaml           yamllint 의 형식 기준
├── .gitleaks.toml           자격 증명 스캔 규칙. 도구는 CI 전용
├── lychee.toml              외부 URL 검사 규칙. 도구는 CI 전용
├── .env.example  →  .env  자격 증명 키 목록
├── AGENTS.md              에이전트 작업 규칙
├── CLAUDE.md              AGENTS.md 를 가리키는 포인터
└── SECURITY.md            자격 증명, 비밀값, 민감정보 취급 규칙
```

## 시작

전제조건은 [uv](https://docs.astral.sh/uv) 와 bash 다. Windows 에서는 Git Bash 가 필요하다.
Git for Windows 기본 설치는 `Git\cmd` 만 PATH 에 넣고 `bash.exe` 를 넣지 않으므로 확인한다.

```bash
uv tool install rust-just   # just 하나만 손으로 깐다
just bootstrap              # 나머지 도구, 의존성, git 훅. 클론마다 한 번
just doctor                 # 환경 진단. 무엇이 없고 무엇이 어긋났는지
just verify                 # 검사 전체
```

`just` 를 인자 없이 치면 레시피 목록이 나온다.

```bash
cp .env.example .env        # 자격 증명. 취급 규칙은 SECURITY.md 를 먼저 읽는다
cat docs/index.md           # 문서 진입점
```

### 명령

| 명령 | 하는 일 |
| --- | --- |
| `just bootstrap` | 도구, 의존성, git 훅 설치. 클론마다 한 번 |
| `just doctor` | 환경 진단 |
| `just verify` | **Definition of Done.** 검사 전체 |
| `just fmt` | 형식 정리. 파일을 바꾼다 |
| `just fix` | 자동으로 고칠 수 있는 지적 수정. 파일을 바꾼다 |
| `just markdown` | 마크다운 구조와 형식 |
| `just prose` | 산문, 용어, 문자 규칙 |
| `just docs` | 문서 규약, 인덱스 최신 여부, front matter 계약과 수명주기 |
| `just markdown` | 마크다운 구조와 형식, 링크 대상, 앵커 |
| `just links-external` | 외부 URL. 네트워크를 탄다. `just verify` 에 없다 |
| `just security` | 자격 증명 스캔과 `.env` 키 검증 |
| `just labels-check` | `.github/labels.yml` 과 원격 라벨의 차이. 읽기만 한다 |
| `just check` | 훅 전체를 손으로 실행 |

`just verify` 는 훅 실행기를 거치지 않는다. 훅을 설치하지 않은 새 클론에서도 그대로 돈다.
훅과 `just verify` 를 대조하려면 `just check` 를 쓴다.

### 커밋 훅

훅 실행기는 [prek](https://prek.j178.dev) 다. pre-commit 의 Rust 재구현이고 설정 파일 형식이 같다.
런타임 의존이 없는 단일 바이너리라 프로젝트 안에 `.venv` 를 만들지 않아도 된다.

`just bootstrap` 이 `pre-commit`, `commit-msg`, `pre-push` 세 종류를 한 번에 설치한다.
**설치하지 않으면 검증이 아예 돌지 않는다.**
무엇이 어느 시점에 도는지는 `.pre-commit-config.yaml` 에 있다.

| 시점 | 대상 |
| --- | --- |
| `pre-commit` | 파일 단위로 빠르게 끝나는 검사. 문서, 마크다운, 산문, 셸, 워크플로, 자격 증명 |
| `commit-msg` | 커밋 메시지 규약 |
| `pre-push` | 저장소 전체를 봐야 답이 나오는 검사. 문서 그래프, 문서 source drift |

전역 `core.hooksPath` 가 설정된 환경이라 설치가 거부되면 다음처럼 그 확인만 우회한다.
전역 설정은 바뀌지 않는다.

```bash
GIT_CONFIG_GLOBAL=/dev/null prek install --hook-type pre-commit --hook-type commit-msg --hook-type pre-push
```

문서 인덱스가 바뀌면 훅이 `AGENTS.md` 를 스테이징하고 그 커밋을 실패시킨다. 그대로 다시 커밋한다.

`.env` 는 gitignore 대상이라 변경을 훅이 감지할 수 없으므로 관련 훅은 매 커밋 돈다.
`.env` 가 아직 없으면 SKIP 이라 커밋을 막지 않는다. 값은 출력하지 않고 키 이름만 다룬다.

훅 저장소는 쿨다운을 두고 갱신한다. 갓 나온 릴리스를 그날 바로 받지 않기 위해서다.

```bash
prek update --cooldown-days 7
```

### 도구

버전은 `tools.txt` 한 곳에 있고 `just bootstrap` 이 그대로 깐다. 손으로 올리지 않는다.
검사 스크립트가 부르는 도구가 없으면 로컬에서는 SKIP 이고 CI 에서는 FAIL 이다.

`shfmt` 의 형식 기준은 `.editorconfig` 다. 명령줄에 형식 플래그를 주면 `.editorconfig` 가 무시되므로
훅, CI, 손으로 돌릴 때 모두 플래그 없이 부른다.

마크다운은 `rumdl` 이 본다. 훅은 `rumdl check` 만 부르고 파일을 바꾸지 않는다.
자동 수정은 `just fmt` 가 `rumdl fmt` 로 한다.

산문은 `Vale` 이 본다. 자리는 산문 정책 검사기와 용어 검사기 둘이다.
문법 검사기도, 글 품질 평가기도, **맞춤법 검사기도 아니다.**
특히 한국어 맞춤법은 Vale 로 검사할 수 없다.
규칙은 `styles/` 에 있고 사람이 읽는 원본은
[docs/standards/writing-style.md](docs/standards/writing-style.md) 다.
Vale 은 첫 실행에 네트워크로 실행 파일을 받는다. 받기 전에는 로컬 SKIP 이고 CI 에서는 FAIL 이다.

문서 수명주기는 `scripts/docs_freshness.py` 와 `scripts/docs_graph.py` 가 본다.
PEP-723 인라인 메타데이터를 갖고 `uv run --script` 로 돌아서 `pyproject.toml` 이 없어도 되고
의존성도 없다. front matter 의 `sources` 에 적힌 경로가 `last_reviewed` 이후에 바뀌면
push 를 막는다. 시간이 흘러 낡은 것은 경고만 하고 막지 않는다. `last_reviewed` 는 사람이
문서를 다시 읽었을 때만 손으로 올린다.

커밋 메시지 형식은 `commitlint` 이 본다. 규칙은 `commitlint.config.mjs` 이고 사람이 읽는 원본은
[docs/standards/commit-convention.md](docs/standards/commit-convention.md) 다.
버전은 `package.json` 과 `package-lock.json` 에 있고 `just bootstrap` 이 `npm ci` 로 깐다.
Node 는 도구 의존성이지 소스 언어가 아니므로 언어 감지와 무관하게 항상 배치한다.
훅은 `node_modules/.bin/commitlint` 을 직접 부른다. `npx` 는 훅 안에서 네트워크를 타므로 쓰지 않는다.
`node_modules` 는 gitignore 대상이라 링크된 worktree 에는 없다. 그래서 현재 worktree 에서 못 찾으면
주 저장소의 것을 `--config` 와 함께 부른다. 다만 `commitlint` 은 `extends` 를 설정 파일이 있는
디렉터리에서 풀기 때문에, 두 설정 파일의 내용이 같을 때만 빌려 쓴다. 다르면 주 저장소 규칙으로
통과시키지 않고 이유를 적어 로컬 SKIP, CI FAIL 로 남긴다. 그때도 제목 표기 검사는 그대로 돈다.
훅은 커밋 한 건을 보고 CI 는 `just commit-range "<base>..HEAD"` 로 브랜치 커밋 전부를 다시 본다.
`prek run --all-files` 는 `commit-msg` 스테이지 훅을 돌리지 않으므로 CI 검사가 따로 필요하다.

`gitleaks`, `lychee`, `osv-scanner` 는 **CI 전용 도구**라 `tools.txt` 에 없다.
PyPI 밖 도구이고 네트워크나 전체 이력이 필요해서 개발자 머신에 요구하지 않는다.
설정 파일(`.gitleaks.toml`, `lychee.toml`)은 저장소에 두어 CI 와 어쩌다 깔려 있는
개발자 머신이 같은 규칙을 쓰게 한다. `just security` 는 의존성 없는 스캔을 항상 돌리고
`gitleaks` 가 PATH 에 있을 때만 한 층 더 얹는다. 없어도 실패로 치지 않는다.

외부 URL 검사는 시간이 걸려 훅과 `just verify` 에서 뺐다. 링크를 새로 넣었으면 직접 돌린다.

```bash
just links-external                          # lychee. 없으면 SKIP, CI 에서는 FAIL
bash tests/check-docs.sh                     # title, 위치, 백틱 경로
bash tests/check-docs-metadata.sh            # front matter 계약, 그래프, 수명주기
bash tests/check-secrets.sh --all            # 추적 파일 전체 스캔
```

### GitHub 거버넌스

`.github/` 의 이슈 폼, PR 템플릿, 룰셋 예제는 깔린 상태로는 아무 일도 하지 않는다.
라벨을 먼저 만들고, 머지 설정을 맞추고, 룰셋을 골라 걸어야 동작한다.
순서와 이유는 [docs/guides/github-governance-setup.md](docs/guides/github-governance-setup.md) 다.

원격을 바꾸는 스크립트 둘은 인자 없이 부르면 무엇이 바뀔지만 보여준다.
실제로 바꾸는 것은 `--apply` 를 줬을 때뿐이다.

```bash
bash scripts/apply-github-labels.sh                       # 차이만 본다
bash scripts/apply-github-labels.sh --apply               # 라벨을 만들고 고친다
bash scripts/apply-github-repository-settings.sh          # 현재 값과 의도한 값
bash scripts/apply-github-repository-settings.sh --apply  # 머지 설정을 반영한다
```

라벨이 없으면 세 가지가 조용히 깨진다. 이슈 폼은 없는 라벨을 오류 없이 버리고,
stale 워크플로는 아무것도 매칭하지 못한 채 매일 초록으로 끝나며, `pr-policy` 는
`policy/skip-issue` 를 붙일 수 없어 사소한 PR 을 전부 막는다.

브랜치 룰셋은 어떤 스크립트도 걸지 않는다. 잘못 걸면 기본 브랜치가 잠기고
푸는 데 같은 관리자 권한이 필요하다. 기본 예제가 1 인 저장소용이다.
`team` 예제는 승인 1 건과 코드 소유자 승인을 요구해서 혼자서는 아무것도 머지하지 못한다.

## 문서

| 찾는 것 | 위치 |
| --- | --- |
| 전체 문서 목록 | [docs/index.md](docs/index.md) |
| 지켜야 하는 규칙 | [docs/standards/](docs/standards/index.md) |
| 에이전트 작업 규칙 | [AGENTS.md](AGENTS.md) |
| 자격 증명, 비밀값 취급 | [SECURITY.md](SECURITY.md) |
