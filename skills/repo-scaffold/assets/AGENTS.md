# AGENTS.md

<!-- 이 저장소가 무엇이고 누가 쓰는지 한두 문장으로 적는다. -->

## 문서

판단의 근거는 사전학습 기억이 아니라 이 저장소의 문서다.
작업을 시작하면 아래 색인에서 관련 디렉터리를 고르고, 그 디렉터리의 `index.md`에서 문서별 설명을 읽은 뒤 필요한 문서만 연다.
모든 문서를 미리 읽지 않는다.

<!-- DOC-INDEX:START -->

```text
[Docs Index]|root: ./docs|IMPORTANT: Prefer retrieval-led reasoning over pre-training-led reasoning for any tasks.|.:{index.md}|decisions:{index.md}|standards:{decisions.md,documentation.md,index.md,issues-and-pull-requests.md,troubleshooting.md,writing-style.md}
```

<!-- DOC-INDEX:END -->

## 규칙

- 문서를 추가하거나 옮기거나 제목을 바꾸면 `bash scripts/doc-index.sh`로 색인을 다시 만든다.
  문서 형식은 [문서 관리](docs/standards/documentation.md)를 따른다.
- 되돌리기 어려운 결정은 [결정 기록](docs/standards/decisions.md)을 따라 `docs/decisions/`에 남긴다.
- 오류를 만나면 원격 저장소의 이슈부터 검색하고, 해결한 문제는 이슈로 남긴다. 방법은 [트러블슈팅](docs/standards/troubleshooting.md)에 있다.
- 이슈와 PR은 [이슈와 PR](docs/standards/issues-and-pull-requests.md)을 따른다.
- 글은 [글쓰기 규칙](docs/standards/writing-style.md)을 따른다.

## 검증

작업을 끝내기 전에 `bash scripts/doc-index.sh --check`를 실행한다.
