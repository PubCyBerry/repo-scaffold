---
name: repo-scaffold
description: >-
  Set up a repository so coding agents work from its docs instead of guessing:
  an AGENTS.md with an auto-generated docs index, a docs/ tree in Open
  Knowledge Format (OKF), decision records in MADR format, troubleshooting kept
  in the remote issue tracker, and pull/merge request and issue templates for
  GitHub, GitLab, and Gitea. A pre-commit hook and one CI job keep the index
  current. Needs only bash and git. Trigger on "scaffold my repo", "set up
  AGENTS.md", "make this repo agent-readable", "add ADRs", "add issue and PR
  templates", and on the Korean phrasings "저장소 세팅해줘", "스캐폴딩",
  "프로젝트 초기화", "AGENTS.md 만들어줘", "문서 체계 세워줘", "문서 인덱스 자동화",
  "ADR 도입해줘", "이슈 템플릿 붙여줘", "PR 템플릿 만들어줘",
  "새 레포 만들었는데 뭐부터". Applies to empty and existing repositories alike.
  Route elsewhere: writing or editing one document, linters and formatters,
  build or test pipelines, language project generators (cargo new, npm init).
license: MIT
compatibility: >-
  Requires bash and git; on Windows use Git Bash. Writes only inside the
  target repository, never overwrites an existing file, and uses no network.
metadata:
  kind: workflow
  language: ko
  group: repo-tooling
  summary: 에이전트가 문서를 근거로 일하게 만드는 최소 구조를 세우고 hook과 CI로 문서 인덱스를 지킨다.
  tags:
    - scaffolding
    - documentation
    - agents-md
    - okf
    - adr
---

# 에이전트용 저장소 스캐폴딩

목적은 하나다. **에이전트가 사전학습 기억이 아니라 저장소 안의 문서를 근거로 판단하게 만든다.**

| 에이전트가 알아야 하는 것 | 어디에 있나 |
| --- | --- |
| 무엇이 어디 있는지 | `AGENTS.md`의 자동 생성 인덱스와 `docs/` 디렉터리마다 생성되는 `index.md` |
| 문서를 열기 전에 필요한지 | 문서 front matter의 `title`, `description` (OKF) |
| 왜 이렇게 만들었는지 | `docs/decisions/`의 MADR 결정 기록 |
| 전에 겪은 문제인지 | 원격 저장소 이슈의 `troubleshooting` 라벨 |

인덱스가 낡으면 없는 것보다 나쁘다. pre-commit hook과 CI가 `bash scripts/doc-index.sh --check`로 막는다.

## 1. 스킬 위치를 잡는다

이 `SKILL.md`가 있는 디렉터리다. 설치 방식마다 경로가 다르므로 추측하지 말고 실제 경로를 넣는다.
흔한 위치는 `~/.claude/skills/`, `.claude/skills/`, `.agents/skills/`, 플러그인 아래 `skills/`다.

```bash
SKILL_DIR="/path/to/repo-scaffold"    # 이 SKILL.md가 있는 디렉터리
```

## 2. dry-run으로 계획을 본다

```bash
bash "$SKILL_DIR/assets/scaffold.sh" --dry-run /path/to/repo
```

| 옵션 | 뜻 |
| --- | --- |
| `--dry-run` | 쓰지 않고 계획만 출력한다 |
| `--forge github\|gitlab` | 템플릿과 CI의 형식이다. 생략하면 `origin` 주소에 `gitlab`이 있을 때 gitlab, 아니면 github다. Gitea와 Forgejo는 github 형식(`.github/`)을 읽는다. 자체 호스팅 GitLab 주소에 `gitlab`이 없으면 직접 준다 |
| `--init` | 대상이 git 저장소가 아니면 `git init` 한다. 새 저장소일 때만 쓴다 |

| 판정 | 뜻 | 할 일 |
| --- | --- | --- |
| `PLAN` / `ADD` | 새로 만든다 | 없음 |
| `SKIP` | 이미 있어서 건드리지 않았다 | 내용이 규약과 맞는지 본다 |
| `NOTE` | 사람이 손으로 합칠 것이 있다 | 출력된 사유대로 처리한다 |
| `FAIL` | 실패했다 | 사유를 읽고 고친다 |

## 3. 적용한다

```bash
bash "$SKILL_DIR/assets/scaffold.sh" /path/to/repo
```

기존 파일은 덮어쓰지 않는다. 여러 번 실행해도 결과가 같다. 대상 저장소 루트가 아니면 멈춘다.

| 묶음 | 깔리는 것 |
| --- | --- |
| 진입점 | `AGENTS.md` |
| 문서 | `docs/` OKF 번들. `standards/`의 규약 다섯 개와 빈 `decisions/`, 디렉터리마다 `index.md` |
| 검사 | `scripts/doc-index.sh`, `.githooks/pre-commit`, `.gitattributes` |
| github 형식 | `.github/pull_request_template.md`, `.github/ISSUE_TEMPLATE/` 셋, `.github/workflows/docs.yml` |
| gitlab 형식 | `.gitlab/merge_request_templates/Default.md`, `.gitlab/issue_templates/` 셋, `.gitlab-ci.yml` |

`core.hooksPath`를 `.githooks`로 설정한다. 다른 hook 설정(`core.hooksPath`, `.pre-commit-config.yaml`,
`.husky`, `lefthook.yml`, 기존 `.git/hooks/pre-commit`)이 있으면 바꾸지 않고 `NOTE`로 알린다.
hook 파일은 실행 비트를 git에 기록하려고 그 파일만 스테이징한다.

## 4. 마무리한다

| 할 일 | 방법 |
| --- | --- |
| 저장소 설명 | `AGENTS.md` 첫 문단의 주석 자리에 이 저장소가 무엇인지 한두 문장으로 쓴다 |
| `NOTE` 항목 | 출력된 사유대로 처리한다. 설정 파일은 자동으로 합치지 않는다 |
| 기존 `AGENTS.md` | 템플릿의 문서 절과 규칙 절을 합치고 `<!-- DOC-INDEX:START -->`, `<!-- DOC-INDEX:END -->` 두 줄을 넣는다 |
| 기존 `CLAUDE.md` | Claude Code는 `CLAUDE.md`가 없을 때만 `AGENTS.md`를 읽는다. 내용을 `AGENTS.md`로 옮기고 지운다 |
| 기존 `docs/` 문서 | front matter에 `type`, `title`, `description`을 넣는다 |
| 라벨 | 원격 저장소에 `troubleshooting` 라벨을 한 번 만든다. 명령은 `docs/standards/troubleshooting.md`에 있다 |

그다음 인덱스를 만들고 검사한다.

```bash
bash scripts/doc-index.sh            # 인덱스를 다시 만든다
bash scripts/doc-index.sh --check    # 통과해야 끝난 것이다
```

검사가 실패하면 출력이 원인을 짚는다. 대부분 front matter가 없거나, 인덱스가 낡았거나,
`AGENTS.md`에 인덱스 자리가 없는 경우다.

## 깔리는 규약

| 문서 | 내용 |
| --- | --- |
| `docs/standards/documentation.md` | `docs/`는 OKF v0.2 번들이다. front matter와 생성되는 색인 |
| `docs/standards/decisions.md` | 되돌리기 어려운 결정은 MADR 4.0 형식으로 `docs/decisions/`에 남긴다. 한국어 템플릿 포함 |
| `docs/standards/troubleshooting.md` | 트러블슈팅은 원격 저장소의 이슈로 남긴다. 검색, 기록, 종료 방법 |
| `docs/standards/issues-and-pull-requests.md` | 이슈와 PR(MR)이 담아야 하는 것과 템플릿 선택 |
| `docs/standards/writing-style.md` | 글의 언어, 구성, 문장, 표기, 링크, 커밋 메시지 형식, 낡지 않게 쓰는 방법 |

깔리는 문서와 템플릿은 한국어로 쓰여 있고, 스크립트 출력은 영어다. 근거는 `writing-style.md`의 언어 절에 있다.

규약을 바꾸려면 `assets/docs/`의 문서를 고치고 `bash assets/scripts/doc-index.sh`로
템플릿의 인덱스를 다시 만든다.
