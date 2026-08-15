---
id: index-docs
title: 문서 인덱스
type: index
status: active
summary: {{REPO_NAME}} 저장소 문서 진입점
scope:
  - docs/**
read_when:
  - 어떤 문서를 읽어야 할지 정할 때
  - 새 문서를 어디에 둘지 정할 때
related:
  - standard-documentation
---

# 문서 인덱스

## 목적

이 저장소 모든 문서의 진입점이다. 본문부터 열지 말고 여기서 대상을 먼저 고른다.

## 범위

[docs/](docs/index.md) 하위 전체.

## 탐색 순서

1. 아래 카테고리에서 디렉터리 하나를 고른다.
2. 그 디렉터리의 인덱스에서 문서 하나를 고른다.
3. 작업 도중 다른 영역이 필요해지면 그때 추가로 연다. 처음부터 전체를 불러오지 않는다.
4. 새 문서를 만들거나 파악했으면 해당 디렉터리의 인덱스에 한 줄 추가한다.

## 문서 목록

| 디렉터리 | 성격 | 언제 여나 |
| --- | --- | --- |
| [standards/](docs/standards/index.md) | 반드시 지켜야 하는 작업 규칙 | 코드나 문서를 쓰기 전 |
| [guides/](docs/guides/index.md) | 어떻게 작업하는지 매뉴얼 | 절차를 따라 실행할 때 |
| [references/](docs/references/index.md) | 외부와 보조 정보 | 사실을 조회할 때 |
| [generated/](docs/generated/index.md) | 코드나 스키마에서 생성한 정보 | 현재 구현 상태를 확인할 때 |

제품이나 프레임워크에 종속되는 자료는 `docs/` 아래 도메인 디렉터리로 분리한다.
그 안에서도 위 네 가지 구분은 같다.

### 저장소 루트 파일

front matter 대상이 아니다. 언어와 표기 규칙만 적용한다.

| 주제 | 파일 |
| --- | --- |
| 저장소 개요, 시작 | [README.md](README.md) |
| 에이전트 작업 규칙 | [AGENTS.md](AGENTS.md) ([CLAUDE.md](CLAUDE.md)는 포인터) |
| 자격 증명, 비밀값, 민감정보 취급 | [SECURITY.md](SECURITY.md) |
| 환경변수 키 목록 | [.env.example](.env.example) |
| 문서 검증 | [tests/check-docs.sh](tests/check-docs.sh) |

## 관련 문서

- [문서 작성](docs/standards/documentation.md)
- [보안](SECURITY.md)
