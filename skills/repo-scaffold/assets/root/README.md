# {{REPO_NAME}}

{{REPO_DESC}}

## 구성

```
{{REPO_NAME}}/
├── docs/                  규칙, 절차, 참고 자료. 영어로 작성합니다
│   ├── standards/         지켜야 하는 작업 규칙
│   ├── guides/            작업 절차
│   ├── references/        사실 조회용 자료
│   └── generated/         코드나 스키마에서 생성한 정보
├── tests/
│   ├── check-docs.sh      문서 규약, 링크, 경로 검증
│   ├── check-shell.sh     셸 스크립트 shellcheck, shfmt 검사
│   ├── check-workflows.sh 워크플로 actionlint, zizmor 검사
│   ├── check-hooks.sh     훅 설정 규약 검증
│   ├── check-env.sh       .env 와 .env.example 키 동기화 검증
│   └── check-secrets.sh   커밋 대상 자격 증명 스캔
├── scripts/
│   ├── bootstrap.sh       도구, 의존성, git 훅 설치
│   ├── doctor.sh          환경 진단
│   ├── fmt.sh             형식 정리
│   ├── fix.sh             자동 수정
│   ├── run-all.sh         레시피 여러 개를 끝까지 돌리고 집계
│   └── gen-doc-index.sh   AGENTS.md 문서 인덱스 생성
├── Justfile                 명령 인터페이스. `just verify` 가 Definition of Done
├── tools.txt                개발 도구와 버전의 단일 출처
├── .pre-commit-config.yaml  커밋과 푸시 직전 검증
├── .editorconfig            편집기와 shfmt 의 형식 기준
├── .env.example  →  .env  자격 증명 키 목록
├── AGENTS.md              에이전트 작업 규칙
├── CLAUDE.md              AGENTS.md 를 가리키는 포인터
└── SECURITY.md            자격 증명, 비밀값, 민감정보 취급 규칙
```

## 시작

전제조건은 [uv](https://docs.astral.sh/uv) 와 bash 입니다. Windows 에서는 Git Bash 가 필요합니다.
Git for Windows 기본 설치는 `Git\cmd` 만 PATH 에 넣고 `bash.exe` 를 넣지 않으므로 확인이 필요합니다.

```bash
uv tool install rust-just   # just 하나만 손으로 깝니다
just bootstrap              # 나머지 도구, 의존성, git 훅. 클론마다 한 번
just doctor                 # 환경 진단. 무엇이 없고 무엇이 어긋났는지
just verify                 # 검사 전체
```

`just` 를 인자 없이 치면 레시피 목록이 나옵니다.

```bash
cp .env.example .env        # 자격 증명. 취급 규칙은 SECURITY.md 를 먼저 읽습니다
cat docs/index.md           # 문서 진입점
```

### 명령

| 명령 | 하는 일 |
| --- | --- |
| `just bootstrap` | 도구, 의존성, git 훅 설치. 클론마다 한 번 |
| `just doctor` | 환경 진단 |
| `just verify` | **Definition of Done.** 검사 전체 |
| `just fmt` | 형식 정리. 파일을 바꿉니다 |
| `just fix` | 자동으로 고칠 수 있는 지적 수정. 파일을 바꿉니다 |
| `just docs` | 문서 규약과 인덱스 최신 여부 |
| `just links-internal` | 저장소 안 링크와 문서 그래프 |
| `just security` | 자격 증명 스캔과 `.env` 키 검증 |
| `just check` | 훅 전체를 손으로 실행 |

`just verify` 는 훅 실행기를 거치지 않습니다. 훅을 설치하지 않은 새 클론에서도 그대로 돕니다.
훅과 `just verify` 를 대조하려면 `just check` 를 씁니다.

### 커밋 훅

훅 실행기는 [prek](https://prek.j178.dev) 입니다. pre-commit 의 Rust 재구현이고 설정 파일 형식이 같습니다.
런타임 의존이 없는 단일 바이너리라 프로젝트 안에 `.venv` 를 만들지 않아도 됩니다.

`just bootstrap` 이 `pre-commit`, `commit-msg`, `pre-push` 세 종류를 한 번에 설치합니다.
**설치하지 않으면 검증이 아예 돌지 않습니다.** 무엇이 어느 시점에 도는지는 `.pre-commit-config.yaml` 에 있습니다.

| 시점 | 대상 |
| --- | --- |
| `pre-commit` | 파일 단위로 빠르게 끝나는 검사. 문서 규약, 링크, 셸, 워크플로, 훅 설정, 자격 증명 |
| `commit-msg` | 커밋 메시지 규약 |
| `pre-push` | 저장소 전체를 봐야 답이 나오는 검사. 문서 그래프 |

전역 `core.hooksPath` 가 설정된 환경이라 설치가 거부되면 다음처럼 그 확인만 우회합니다. 전역 설정은 바뀌지 않습니다.

```bash
GIT_CONFIG_GLOBAL=/dev/null prek install --hook-type pre-commit --hook-type commit-msg --hook-type pre-push
```

문서 인덱스가 바뀌면 훅이 `AGENTS.md` 를 스테이징하고 그 커밋을 실패시킵니다. 그대로 다시 커밋하면 됩니다.

`.env` 는 gitignore 대상이라 변경을 훅이 감지할 수 없으므로 관련 훅은 매 커밋 돕니다.
`.env` 가 아직 없으면 SKIP 이라 커밋을 막지 않습니다. 값은 출력하지 않고 키 이름만 다룹니다.

훅 저장소는 쿨다운을 두고 갱신합니다. 갓 나온 릴리스를 그날 바로 받지 않기 위해서입니다.

```bash
prek update --cooldown-days 7
```

### 도구

버전은 `tools.txt` 한 곳에 있고 `just bootstrap` 이 그대로 깝니다. 손으로 올리지 않습니다.
검사 스크립트가 부르는 도구가 없으면 로컬에서는 SKIP 이고 CI 에서는 FAIL 입니다.

`shfmt` 의 형식 기준은 `.editorconfig` 입니다. 명령줄에 형식 플래그를 주면 `.editorconfig` 가 무시되므로
훅, CI, 손으로 돌릴 때 모두 플래그 없이 부릅니다.

외부 URL 검사는 시간이 걸려 훅에서 제외했습니다. 링크를 새로 넣었으면 직접 돌립니다.

```bash
bash tests/check-docs.sh                     # URL 포함 전체
bash tests/check-secrets.sh --all            # 추적 파일 전체 스캔
```

## 문서

| 찾는 것 | 위치 |
| --- | --- |
| 전체 문서 목록 | [docs/index.md](docs/index.md) |
| 지켜야 하는 규칙 | [docs/standards/](docs/standards/index.md) |
| 에이전트 작업 규칙 | [AGENTS.md](AGENTS.md) |
| 자격 증명, 비밀값 취급 | [SECURITY.md](SECURITY.md) |
