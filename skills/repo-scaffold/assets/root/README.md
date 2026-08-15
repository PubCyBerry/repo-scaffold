# {{REPO_NAME}}

{{REPO_DESC}}

## 구성

```
{{REPO_NAME}}/
├── docs/                  규칙, 절차, 참고 자료
│   ├── standards/         지켜야 하는 작업 규칙
│   ├── guides/            작업 절차
│   ├── references/        사실 조회용 자료
│   └── generated/         코드나 스키마에서 생성한 정보
├── tests/
│   ├── check-docs.sh      문서 규약, 링크, 경로 검증
│   ├── check-env.sh       .env 와 .env.example 키 동기화 검증
│   └── check-secrets.sh   커밋 대상 자격 증명 스캔
├── scripts/
│   └── gen-doc-index.sh   AGENTS.md 문서 인덱스 생성
├── .pre-commit-config.yaml  커밋 직전 인덱스 갱신과 검증
├── .env.example  →  .env  자격 증명 키 목록
├── AGENTS.md              에이전트 작업 규칙
├── CLAUDE.md              AGENTS.md 를 가리키는 포인터
└── SECURITY.md            자격 증명, 비밀값, 민감정보 취급 규칙
```

## 시작

```bash
# 자격 증명. 취급 규칙은 SECURITY.md 를 먼저 읽습니다
cp .env.example .env        # 값을 채웁니다

# 문서 진입점
cat docs/index.md
```

### pre-commit 훅

커밋 직전에 문서 인덱스를 갱신하고 문서 규약과 자격 증명을 검증합니다. **클론마다 한 번 설치합니다.**
설치하지 않으면 검증이 아예 돌지 않습니다.

```bash
uv venv
uv pip install --python .venv pre-commit
.venv/Scripts/pre-commit install        # 리눅스, macOS 는 .venv/bin/pre-commit
```

pre-commit 은 프로젝트 로컬 `.venv` 에 둡니다. 호스트 전역에 설치하지 않습니다.
전역 `core.hooksPath` 가 설정된 환경이면 설치 시 다음처럼 그 확인만 우회합니다. 전역 설정은 바뀌지 않습니다.

```bash
GIT_CONFIG_GLOBAL=/dev/null .venv/Scripts/pre-commit install
```

| 훅 | 대상 | 하는 일 |
| --- | --- | --- |
| `doc-index` | `*.md`, `*.mdx` | `AGENTS.md` 문서 인덱스를 저장소 상태로 갱신 |
| `doc-rules` | `*.md`, `*.mdx` | front matter, 경로 표기, 문서 간 링크 검증 |
| `env-sync` | 매 커밋 | `.env` 와 `.env.example` 의 키 집합 일치, 비밀 키 값 비움 검증 |
| `secret-scan` | 매 커밋 | staged 내용의 토큰, 사설키 패턴 탐지. 값은 출력하지 않음 |

인덱스가 바뀌면 훅이 `AGENTS.md` 를 스테이징하고 그 커밋을 실패시킵니다. 그대로 다시 커밋하면 됩니다.

`env-sync` 와 `secret-scan` 은 `.env` 가 gitignore 대상이라 변경을 훅이 감지할 수 없으므로 매 커밋 돕니다.
`.env` 가 아직 없으면 SKIP 이라 커밋을 막지 않습니다. 값은 출력하지 않고 키 이름만 다룹니다.

외부 URL 검사는 시간이 걸려 훅에서 제외했습니다. 링크를 새로 넣었으면 직접 돌립니다.

```bash
bash tests/check-docs.sh                     # URL 포함 전체
bash tests/check-secrets.sh --all            # 추적 파일 전체 스캔
.venv/Scripts/pre-commit run --all-files     # 훅 전체를 수동 실행
```

## 문서

| 찾는 것 | 위치 |
| --- | --- |
| 전체 문서 목록 | [docs/index.md](docs/index.md) |
| 지켜야 하는 규칙 | [docs/standards/](docs/standards/index.md) |
| 에이전트 작업 규칙 | [AGENTS.md](AGENTS.md) |
| 자격 증명, 비밀값 취급 | [SECURITY.md](SECURITY.md) |
