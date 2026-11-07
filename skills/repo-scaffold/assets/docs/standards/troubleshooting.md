---
type: Standard
title: 트러블슈팅
description: 트러블슈팅 기록을 원격 저장소의 이슈로 남기고, 검색하고, 닫는 방법을 정한다.
tags: [troubleshooting, issues]
---

# 트러블슈팅

트러블슈팅 기록은 `docs/`의 파일이 아니라 원격 저장소(GitHub, GitLab, Gitea 등)의 이슈로 남긴다. 이슈를 쓰는 이유는 다음과 같다.

- 오류 메시지로 검색할 수 있다.
- 조사 과정이 댓글로 남는다.
- 문제를 고친 커밋과 PR이 이슈에 연결된다.
- 이슈가 열려 있는지 닫혔는지로 해결 여부를 알 수 있다.

## 디버깅 전 검색

오류 메시지에서 그 오류에만 나오는 부분으로 열린 이슈와 **닫힌 이슈**를 함께 검색한다. 해결한 기록은 닫힌 이슈에 있다.

| 서비스 | 명령 |
| --- | --- |
| GitHub | `gh issue list --state all --search "<오류 메시지>"` |
| GitLab | `glab issue list --all --search "<오류 메시지>"` |
| Gitea | `tea issues list --state all --keyword "<오류 메시지>"` |

닫힌 이슈가 맞으면 그 해결 방법을 적용한다. 해결 방법이 더는 통하지 않으면 이슈를 다시 열거나, 무엇이 달라졌는지 댓글로 남긴다.

## 이슈를 여는 경우

다음 중 하나에 해당하면 트러블슈팅 템플릿으로 이슈를 연다.

- 원인을 찾는 데 시간이 걸렸다.
- 다시 일어날 가능성이 크다. 설치, 환경, CI, 의존성, 도구 문제가 그렇다.

제품 코드의 결함은 트러블슈팅 기록이 아니라 버그 이슈로 올린다.

## 기록할 내용

템플릿의 절을 채우고 다음을 지킨다.

- 증상에는 오류 메시지를 스크린샷이 아니라 텍스트로 붙인다. 다음 사람은 이 텍스트로 검색한다.
- 시도한 방법에는 실패한 방법도 쓴다. 그래야 다른 사람이 같은 시도를 되풀이하지 않는다.
- 로그를 붙이기 전에 비밀값과 개인 정보를 지운다.
- 원인과 해결을 채운 뒤 이슈를 닫는다. 코드를 고쳐야 하면 PR에 닫는 키워드(`Closes #123`)를 써서 이슈와 연결한다.

## 라벨

템플릿은 `troubleshooting` 라벨을 붙인다. 원격 저장소에 없는 라벨은 이슈에 붙지 않으므로 저장소마다 한 번 만든다.

| 서비스 | 명령 |
| --- | --- |
| GitHub | `gh label create troubleshooting` |
| GitLab | `glab label create --name troubleshooting` |
| Gitea | `tea labels create --name troubleshooting --color "#d4c5f9"` |

## 이슈에서 문서로

해결 방법이 늘 지켜야 하는 규칙이 되면(필수 설치 단계, 필수 버전) 그 규칙을 `docs/`에 쓰고, 그 문서의 `sources`에 이슈 URL을 넣는다.

## 함께 고칠 곳

템플릿의 절이나 라벨을 바꾸면 저장소에 있는 템플릿 파일을 함께 고친다.

| 파일 | 설명 |
| --- | --- |
| `.github/ISSUE_TEMPLATE/troubleshooting.md` | GitHub, Gitea, Forgejo가 읽는 템플릿 |
| `.gitlab/issue_templates/Troubleshooting.md` | GitLab이 읽는 템플릿 |

## 검사

자동 검사는 없다. 리뷰에서 확인한다.

## 같이 보기

- [이슈와 PR](issues-and-pull-requests.md)
