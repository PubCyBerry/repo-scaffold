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

`docs/` 아래 문서는 전부 영어로 쓴다. 규칙은 [docs/standards/writing-style.md](docs/standards/writing-style.md) 에 있다.

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
| `docs/architecture/` | 시스템 구조. 그 아래 `adr/` 는 결정 기록 |

제품이나 프레임워크에 종속되는 자료는 `docs/` 아래 별도 도메인 디렉터리로 분리한다.
그 안에서도 `standards/`, `guides/`, `references/` 구분은 같다.
`architecture/` 는 최상위에 하나만 둔다. 두 제품 사이의 경계는 어느 쪽 것도 아니다.

결정 기록(ADR)은 한 번 쓰고 고치지 않는다. 결정이 바뀌면 새 기록을 쓰고 옛 기록의
`status` 를 `superseded` 로 바꾼다. 형식은 `docs/architecture/adr/index.md` 에 있다.

문서 front matter 의 `sources` 는 그 문서가 서술하는 저장소 경로다. `last_reviewed` 이후에
그 경로가 바뀌면 push 전에 검사가 막는다. `last_reviewed` 는 사람이 문서를 다시 읽었을 때만
손으로 올린다. 도구가 올리지 않는다.

## 코드 탐색

`grep` 과 `find` 를 쓰지 않는다. 아래 도구를 쓴다.

| 찾는 것 | 도구 |
| --- | --- |
| 코드 구조. 함수 호출, 클래스와 함수 정의, import, 인자 패턴 | `ast-grep` |
| 리터럴 문자열, 로그 메시지, 설정값, 주석 | `rg` (ripgrep) |
| 파일과 디렉터리 이름 | `fd` |

구조를 찾을 때 `rg` 정규식을 길게 늘리지 않는다. 그건 `ast-grep` 이 하는 일이다.
줄 단위 정규식은 여러 줄에 걸친 호출과 인자를 놓치고, 문자열 리터럴 안의 우연한 일치를 잡는다.

```bash
ast-grep --pattern 'fetchUser($$$)' --lang ts      # 호출 위치
ast-grep --pattern 'class $NAME extends Base'      # 정의
rg -n 'connection refused'                         # 로그 메시지
fd --extension py --exec-batch wc -l               # 파일 목록
```

검증 스크립트 자체는 `grep` 과 `find` 를 계속 쓴다. 훅과 CI 에서 추가 의존 없이 돌아야 한다.

## 문서 작성

보고서, 커밋 메시지, 코드 주석을 포함해 이 저장소에서 쓰는 모든 산문은
[docs/standards/writing-style.md](docs/standards/writing-style.md) 를 따른다.
언어, 어조, 표기가 거기 있다. 문서 메타데이터와 배치는 [docs/standards/documentation.md](docs/standards/documentation.md) 다.

주석과 문서와 지침은 **stateless** 하게 쓴다. 지금 저장소가 어떤 상태인지만 적고
무엇이 어떻게 바뀌었는지는 적지 않는다. "이제", "기존", "원래는", "이번에 추가",
"~에서 이름을 바꿨다" 는 읽는 쪽이 확인할 수 없는 상태를 가리킨다.
결정의 근거는 이력이 아니므로 현재 사실로 바꿔 적는다.
변경 자체를 기록하는 자리는 커밋 메시지와 ADR 둘뿐이다.

## 코드 작성

간결하고 읽기 쉬운 코드를 쓴다. 영리한 구성보다 평범한 구성을 고른다.
함수 하나는 한 가지만 한다. 이름은 무엇을 담고 무엇을 하는지로 짓는다.
추상은 이미 일어난 반복에서 뽑고, 일어날 것 같은 반복에서 만들지 않는다.
줄 수를 줄이려고 이름과 가드 절을 지우면 읽는 시간이 늘어난다.
한도와 나머지 규칙은 [docs/standards/code-quality.md](docs/standards/code-quality.md) 에 있다.

## 작업 전 확인

```bash
just verify
```

통과하지 않으면 작업이 끝난 것이 아니다. 무엇이 도는지는 [Justfile](Justfile) 에 있다.
명령을 외우지 않는다. `just` 를 인자 없이 치면 목록이 나온다.

| 명령 | 하는 일 |
| --- | --- |
| `just bootstrap` | 도구, 의존성, git 훅 설치. 클론마다 한 번 |
| `just doctor` | 환경 진단. 무엇이 없고 무엇이 어긋났는지 |
| `just verify` | Definition of Done. 검사 전체 |
| `just fmt` / `just fix` | 형식 정리와 자동 수정. 파일을 바꾼다 |

### Definition of Done

1. 요청한 구현이 끝났다
2. 관련 테스트를 추가하거나 갱신했다
3. 동작, 인터페이스, 아키텍처, 개발 절차가 바뀌었으면 문서를 갱신했다
4. 생성 산출물을 동기화했다
5. `just verify` 가 통과한다
6. 최종 diff 를 직접 확인했다
