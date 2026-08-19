---
name: repo-scaffold
description: >-
  Scaffold a repository so coding agents navigate it by reading its docs
  instead of guessing: an auto-generated AGENTS.md doc index, a docs/
  hierarchy (standards/guides/references/generated/architecture) with a front
  matter convention, 14 ready-made standards, a Justfile whose `just verify`
  is the one command to remember, prek hooks split across pre-commit,
  commit-msg and pre-push, and GitHub Actions plus issue and pull request
  governance. Trigger on "scaffold my repo", "set up AGENTS.md", "initialize
  this project", "add pre-commit hooks", "make this repo agent-readable", and
  on the Korean phrasings "저장소 세팅해줘", "스캐폴딩", "프로젝트 초기화",
  "AGENTS.md 만들어줘", "CLAUDE.md 붙여줘", "문서 체계 세워줘",
  "문서 인덱스 자동화", "pre-commit 훅 붙여줘", "린터 붙여줘",
  "검증 명령 하나로 줄여줘", "새 레포 만들었는데 뭐부터". Trigger even when neither
  "scaffold" nor "스캐폴딩" is named. Applies to empty and existing repositories
  alike. Route elsewhere: writing or editing one document, language project
  generators (cargo new), refactors.
license: MIT
compatibility: >-
  Requires bash, git, and GNU sed on the target machine; on Windows use Git
  Bash. The target must already be a git repository unless --init is passed.
  Scaffolding itself needs nothing else. Running the generated gates needs uv
  (or another way to install the pinned tools in tools.txt), and `just
  bootstrap` additionally uses Node for commitlint. Every tool the hooks call
  is a local SKIP when missing and a CI failure, so a partial toolchain still
  commits. Writes only inside --target and never overwrites an existing file.
metadata:
  kind: workflow
  language: ko
  group: repo-tooling
  summary: 에이전트가 문서로 저장소를 탐색하게 만드는 구조를 세우고 훅과 CI 로 고정한다.
  tags:
    - scaffolding
    - documentation
    - agents-md
    - pre-commit
    - repo-setup
---

# 에이전트 특화 저장소 스캐폴딩

목적은 하나다. **에이전트가 사전학습 기억이 아니라 저장소 안 문서를 근거로 판단하게 만든다.**
그러려면 문서가 있는 것만으로는 부족하고, 세 가지가 성립해야 한다.

| 조건 | 수단 |
| --- | --- |
| 무엇이 어디 있는지 한 번에 안다 | AGENTS.md 의 자동 생성 문서 인덱스 |
| 열어보기 전에 열지 말지 판단한다 | front matter 의 `title`, `summary`, `read_when` |
| 규약이 시간이 지나도 안 썩는다 | 훅과 CI 가 커밋마다 검증 |

셋째가 핵심이다. 검증이 없으면 인덱스가 낡고, 낡은 인덱스는 없는 것보다 나쁘다.

에이전트가 외울 명령은 하나다. **`just verify`** 가 Definition of Done 이다.
그 뒤에 무엇이 도는지는 대상 저장소의 Justfile 에 적혀 있고, 이 스킬은 그것을 배치한다.

## 1. 파라미터를 먼저 고정한다

| 파라미터 | 옵션 | 기본값 | 정하는 법 |
| --- | --- | --- | --- |
| 대상 경로 | `--target` | 없음. 필수 | 저장소 루트. worktree 면 그 worktree 경로 |
| 저장소 이름 | `--name` | `--target` 의 basename | 인덱스 제목 `[NAME Docs Index]` 에 들어간다 |
| 한 줄 설명 | `--desc` | `<이름> 저장소` | AGENTS.md 와 README 첫 문장 |
| 제품 디렉터리 | `--product` | 없음 | 제품 종속 자료가 따로 있을 때만. 예: `--product nexus` |
| 문서 언어 | `--lang` | `en` | `docs/` 는 영어로 쓰는 것이 규약이다. `ko` 는 규약을 벗어날 때만 |
| 언어 강제 | `--with`, `--without` | 없음 | 언어 감지 결과를 덮어쓴다. 여러 번 줄 수 있다 |
| 저장소 생성 | `--init` | 하지 않음 | 대상이 아직 git 저장소가 아닐 때만 |

`--product` 는 **제품 종속 규칙과 스택 무관 규칙이 섞이는 것을 막을 때만** 쓴다.
컴포넌트가 하나이고 스택도 하나면 넣지 않는다. 나중에 디렉터리만 만들어 옮겨도 된다.

이름과 설명이 명확하지 않으면 사용자에게 묻는다.
인덱스 제목과 README 첫 문장이라 나중에 고치면 diff 가 지저분해진다.

## 2. dry-run 으로 계획을 본다

전역 설치된 스킬 위치를 잡는다.

```bash
SKILL_DIR="$HOME/.claude/skills/repo-scaffold"
```

```bash
bash "$SKILL_DIR/assets/scaffold.sh" \
    --target /path/to/repo --name MYREPO --desc "한 줄 설명" --dry-run
```

판정은 다섯이다. 파일이 안 생기는 이유가 셋으로 갈리므로 뭉뚱그려 읽지 않는다.

| 판정 | 뜻 | 사람이 할 일 |
| --- | --- | --- |
| `PLAN` / `ADD` | 새로 만든다 | 없음 |
| `SKIP` | 이미 있어서 건드리지 않았다 | 내용이 규약에 맞는지 본다 |
| `OMIT` | 이 저장소에 불필요하다고 판정했다 | 틀렸으면 `--with` 로 강제한다 |
| `NOTE` | 이미 있는 설정 파일이다 | 원본을 열어 손으로 합친다. 자동 병합은 하지 않는다 |
| `FAIL` | 실패했다 | 사유를 읽고 고친다 |

**SKIP 이 많으면 그게 진단 결과다.** 어떤 규약이 빠져 있는지가 PLAN 목록에 그대로 나온다.

git 저장소가 아니면 실패한다. 새로 만드는 경우에만 `--init` 을 붙인다.

## 3. 적용한다

```bash
bash "$SKILL_DIR/assets/scaffold.sh" \
    --target /path/to/repo --name MYREPO --desc "한 줄 설명"
```

기존 파일은 절대 덮어쓰지 않는다. 여러 번 돌려도 결과가 같다.

스크립트가 이번 실행에서 만든 경로만 `git add -N` 으로 인덱스에 등록한다.
`scripts/gen-doc-index.sh` 와 `AGENTS.md` 를 둘 다 만든 실행에서만 문서 인덱스를 생성한다.
둘 중 하나라도 `SKIP` 이면 기존 스크립트를 실행하거나 기존 `AGENTS.md` 를 바꾸지 않는다.

깔리는 것은 다섯 덩어리다.

| 덩어리 | 내용 |
| --- | --- |
| 명령 레이어 | `Justfile`, `tools.txt`, `scripts/` 의 bootstrap, doctor, tool-help, fmt, fix, run-all |
| 검증 | `tests/check-*.sh` 13종, `run-tests.sh`, `.pre-commit-config.yaml`, `schemas/` |
| 문서 | `AGENTS.md`, `CLAUDE.md`, `README.md`, `docs/` 계층과 규약 문서 14종 |
| 도구 설정 | `.rumdl.toml`, `.vale.ini`, `styles/`, `.shellcheckrc`, `.yamllint.yaml` 등 |
| GitHub | 워크플로 6종, Issue Form, PR 템플릿, 라벨 정의, CODEOWNERS 와 룰셋 예제 |

`docs/` 계층은 다섯이다. `standards` `guides` `references` `generated` `architecture` 이고,
디렉터리명과 front matter 의 `type` 이 1:1 이다. `architecture/adr/` 만 `type: decision` 이다.

`docs/standards/` 에 규약 문서 14종이 같이 깔린다. 문서 작성, 글쓰기, 코드 품질, 테스트,
코드 리뷰, 리뷰 피드백, 커밋, 셸, 파이썬, GitHub Actions, 이슈 수명주기, 분류 라벨,
PR 수명주기, GitHub 강제다.
**깔았으면 지켜야 하는 규칙이다.** 팀에 안 맞는 문서는 남기지 말고 지운다.

언어 감지가 정하는 것은 **도구 설정 파일뿐**이다. `Justfile` 과 훅 설정과 `tests/*.sh` 는
언어와 무관하게 항상 깔린다. 근거가 없고 저장소가 비어 있으면 `unknown` 이라 `OMIT` 이고,
이때는 코드를 넣은 뒤 다시 돌리거나 `--with python` 으로 강제한다.

## 4. 도구를 깔고 검증한다

손으로 까는 것은 `just` 하나다. 나머지는 `just bootstrap` 이 `tools.txt` 를 읽어 채운다.

```bash
cd /path/to/repo
uv tool install rust-just    # just 하나만 손으로 깐다
just bootstrap               # 나머지 도구, 의존성, git 훅. 클론마다 한 번
just doctor                  # 환경 진단. 무엇이 없고 무엇이 어긋났는지 보고만 한다
just verify                  # Definition of Done
```

`just verify` 는 prek 를 거치지 않는다. 훅을 안 깐 새 클론에서도 그대로 돈다.
prek 를 부르는 것은 `check` 계열(`just check` 와 `just check-fast`) 둘뿐이다.
`verify` 와 훅이 갈리는지 의심되면 `just check` 로 대조한다.

`just verify` 가 부르는 것은 lint, type, markdown, prose, docs, hooks,
workflow-check, security, test 다. 명령을 외우지 않는다. 인자 없이 `just` 를 치면 목록이 나온다.

FAIL 이 나오면 그 자리에서 고친다. 스캐폴딩 직후 FAIL 은 대부분 기존 문서의 front matter
누락이거나 옛 규약대로 저장소 루트 기준으로 쓰인 링크다.
[references/retrofit.md](references/retrofit.md) 에 증상별 조치와 링크 일괄 변환 절차가 있다.

도구가 없으면 그 단계는 SKIP 이다. 조용히 통과한 것이 아니다.
환경변수 `CI=true` 이면 같은 상황이 FAIL 이다. 막는 지점을 커밋에서 머지로 옮긴 것이다.
SKIP 줄 아래에 그 도구의 문서 주소와 설치 명령이 함께 나온다. `scripts/tool-help.sh` 가 낸다.

## 5. 손으로 마무리할 것

스크립트가 못 채우는 자리다. 스캐폴딩 후 반드시 확인한다.

| 대상 | 할 일 |
| --- | --- |
| `NOTE` 로 보고된 설정 파일 | 원본을 열어 필요한 부분만 손으로 합친다. TOML 과 JSON 은 자동 병합하지 않는다 |
| `.env.example` | 예시 키를 지우고 실제로 쓰는 키를 빈 값으로 넣는다 |
| `README.md` | 구성 트리에서 없는 디렉터리를 지운다. 컴포넌트 표를 채운다 |
| `AGENTS.md` | `--product` 를 썼으면 폴더 성격 표에 그 디렉터리 행을 추가한다 |
| `docs/standards/` | 팀에 안 맞는 규약 문서를 지우고, 참조하는 링크와 인덱스 행도 같이 지운다 |
| `docs/*/index.md` | 기존 문서가 있으면 문서 목록 표에 한 줄씩 넣는다 |
| `.claude/settings.json` | 프로젝트에서 자주 쓰는 명령을 allow 에 추가한다 |

원격 GitHub 설정은 사람이 하는 일이다. 스크립트는 있지만 **인자 없이 부르면 dry-run** 이고
`--apply` 를 줘야 실제로 바꾼다. 절차는 대상 저장소의
`docs/guides/github-governance-setup.md` 에 있다.

| 할 일 | 왜 사람이 하나 |
| --- | --- |
| `scripts/apply-github-labels.sh --apply` | 라벨이 없으면 Issue Form 이 라벨을 조용히 버린다. **가장 먼저 한다** |
| `.github/CODEOWNERS.example` → `CODEOWNERS` | 실제 핸들과 팀 이름은 스크립트가 알 수 없다 |
| `.github/rulesets/` 적용 | 잘못 걸면 기본 브랜치가 잠긴다. 기본 예제가 1인 저장소용이고 승인자가 둘 이상일 때만 team 예제를 쓴다 |
| required check 이름 확인 | 워크플로 잡 이름은 `quality` `tests` `docs` `security` `pr-policy` 다 |

## 6. 훅은 세 스테이지로 갈린다

훅은 **클론마다 한 번** 설치한다. `just bootstrap` 이 `prek install --hook-type` 을 세 번
불러 pre-commit, commit-msg, pre-push 를 모두 건다. 하나라도 빠지면 그 스테이지의 검사가
몇 달간 한 번도 안 돈다.

실행기는 [prek](https://prek.j178.dev) 이다. pre-commit 의 Rust 재구현이고
`.pre-commit-config.yaml` 을 그대로 읽는다. 단일 바이너리라 프로젝트 안에 `.venv` 를 만들지 않는다.

| 스테이지 | 무엇이 도나 | 왜 거기인가 |
| --- | --- | --- |
| pre-commit | 문서 인덱스, 문서 규약, 링크, 마크다운, 산문, ruff, 셸, YAML, 워크플로, `.env`, 자격 증명 | 파일 단위로 답이 나온다 |
| commit-msg | commitlint 와 제목 표기 | 검사 대상이 커밋 메시지다 |
| pre-push | 문서 그래프, source drift, mypy, 단위 테스트, 워크플로 전체 | 부분 검사가 **틀린 답**을 낸다. 느려서가 아니다 |

전역 `core.hooksPath` 가 걸린 환경이면 그 확인만 우회한다. 전역 설정은 건드리지 않는다.

```bash
GIT_CONFIG_GLOBAL=/dev/null prek install
```

첫 커밋은 `doc-index` 훅이 AGENTS.md 를 갱신하면서 **한 번 실패한다.** 정상 동작이다.
커밋 내용이 바뀌었다는 신호이므로 그대로 다시 커밋한다.

커밋 제목은 Conventional Commits 이고 **소문자로 시작한다.** PR 제목도 같은 규격이다.
squash 머지가 PR 제목으로 커밋을 합성하므로 `pr-policy` 워크플로가 PR 제목을 다시 검사한다.

## 참고

- [references/layout.md](references/layout.md): 파일별로 무엇을 막는지.
  항목을 빼자는 요구가 나오면 여기를 근거로 답한다
- [references/retrofit.md](references/retrofit.md): 기존 저장소에 얹을 때의 충돌 처리와 FAIL 대처
- 템플릿 실체는 [assets](assets) 아래에 있다. 규약을 바꾸려면 템플릿과 검증 스크립트를 같이 고친다
