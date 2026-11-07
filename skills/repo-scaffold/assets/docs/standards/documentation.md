---
type: Standard
title: 문서 관리
description: docs/를 OKF 번들로 관리하는 방법과 색인을 최신으로 유지하는 방법을 정한다.
tags: [docs, okf]
---

# 문서 관리

`docs/`는 [OKF(Open Knowledge Format) v0.2](https://github.com/GoogleCloudPlatform/knowledge-catalog/blob/main/okf/SPEC.md) 번들이다.
번들은 YAML front matter가 붙은 Markdown 파일의 트리이고, 파일 하나가 개념 하나를 다룬다. 번들 루트는 `docs/`다.

## front matter

`index.md`와 `log.md`를 뺀 모든 Markdown 파일은 front matter로 시작한다.
OKF가 요구하는 키는 `type` 하나지만, 이 저장소는 `title`과 `description`도 요구한다. 색인을 이 두 키로 만들기 때문이다.

| 키 | 필수 | 설명 |
| --- | --- | --- |
| `type` | 예 | 문서의 종류다. `Standard`, `Decision`, `Guide`, `Reference`처럼 이름만 보고 알 수 있는 값을 쓴다 |
| `title` | 예 | 표시 이름이다. 한 줄로 쓴다 |
| `description` | 예 | 문서를 열지 판단하게 해 주는 한 문장이다. 한 줄로 쓴다 |
| `status` | 아니요 | `draft`, `stable`, `deprecated` 중 하나이고 기본값은 `stable`이다. 결정 기록은 [상태](decisions.md#상태)를 따른다 |
| `tags` | 아니요 | 디렉터리를 가로지르는 주제를 나타내는 짧은 문자열 목록이다 |

나머지 OKF 키(`resource`, `sources`, `generated`, `verified`, `stale_after`)는 선택이고, 쓸 때는 규격을 따른다.
규격에 없는 키도 쓸 수 있다.

```markdown
---
type: Guide
title: 로컬 개발 환경
description: 개발 도구를 설치하고 서비스를 로컬에서 실행한다.
---
```

## 디렉터리

| 디렉터리 | 설명 |
| --- | --- |
| `standards/` | 기여자와 에이전트가 따르는 규칙 |
| `decisions/` | MADR 형식의 결정 기록 |

묶어 둘 문서가 생기면 디렉터리를 추가한다.

## 색인

`scripts/doc-index.sh`가 `docs/` 아래 모든 디렉터리의 `index.md`와 `AGENTS.md`의 문서 색인을 만든다.
둘 다 손으로 고치지 않는다. 손으로 고친 내용은 다음에 색인을 만들 때 사라진다.

- 문서를 추가하거나 옮기거나 제목을 바꾸면 `bash scripts/doc-index.sh`를 실행한다.
- `bash scripts/doc-index.sh --check`는 front matter가 없거나 색인이 낡았으면 실패한다.
- pre-commit hook은 클론마다 `git config core.hooksPath .githooks`를 한 번 실행해서 켠다.

## 링크

문서 사이의 링크는 [글쓰기 규칙](writing-style.md#링크)을 따른다.

## docs/에 두지 않는 것

트러블슈팅 기록은 문서가 아니라 원격 저장소의 이슈다. [트러블슈팅](troubleshooting.md)을 따른다.

## 함께 고칠 곳

| 파일 | 설명 |
| --- | --- |
| `scripts/doc-index.sh` | 필수 키를 검사하고 색인을 만든다. 필수 키가 바뀌면 함께 고친다 |
| `AGENTS.md` | 문서 색인이 들어갈 자리를 표시하는 주석이 있다 |

## 검사

`bash scripts/doc-index.sh --check`가 front matter와 색인을 검사한다. pre-commit hook과 CI가 이 명령을 실행한다.

## 같이 보기

- [Open Knowledge Format v0.2](https://github.com/GoogleCloudPlatform/knowledge-catalog/blob/main/okf/SPEC.md)
- [글쓰기 규칙](writing-style.md)
