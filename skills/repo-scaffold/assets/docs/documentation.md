---
id: standard-documentation
title: 문서 작성
type: standard
status: active
summary: 파일명, 경로 표기, front matter, 문서 구조 규칙
scope:
  - docs/**
read_when:
  - 새 문서를 만들 때
  - 기존 문서를 고칠 때
  - 문서를 어느 디렉터리에 둘지 정할 때
related:
  - index-docs
---

# 문서 작성

## 목적

저장소 문서가 한 가지 형태를 유지하도록 파일명, 경로 표기, 메타데이터, 문서 구조를 정의한다.
에이전트가 문서를 열지 말지 판단하는 근거는 front matter다. 본문을 읽어야 판단이 되면 메타데이터가 부족한 것이다.

## 범위

[docs/](docs/index.md) 하위 모든 마크다운 문서에 적용한다.

저장소 루트의 [README.md](README.md), [AGENTS.md](AGENTS.md), [CLAUDE.md](CLAUDE.md), [SECURITY.md](SECURITY.md)는 front matter 대상이 아니다.
README와 SECURITY는 호스팅 서비스가 관례 파일명으로 인식하고, CLAUDE.md는 import 한 줄이라 메타데이터가 본문보다 길어진다.
언어와 표기 규칙은 이 네 파일에도 적용한다.

## 언어

- 문서와 코드 주석은 한국어로 쓴다
- 기술 용어, 식별자, 명령어, 경로는 원어를 유지한다
- front matter는 키가 영어, 사람이 읽는 값이 한국어다. `type`, `status`, `id`처럼 고정 어휘인 값만 영어다

## 파일명

lowercase kebab-case를 쓴다.

| 규칙 | 예 |
| --- | --- |
| 소문자만 | `error-handling.md` |
| 단어 구분은 하이픈 | `commit-convention.md` |
| 밑줄, 공백, 대문자 금지 | `Error_Handling.md` 안 됨 |
| 각 디렉터리 인덱스는 `index.md` 고정 | [docs/standards/index.md](docs/standards/index.md) |

제품 버전처럼 점이 의미를 갖는 경우에만 점을 남긴다. 예: `install-4.2.md`.

## 경로 표기

저장소 안의 파일이나 디렉터리를 가리킬 때는 마크다운 링크로 쓴다. 백틱 경로만 쓰지 않는다.

**링크 대상은 문서 위치가 아니라 저장소 루트 기준 상대 경로다.** 문서를 다른 디렉터리로 옮겨도 링크가 깨지지 않는다.

```markdown
잘못: 기동 절차는 `README.md` 4장에 있다.
잘못: [테스트](../standards/testing.md)              문서 위치 기준
맞음: [테스트](docs/standards/testing.md)            저장소 루트 기준
```

- 링크 텍스트는 문서 제목이나 사람이 읽는 이름을 쓴다. 경로를 그대로 넣지 않아도 된다
- 디렉터리를 가리킬 때는 그 디렉터리의 `index.md`를 링크한다
- 글로브가 들어가 링크가 하나로 안 되면 항목을 나눠 각각 링크한다

루트 기준 경로는 마크다운 렌더러가 현재 디렉터리 기준으로 해석하므로 웹 화면에서는 링크가 걸리지 않는다.
문서를 읽는 주체가 에이전트와 로컬 편집기라 경로 안정성을 우선한다.

예외 세 가지다. 이때는 백틱을 쓴다.

- 저장소 밖 경로. 배포 패키지 내부 경로, 서버 경로, 컨테이너 안 경로가 해당한다
- 다른 저장소 안의 경로
- 실제 파일이 아니라 형식을 설명하는 패턴. 예: `{영역}_{행위}_pop.html`

## front matter

모든 문서는 YAML front matter로 시작한다.

### 필수 property

| Property | 의미 | 형식 |
| --- | --- | --- |
| `id` | 문서의 안정적인 식별자 | `<type>-<slug>`. 파일을 옮겨도 바뀌지 않는다 |
| `title` | 사람이 읽는 제목 | 본문 H1과 같게 |
| `type` | 문서 종류 | 아래 enum |
| `status` | 현재 유효성 | type별로 값이 다르다 |
| `summary` | 1문장 설명 | **개조식**. 명사 또는 명사구로 끝낸다. 서술형 종결어미를 쓰지 않는다 |
| `scope` | 적용되는 코드나 영역 | 저장소 루트 기준 경로 목록. 글로브 허용 |
| `read_when` | 언제 읽어야 하는가 | 상황 목록. 문서 제목을 되풀이하지 않는다 |

```yaml
# 개조식
summary: 예외 계층, 표준 오류 응답, 로그 레벨 규칙

# 서술형. 쓰지 않는다
summary: 예외 계층과 표준 오류 응답, 로그 레벨을 정의한다.
```

`id`는 파일 경로와 독립이다. 문서를 다른 디렉터리로 옮겨도 `id`는 유지하고, `related`로 거는 참조가 깨지지 않게 한다.

### type enum

고정이다. 이 다섯 개 밖의 값을 쓰지 않는다.

| `type` | 위치 | 성격 |
| --- | --- | --- |
| `index` | 각 디렉터리의 `index.md` | 해당 범위의 문서 목록 |
| `standard` | `standards/` 아래 | 반드시 지켜야 하는 작업 규칙 |
| `guide` | `guides/` 아래 | 어떻게 작업하는지 매뉴얼 |
| `reference` | `references/` 아래 | 외부와 보조 정보 |
| `generated` | `generated/` 아래 | 코드나 스키마에서 생성한 정보 |

디렉터리명과 `type`이 1:1이다. 상위에 도메인 디렉터리가 붙어도 규칙은 같다.

### status

type마다 쓰는 값이 다르다.

| `type` | 허용 `status` | 의미 |
| --- | --- | --- |
| `index` | `active` | 인덱스는 항상 유효하다. 다른 값을 쓰지 않는다 |
| `standard` | `draft` | 합의 전. 아직 강제하지 않는다 |
| | `active` | 적용 중. 어기면 리뷰에서 지적 대상 |
| | `deprecated` | 폐기. `supersedes`의 반대편 문서를 본다 |
| `guide` | `draft` | 절차 검증 전 |
| | `active` | 그대로 따라 하면 되는 상태 |
| | `outdated` | 절차가 현재 구현과 어긋난다. 고치기 전까지 그대로 따르지 않는다 |
| `reference` | `active` | 조회 가능 |
| | `outdated` | 원본이 바뀌었다. 값 확인 필요 |
| | `archived` | 더 이상 유지하지 않는다. 이력 보존용 |
| `generated` | `current` | 원본과 동기 상태 |
| | `stale` | 원본이 바뀌었다. 다시 생성해야 한다 |

### 추가 property

필요할 때만 쓴다. 값이 없으면 키 자체를 넣지 않는다.

| Property | 언제 | 예 |
| --- | --- | --- |
| `owners` | 담당이 갈리는 문서 | `- backend` |
| `last_reviewed` | 내용을 검토한 날짜 | `2026-01-01` |
| `related` | 같이 읽어야 하는 문서 | `- standard-testing` |
| `supersedes` | 이 문서가 대체한 문서 | `- reference-old-install` |
| `generated_from` | `type: generated` 필수 | `- src/database/schema.py` |
| `edit_policy` | 편집 제한 | `generated` (손으로 고치지 않음) |

`related`와 `supersedes`는 파일 경로가 아니라 `id`로 적는다.
날짜는 상대 표현을 쓰지 않는다. "지난주", "최근" 대신 `2026-01-01` 형태로 쓴다.

## 문서 구조

Header, Body, Footer 순서다. Body만 `type`별로 다르다.

```markdown
---
(front matter)
---

# 문서 제목

## 목적

이 문서가 무엇을 정하는지. 한두 문단.

## 범위

어디에 적용되는지. scope 를 사람이 읽는 문장으로 푼 것.

(type별 Body)

## 관련 문서

- [예외 처리와 로깅](docs/standards/error-handling.md)

## 참고

- [외부 표준 문서](https://example.com/spec)
```

- `## 관련 문서`는 저장소 안 문서만 넣는다
- `## 참고`는 외부 자료만 넣는다
- 둘 다 없으면 섹션을 생략한다. 빈 섹션을 남기지 않는다

### type별 Body

`index`

```markdown
## 탐색 순서

## 문서 목록

| 문서 | 내용 |
```

`standard`

```markdown
## 원칙

지켜야 하는 이유. 판단이 갈릴 때 근거가 되는 문장.

## 규칙

항목별 규칙. 표나 목록.

## 체크리스트

리뷰나 커밋 전에 확인할 항목.
```

`guide`

```markdown
## 사전 조건

## 절차

1. 단계

## 확인

절차가 성공했는지 판정하는 방법.

## 문제 해결

| 증상 | 조치 |
```

`reference`

```markdown
## 요약

한눈에 보는 표.

## 상세

항목별 내용.
```

`generated`

```markdown
## 생성 방법

명령과 기준 커밋 또는 태그.

## 내용

생성된 표나 목록.
```

## 문서 배치

새 문서를 만들기 전에 두 가지를 순서대로 정한다.

1. 특정 제품이나 프레임워크에 종속되는가. 그렇다면 해당 도메인 디렉터리 아래로 간다
2. 어느 카테고리인가

| 디렉터리 | 판단 기준 |
| --- | --- |
| `standards/` | 어겼을 때 리뷰에서 지적 대상이 되는가 |
| `guides/` | 순서를 따라 하면 결과가 나오는가 |
| `references/` | 사실 조회용인가. 절차가 아닌가 |
| `generated/` | 손으로 고치지 않고 다시 생성하는가 |

컴포넌트 하나에만 해당하는 실행 절차는 문서로 올리지 않고 그 컴포넌트 디렉터리의 README에 둔다.

## 인덱스 관리

인덱스는 두 층이다.

| 인덱스 | 내용 | 갱신 |
| --- | --- | --- |
| [AGENTS.md](AGENTS.md)의 문서 인덱스 | 디렉터리별 파일명 목록. 설명 없음 | **자동 생성.** 손으로 고치지 않는다 |
| [docs/index.md](docs/index.md)와 각 디렉터리 `index.md` | 문서별 한 줄 설명, 탐색 순서 | 손으로 쓴다 |

- 문서를 추가했으면 해당 디렉터리 인덱스에 한 줄 추가한다
- 인덱스 내용을 다른 문서에 중복해서 쓰지 않는다

AGENTS.md 인덱스는 [gen-doc-index.sh](scripts/gen-doc-index.sh)가 만들고
pre-commit 훅이 커밋 직전에 실행한다. 설정은 [.pre-commit-config.yaml](.pre-commit-config.yaml)에 있다.
`<!-- DOC-INDEX:START -->` 와 `<!-- DOC-INDEX:END -->` 사이를 통째로 바꾸므로
그 안에 손으로 쓴 내용을 넣으면 다음 커밋에 사라진다.

형식은 디렉터리별로 묶어 `|` 하나로 이은 한 줄이다.

```
<directory>:{<file1>,<file2>,...}|<directory>:{...}
```

훅은 클론마다 한 번 설치한다. 절차는 [README.md](README.md)의 pre-commit 훅 절에 있다.

인덱스가 바뀌면 훅이 AGENTS.md 를 고치고 스테이징한 뒤 그 커밋을 **실패시킨다**.
커밋 내용이 바뀌었다는 신호이므로 그대로 다시 커밋하면 된다. pre-commit 프레임워크의 기본 동작이다.

## stateless 유지

[AGENTS.md](AGENTS.md)와 `standards/` 문서에는 곧 낡는 정보를 넣지 않는다.
진행 상황, 할 일 목록, 현재 브랜치명, 담당자 이름이 대상이다. 그런 정보는 이슈나 별도 작업 메모에 둔다.

## 표기

제목, 표 머리글, 목록 레이블, 상태명, 선택지는 서술형 문장보다 짧은 명사 또는 명사구로 쓴다.

아래 기호는 쓰지 않고 대체 표기로 바꾼다.

| 대상 | 예 | 대체 |
| --- | --- | --- |
| 가운뎃점 (세 항목 이상) | `배포·환경·로그` | `배포, 환경, 로그` |
| 가운뎃점 (두 항목) | `빌드·기동` | `빌드와 기동` 또는 `빌드, 기동` |
| em dash, en dash (앞뒤 공백 포함) | `주의 — 공유 자원이다` | `주의: 공유 자원이다` |
| double hyphen (문장 안) | `주의 -- 공유 자원이다` | `주의: 공유 자원이다` |
| 반복 기호 | `〃` | 값을 그대로 다시 쓴다 |

예외 두 가지다.

- 명령어 옵션의 `--` (`--no-cache` 등)
- 코드 블록 안의 코드

파일 크기는 MB, GB, GiB로 쓴다. raw byte 수는 쓰지 않는다.

## 충돌 보고

문서끼리 또는 문서와 코드가 어긋나면 임의로 한쪽을 고르지 않는다. 경로, 문구, 실행 결과를 제시해 보고한다.

## 체크리스트

- 파일명이 lowercase kebab-case인가
- front matter 필수 7개가 다 있는가
- `type`이 디렉터리와 맞는가. `status`가 그 `type`에 허용된 값인가
- 저장소 안 경로를 백틱만으로 쓴 곳이 없는가
- 링크 대상이 저장소 루트 기준 경로인가
- H1이 `title`과 같은가. `## 목적`, `## 범위`가 있는가
- 문서를 추가했으면 해당 디렉터리 인덱스에 넣었는가
- [tests/check-docs.sh](tests/check-docs.sh)가 통과하는가

## 관련 문서

- [문서 인덱스](docs/index.md)
- [표준](docs/standards/index.md)
