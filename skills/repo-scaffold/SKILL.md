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
  summary: 에이전트가 저장소의 문서를 근거로 일하게 하는 최소 구조와 문서 인덱스를 최신으로 유지하는 hook, CI
  tags:
    - scaffolding
    - documentation
    - agents-md
    - okf
    - adr
---

# 에이전트용 저장소 스캐폴딩

에이전트가 사전학습 기억 대신 저장소의 문서를 근거로 판단하도록, 대상 저장소에 문서 체계와 검사를 추가한다.

## 1. 스킬 위치 확인

`SKILL_DIR`은 이 `SKILL.md`가 있는 디렉터리다. 설치 방식마다 경로가 다르므로 실제 경로를 확인해서 넣는다.
흔한 위치는 `~/.claude/skills/`, `.claude/skills/`, `.agents/skills/`, 플러그인 아래 `skills/`다.

```bash
SKILL_DIR="/path/to/repo-scaffold"
```

## 2. 계획 확인

```bash
bash "$SKILL_DIR/assets/scaffold.sh" --dry-run /path/to/repo
```

| 옵션 | 설명 |
| --- | --- |
| `--dry-run` | 파일을 쓰지 않고 계획만 출력 |
| `--forge github\|gitlab` | 템플릿과 CI의 형식. 생략하면 `origin` 주소에 `gitlab`이 있을 때 gitlab, 그 밖에는 github. Gitea와 Forgejo는 github 형식(`.github/`) 사용. 주소에 `gitlab`이 없는 자체 호스팅 GitLab은 직접 지정 |
| `--init` | 대상이 git 저장소가 아니면 `git init` 실행. 새 저장소에만 사용 |

| 판정 | 의미 | 후속 작업 |
| --- | --- | --- |
| `PLAN` / `ADD` | 새로 만들 파일 / 새로 만든 파일 | 없음 |
| `SKIP` | 이미 있어서 그대로 둔 파일 | 내용이 규약과 맞는지 확인 |
| `NOTE` | 직접 처리해야 하는 항목 | 출력된 사유대로 처리 |
| `FAIL` | 실패 | 사유를 읽고 수정 |

## 3. 적용

```bash
bash "$SKILL_DIR/assets/scaffold.sh" /path/to/repo
```

기존 파일은 덮어쓰지 않고, 여러 번 실행해도 결과가 같다. 대상이 저장소 루트가 아니면 멈춘다.

| 묶음 | 추가되는 파일 |
| --- | --- |
| 진입점 | `AGENTS.md` |
| 문서 | `docs/` OKF 번들. `standards/`의 규약 문서, 빈 `decisions/`, 디렉터리마다 `index.md` |
| 검사 | `scripts/doc-index.sh`, `.githooks/pre-commit` |
| git 설정 | `.gitignore`, `.gitattributes` |
| github 형식 | `.github/pull_request_template.md`, `.github/ISSUE_TEMPLATE/`의 이슈 템플릿, `.github/workflows/docs.yml` |
| gitlab 형식 | `.gitlab/merge_request_templates/Default.md`, `.gitlab/issue_templates/`의 이슈 템플릿, `.gitlab-ci.yml` |

`core.hooksPath`를 `.githooks`로 설정한다. 다른 hook 설정(`core.hooksPath`, `.pre-commit-config.yaml`, `.husky`, `lefthook.yml`, 기존 `.git/hooks/pre-commit`)이 있으면 바꾸지 않고 `NOTE`로 알린다.
hook 파일의 실행 비트를 git에 기록하려고 그 파일만 스테이징한다.
`.gitattributes`를 새로 추가할 때 CRLF로 커밋된 파일이 있으면, `git add --renormalize .`로 줄바꿈을 맞추라고 `NOTE`로 알린다.

## 4. 마무리

| 대상 | 작업 |
| --- | --- |
| 저장소 설명 | `AGENTS.md` 첫 문단의 주석 자리에 저장소 설명을 한두 문장으로 작성 |
| `NOTE` 항목 | 출력된 사유대로 직접 처리 |
| 기존 `AGENTS.md` | 템플릿의 문서 절과 규칙 절을 합치고 `<!-- DOC-INDEX:START -->`, `<!-- DOC-INDEX:END -->` 두 줄 추가 |
| 기존 `CLAUDE.md` | 내용을 `AGENTS.md`로 옮긴 뒤 삭제. Claude Code는 `CLAUDE.md`가 없을 때만 `AGENTS.md`를 읽음 |
| 기존 `docs/` 문서 | front matter에 `type`, `title`, `description` 추가 |
| 라벨 | 원격 저장소에 `troubleshooting` 라벨을 한 번 생성. 명령은 `docs/standards/troubleshooting.md`에 있음 |

이어서 인덱스를 다시 만들고 검사한다. 검사를 통과해야 작업이 끝난다.

```bash
bash scripts/doc-index.sh
bash scripts/doc-index.sh --check
```

검사가 실패하면 출력에 원인이 나온다. 흔한 원인은 front matter 누락, 낡은 인덱스, `AGENTS.md`의 인덱스 자리 누락이다.

## 추가되는 규약

규약 문서의 목록과 설명은 `assets/docs/standards/index.md`에 있다.
규약 문서와 템플릿은 한국어이고 스크립트 출력은 영어다. 언어 규칙은 `assets/docs/standards/writing-style.md`의 언어 절에 있다.
