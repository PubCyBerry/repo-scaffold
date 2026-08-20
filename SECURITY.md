# 보안 정책

## 취약점 신고

공개 이슈로 올리지 않는다. GitHub 의
[Security Advisories](https://github.com/pubcyberry/repo-scaffold/security/advisories/new)
로 비공개 신고한다.

포함할 내용:

- 영향 범위: 무엇이 노출되거나 실행되는가
- 재현 절차
- 영향받는 커밋 또는 버전

## 이 스킬의 위협 표면

Agent Skill 은 에이전트에게 **명령을 지시하는 텍스트**다. 스킬 자체가 공급망 표면이다.
아래는 이 저장소가 스스로에게 지키는 선이다.

| 항목 | 정책 |
| --- | --- |
| 쓰기 범위 | `assets/scaffold.sh` 는 `--target` 디렉터리 바깥에 쓰지 않는다 |
| 덮어쓰기 | 기존 파일을 절대 덮어쓰지 않는다. `--dry-run` 이 PLAN/SKIP 을 먼저 보여준다 |
| 전역 설정 | 사용자의 전역 git 설정을 변경하지 않는다 |
| 네트워크 | 스캐폴딩 자체는 네트워크를 쓰지 않는다. pre-commit 설치 단계에서만 다운로드가 일어난다 |
| 자격 증명 | 스킬은 어떤 키도 요구하지 않는다. 생성되는 `check-secrets.sh` 는 staged 자격 증명을 커밋 전에 차단한다 |

스킬 텍스트가 위 선을 넘도록 유도하는 변경(임의 URL 실행, 대상 밖 경로 쓰기, 자격 증명 요구)은
기능 제안이 아니라 보안 이슈로 취급한다.

## 이 저장소의 자격 증명 취급

이 저장소는 자격 증명을 하나도 쓰지 않는다. 스킬도 요구하지 않는다.
`.env.example` 은 키 이름조차 예시뿐이고 값은 전부 비어 있다.

그래도 검사는 매 커밋 돈다. 값이 없다는 사실을 사람이 기억하는 것과 검사가 확인하는 것은 다르다.

```bash
bash tests/check-secrets.sh    # staged 자격 증명 스캔. pre-commit 이 자동으로도 돈다
bash tests/check-env.sh        # .env 와 .env.example 키 동기화
```

**이 파일은 스캐폴딩이 배포하는 `SECURITY.md` 와 다른 문서다.** 배포되는 쪽은 자격 증명 취급
규약이고 이 파일은 취약점 신고 정책이다. 자격 증명을 다루는 저장소가 쓸 규약 원본은
[skills/repo-scaffold/assets/root/SECURITY.md](skills/repo-scaffold/assets/root/SECURITY.md)
에 있다. 두 문서가 같은 파일명을 두고 부딪힌 이유와 결정은
[ADR 0004](docs/architecture/adr/0004-keep-the-vulnerability-policy-at-security-md.md) 에 있다.

## 에이전트 훅

`.claude/settings.json` 과 `.codex/hooks.json` 은 도구 호출 직전과 직후에 이 저장소의
스크립트를 실행한다. 클론한 사람의 기계에서 도는 실행 코드다.

두 설정과 `scripts/agent-hooks/` 아래 스크립트를 고치는 변경은 코드 변경으로 보고 리뷰한다.
훅이 저장소 밖으로 값을 보내게 하거나, 대상 밖 경로에 쓰게 하거나, 자격 증명을 읽게 만드는
변경은 기능 제안이 아니라 보안 이슈다.

## 지원 범위

`main` 브랜치의 최신 커밋만 지원한다.
