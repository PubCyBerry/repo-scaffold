---
name: repo-scaffold
description: >-
  Scaffold a repository so coding agents navigate it by reading its docs
  instead of guessing: an auto-generated AGENTS.md doc index, a docs/
  hierarchy (standards/guides/references/generated) with a front matter
  convention, ready-made standards (writing style, code quality, testing,
  review, commits, shell, Actions), and prek hooks that keep it from
  rotting (doc convention, shellcheck/shfmt, actionlint/zizmor, .env key
  sync, credential scan). Trigger on "scaffold my repo", "set up
  AGENTS.md", "initialize this project", "add pre-commit hooks", "make
  this repo agent-readable", and on the Korean phrasings "저장소 세팅해줘",
  "스캐폴딩", "프로젝트 초기화", "AGENTS.md 만들어줘", "CLAUDE.md 붙여줘",
  "문서 체계 세워줘", "문서 인덱스 자동화", "pre-commit 훅 붙여줘",
  "린터 붙여줘", "새 레포 만들었는데 뭐부터" — even when neither
  "scaffold" nor "스캐폴딩" is named. Applies to empty and existing
  repositories alike. Route elsewhere: writing or editing one document,
  CI/CD pipeline setup, language project generators (cargo new), refactors.
license: MIT
compatibility: >-
  Requires bash, git, and GNU sed on the target machine; on Windows use
  Git Bash. The target must already be a git repository unless --init is
  passed. Installing the generated hooks additionally needs prek (a
  single binary, installable with uv or brew). The shell and workflow
  hooks call shellcheck, shfmt, actionlint, and zizmor; a missing tool is
  a local SKIP and a CI failure. Writes only inside --target and never
  overwrites an existing file.
metadata:
  kind: workflow
  language: ko
  group: repo-tooling
  summary: 에이전트가 문서로 저장소를 탐색하게 만드는 구조를 세우고 커밋 훅으로 고정한다.
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
| 규약이 시간이 지나도 안 썩는다 | 커밋 훅이 커밋마다 검증 |

셋째가 핵심이다. 검증이 없으면 인덱스가 낡고, 낡은 인덱스는 없는 것보다 나쁘다.

## 1. 파라미터를 먼저 고정한다

| 파라미터 | 옵션 | 기본값 | 정하는 법 |
| --- | --- | --- | --- |
| 대상 경로 | `--target` | 없음. 필수 | 저장소 루트. worktree 면 그 worktree 경로 |
| 저장소 이름 | `--name` | `--target` 의 basename | 인덱스 제목 `[NAME Docs Index]` 에 들어간다 |
| 한 줄 설명 | `--desc` | `<이름> 저장소` | AGENTS.md 와 README 첫 문장 |
| 제품 디렉터리 | `--product` | 없음 | 특정 제품이나 프레임워크 종속 자료가 있을 때만. 예: `--product nexus` |
| 문서 언어 | `--lang` | `en` | `docs/` 는 영어로 쓰는 것이 규약이다. `ko` 는 규약을 벗어날 때만 |

`--product` 는 **제품 종속 규칙과 스택 무관 규칙이 섞이는 것을 막을 때만** 쓴다.
컴포넌트가 하나이고 스택도 하나면 넣지 않는다. 나중에 디렉터리만 만들어 옮겨도 된다.

이름과 설명이 명확하지 않으면 사용자에게 묻는다. 인덱스 제목과 README 첫 문장이라 나중에 고치면 diff 가 지저분해진다.

## 2. dry-run 으로 계획을 본다

전역 설치된 스킬 위치를 잡는다.

```bash
SKILL_DIR="$HOME/.claude/skills/repo-scaffold"
```

```bash
bash "$SKILL_DIR/assets/scaffold.sh" \
    --target /path/to/repo --name MYREPO --desc "한 줄 설명" --dry-run
```

출력의 `PLAN` 은 새로 만들 파일, `SKIP` 은 이미 있어서 건드리지 않을 파일이다.
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

`docs/standards/` 에는 규약 문서 8종이 같이 깔린다.
문서 작성, 글쓰기, 코드 품질, 테스트, 코드 리뷰, 커밋, 셸, GitHub Actions 다.
**깔았으면 지켜야 하는 규칙이다.** 팀에 안 맞는 문서는 남기지 말고 지운다.

## 4. 검증한다

```bash
cd /path/to/repo
bash tests/check-docs.sh --no-net    # 문서 규약. FAIL 0 이어야 한다
bash tests/check-shell.sh            # shellcheck, shfmt
bash tests/check-workflows.sh        # actionlint, zizmor
bash tests/check-env.sh              # .env 키 동기화
bash tests/check-secrets.sh          # staged 자격 증명 스캔
```

FAIL 이 나오면 그 자리에서 고친다. 스캐폴딩 직후 FAIL 은 대부분 기존 문서의 front matter 누락이다.
[references/retrofit.md](references/retrofit.md) 에 증상별 조치가 있다.

`check-shell.sh` 와 `check-workflows.sh` 는 도구가 없으면 SKIP 이다. 조용히 통과한 것이 아니다.
환경변수 `CI=true` 이면 같은 상황이 FAIL 이다.

## 5. 손으로 마무리할 것

스크립트가 못 채우는 자리다. 스캐폴딩 후 반드시 확인한다.

| 대상 | 할 일 |
| --- | --- |
| `.env.example` | 예시 키를 지우고 실제로 쓰는 키를 빈 값으로 넣는다 |
| `README.md` | 구성 트리에서 없는 디렉터리를 지운다. 컴포넌트 표를 채운다 |
| `AGENTS.md` | `--product` 를 썼으면 폴더 성격 표에 그 디렉터리 행을 추가한다 |
| `docs/standards/` | 팀에 안 맞는 규약 문서를 지우고, 지운 문서를 참조하는 링크와 인덱스 행도 지운다 |
| `docs/*/index.md` | 기존 문서가 있으면 문서 목록 표에 한 줄씩 넣는다 |
| `.claude/settings.json` | 프로젝트에서 자주 쓰는 명령을 allow 에 추가한다 |

## 6. 훅 설치를 안내한다

훅은 **클론마다 한 번** 설치한다. 설치하지 않으면 검증이 아예 돌지 않는다.
스캐폴딩만 하고 끝내면 절반만 한 것이다.

실행기는 [prek](https://prek.j178.dev) 이다. pre-commit 의 Rust 재구현이고 `.pre-commit-config.yaml` 을 그대로 읽는다.
단일 바이너리라 프로젝트 안에 `.venv` 를 만들지 않는다.

```bash
uv tool install prek        # 또는 brew install prek
prek install
```

`shell-lint` 와 `workflow-lint` 훅이 부르는 도구도 같이 안내한다.

```bash
for t in shellcheck-py shfmt-py actionlint-py zizmor; do uv tool install "$t"; done
```

전역 `core.hooksPath` 가 걸린 환경이면 그 확인만 우회한다. 전역 설정은 건드리지 않는다.

```bash
GIT_CONFIG_GLOBAL=/dev/null prek install
```

첫 커밋은 `doc-index` 훅이 AGENTS.md 를 갱신하면서 **한 번 실패한다.** 정상 동작이다.
커밋 내용이 바뀌었다는 신호이므로 그대로 다시 커밋한다.

## 참고

- [references/layout.md](references/layout.md) — 파일별로 무엇을 막는지. 항목을 빼자는 요구가 나오면 여기를 근거로 답한다
- [references/retrofit.md](references/retrofit.md) — 기존 저장소에 얹을 때의 충돌 처리와 FAIL 대처
- 템플릿 실체는 [assets/](assets/) 아래에 있다. 규약을 바꾸려면 템플릿과 검증 스크립트를 같이 고친다
