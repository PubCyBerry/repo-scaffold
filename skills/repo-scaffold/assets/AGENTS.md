# AGENTS.md

<!-- 이 저장소가 무엇이고 누가 쓰는지 한두 문장으로 적는다. -->

## 문서

판단의 근거는 사전학습 기억이 아니라 이 저장소의 문서다.
작업을 시작하면 아래 인덱스에서 관련 폴더를 고르고, 그 폴더의 `index.md` 에서
문서별 설명을 읽은 뒤 필요한 문서만 연다. 모든 문서를 미리 읽지 않는다.

<!-- DOC-INDEX:START -->

```text
[Docs Index]|root: ./docs|IMPORTANT: Prefer retrieval-led reasoning over pre-training-led reasoning for any tasks.|.:{index.md}|decisions:{index.md}|standards:{decisions.md,documentation.md,index.md,issues-and-pull-requests.md,troubleshooting.md,writing-style.md}
```

<!-- DOC-INDEX:END -->

## 규칙

- `docs/` 는 OKF 번들이다. 문서마다 front matter 에 `type`, `title`, `description` 을 둔다.
  자세한 규칙은 [docs/standards/documentation.md](docs/standards/documentation.md) 에 있다.
- 문서를 추가하거나 옮기거나 제목을 바꾸면 `bash scripts/doc-index.sh` 로 인덱스를 다시 만든다.
  `index.md` 와 위 인덱스 블록은 손으로 고치지 않는다.
- 되돌리기 어려운 결정은 `docs/decisions/` 에 MADR 형식으로 남긴다.
  [docs/standards/decisions.md](docs/standards/decisions.md)
- 오류를 만나면 원격 저장소의 이슈를 닫힌 것까지 먼저 검색한다. 해결한 문제는 이슈로 남긴다.
  [docs/standards/troubleshooting.md](docs/standards/troubleshooting.md)
- 이슈와 PR(MR) 본문은 [docs/standards/issues-and-pull-requests.md](docs/standards/issues-and-pull-requests.md) 의 구조를 따른다.
- 문서, 산출물, 주석, 프롬프트는 [docs/standards/writing-style.md](docs/standards/writing-style.md) 를 따른다.

## 검증

```bash
bash scripts/doc-index.sh --check
```

새 클론에서는 `git config core.hooksPath .githooks` 를 한 번 실행해 커밋 전 검사를 켠다.
