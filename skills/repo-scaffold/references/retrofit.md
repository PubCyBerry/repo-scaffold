# 기존 저장소에 얹기

이미 파일이 있는 저장소에 적용할 때만 읽는다. 빈 저장소면 [SKILL.md](SKILL.md) 절차로 충분하다.

## 원칙

스크립트는 기존 파일을 건드리지 않는다. `SKIP` 으로 보고만 하고 넘어간다.
**병합은 사람이 판단할 일이다.** 에이전트가 임의로 기존 규약을 덮지 않는다.

## 진단

```bash
SKILL_DIR="$HOME/.claude/skills/repo-scaffold"
bash "$SKILL_DIR/assets/scaffold.sh" --target /path/to/repo --dry-run
```

`PLAN` 이 빠진 규약, `SKIP` 이 이미 있는 규약이다. 이 목록을 그대로 사용자에게 보고한다.

## SKIP 항목 처리

| 이미 있는 파일 | 확인할 것 |
| --- | --- |
| `AGENTS.md` | `<!-- DOC-INDEX:START -->` 와 `<!-- DOC-INDEX:END -->` 두 줄이 있는가. 없으면 인덱스 생성이 실패한다 |
| `.gitattributes` | `* text=auto eol=lf` 와 `*.sh text eol=lf` 가 있는가 |
| `.gitignore` | `.env` 가 있는가. 없으면 이미 커밋됐는지부터 확인한다 |
| `.pre-commit-config.yaml` | 기존 훅과 `repos: - repo: local` 블록을 합친다. 훅 id 가 겹치면 안 된다 |
| `.env.example` | 실제 `.env` 와 키 집합이 같은가. `check-env.sh` 로 확인한다 |
| `docs/` | 디렉터리명이 `standards`, `guides`, `references`, `generated` 와 다르면 `check-docs.sh` 의 `expected_type` 이 빈 값을 돌려주고 type 검사를 건너뛴다 |

### AGENTS.md 에 마커가 없을 때

가장 흔한 경우다. 문서 인덱스 절을 통째로 추가한다.

```markdown
## 문서 인덱스

pre-commit hook으로 커밋 직전에 자동 생성한다.

<!-- DOC-INDEX:START -->
<!-- DOC-INDEX:END -->
```

넣고 나서 인덱스를 생성한다.

```bash
git add -N -- AGENTS.md scripts/gen-doc-index.sh docs
bash scripts/gen-doc-index.sh
```

마커 사이에 손으로 쓴 내용을 넣으면 다음 커밋에 사라진다.

### .gitattributes 를 새로 넣었을 때

이미 CRLF 로 커밋된 파일이 있으면 속성만 바꿔서는 저장소 안 내용이 안 바뀐다. 한 번 재정규화한다.

```bash
git add --renormalize .
git status          # 줄바꿈만 바뀐 파일이 잔뜩 뜬다. 별도 커밋으로 분리한다
```

기능 변경과 같은 커밋에 넣지 않는다. diff 가 전부 줄바꿈으로 덮인다.

## check-docs.sh FAIL 대처

| 메시지 | 조치 |
| --- | --- |
| `front matter 없음` | 문서 맨 앞에 `---` 블록을 넣는다. 필수 7개는 `id title type status summary scope read_when` |
| `필수 property 누락` | 빠진 키만 채운다. 값이 없으면 키를 넣지 않는 것이 아니라 값을 정한다 |
| `type '...' 는 enum 밖` | `index standard guide reference generated` 다섯 개만 쓴다 |
| `위치 기준 type 은 X 인데 Y` | 문서를 옮기거나 `type` 을 고친다. 디렉터리와 `type` 은 1:1이다 |
| `status '...' 는 type '...' 에 허용되지 않음` | 규약 표를 본다. `index` 는 `active` 만 쓴다 |
| `summary 가 개조식이 아니다` | 명사나 명사구로 끝낸다. 마침표와 서술형 종결어미를 뺀다 |
| `H1 이 title 과 다름` | 본문 첫 `# ` 제목과 front matter `title` 을 같게 맞춘다 |
| `id 중복` | 문서를 복사해 만들면 자주 난다. `<type>-<slug>` 로 새 id 를 준다 |
| `그런 id 가 없음` | `related` 와 `supersedes` 는 파일 경로가 아니라 `id` 로 적는다 |
| `저장소 안 경로는 링크로 쓴다` | 백틱을 마크다운 링크로 바꾼다. 링크 대상은 저장소 루트 기준 |
| `저장소 루트 기준 경로로 쓴다` | `../` 나 `./` 로 시작하는 링크를 루트 기준으로 고친다 |
| `대상 없음` | 파일이 옮겨졌거나 오타다. 실제 경로를 확인한다 |

문서가 많아 한 번에 못 고치면 `status: draft` 로 두고 넘기지 않는다.
`status` 는 문서의 유효성이지 정리 상태가 아니다. 고칠 때까지 FAIL 을 남겨두는 편이 낫다.

## 훅 설치 충돌

| 증상 | 원인과 조치 |
| --- | --- |
| `Cowardly refusing to install hooks with core.hooksPath set` | 전역 `core.hooksPath` 가 걸려 있다. `GIT_CONFIG_GLOBAL=/dev/null` 를 앞에 붙여 설치한다. 전역 설정은 바뀌지 않는다 |
| 기존 `.git/hooks/pre-commit` 이 있다 | pre-commit 이 `.legacy` 로 백업하고 이어서 호출한다. 백업 파일이 생겼는지 확인한다 |
| 훅이 아예 안 돈다 | 클론마다 설치가 필요하다. `.venv/Scripts/pre-commit install` 을 했는지 확인한다 |
| 훅이 매번 통째로 실패한다 | `pre-commit run --all-files` 로 원인을 먼저 본다. 커밋을 막은 채로 방치하면 `--no-verify` 가 습관이 된다 |

## 자격 증명이 이미 커밋돼 있을 때

`check-secrets.sh --all` 이 추적 파일 전체를 훑는다. 걸리면 순서가 정해져 있다.

1. **해당 토큰을 즉시 폐기하고 재발급한다.** 이력 정리보다 먼저다
2. 값을 `.env` 로 옮기고 `.env.example` 에 빈 키를 넣는다
3. 노출 범위를 보고한다. 저장소, 브랜치, 시점을 적는다
4. 이력에서 지울지는 그다음 판단이다. 이미 push 된 이력을 강제로 다시 쓰지 않는다

오탐이면 그 줄 끝에 `secret-scan: allow` 주석을 붙인다. 패턴 자체를 지우지 않는다.
