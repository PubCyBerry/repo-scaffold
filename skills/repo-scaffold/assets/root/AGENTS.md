# Instructions for Agents

{{REPO_DESC}}

## 문서 작업 방식

이 저장소에서 작업할 때 문서를 읽고 갱신하는 방법은 다음과 같다.
먼저 아래 문서 인덱스를 읽고 주요 문서가 있는 폴더만 선택한다.
작업의 성격상 다른 폴더도 필요하다면 그때 가서 해당 폴더들을 불러온다.
굳이 모든 문서들을 일일이 불러오려고 하지 않는다.
문서를 새로 만들거나 파악했으면 해당 폴더의 `index.md`에 한 줄 추가한다.

각 문서가 무엇을 다루는지는 그 문서 front matter의 `title`, `summary`, `read_when` 에 있다.
폴더를 고른 뒤 그 폴더의 `index.md` 를 열면 문서별 한 줄 설명이 나온다.

## 문서 인덱스

pre-commit hook으로 커밋 직전에 자동 생성한다.

<!-- DOC-INDEX:START -->
<!-- DOC-INDEX:END -->

폴더 성격은 다음과 같다.

| 경로 | 성격 |
| --- | --- |
| `docs/standards/` | 지켜야 하는 규칙. 어기면 리뷰 지적 대상 |
| `docs/guides/` | 절차 |
| `docs/references/` | 사실 조회 |
| `docs/generated/` | 코드나 스키마에서 생성. 손으로 고치지 않음 |

제품이나 프레임워크에 종속되는 자료는 `docs/` 아래 별도 도메인 디렉터리로 분리한다.
그 안에서도 `standards/`, `guides/`, `references/` 구분은 같다.

## 작업 전 확인

- 커밋 전에 [tests/check-docs.sh](tests/check-docs.sh) 가 통과하는가
- 자격 증명을 코드나 문서에 리터럴로 넣지 않았는가. 규칙은 [SECURITY.md](SECURITY.md)
- 문서를 추가했으면 해당 디렉터리 `index.md` 에 한 줄 넣었는가
