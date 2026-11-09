---
type: Standard
title: 이슈와 PR
description: 이슈와 PR이 담아야 하는 내용과 고를 템플릿을 정한다.
tags: [issues, pull-requests]
---

# 이슈와 PR

이슈와 PR은 템플릿으로 쓰고, 이 문서는 템플릿이 따르는 규칙을 정한다. GitLab의 merge request(MR)도 이 문서에서는 PR이라고 부른다.
명령줄 도구는 템플릿을 적용하지 않는다. 그래서 에이전트가 명령줄로 이슈나 PR을 만들 때는 템플릿 파일을 읽고 같은 절을 직접 쓴다.

## 템플릿 위치

| 서비스 | 이슈 템플릿 | PR 템플릿 |
| --- | --- | --- |
| GitHub, Gitea, Forgejo | `.github/ISSUE_TEMPLATE/` | `.github/pull_request_template.md` |
| GitLab | `.gitlab/issue_templates/` | `.gitlab/merge_request_templates/Default.md` |

## 이슈

| 템플릿 | 라벨 | 설명 |
| --- | --- | --- |
| 버그 | `bug` | 제품이 문서나 기대와 다르게 동작한다 |
| 기능 요청 | `enhancement` | 새 기능이나 동작 변경을 제안한다 |
| 트러블슈팅 | `troubleshooting` | 설치, 환경, CI, 도구 문제와 해결 방법을 기록한다. [트러블슈팅](troubleshooting.md)을 따른다 |

- 이슈 하나에는 문제 하나만 쓴다. 문제가 섞이면 하나만 해결된 이슈를 닫을 수 없다.
- 제목과 본문의 문장 끝은 [문장과 낱말](writing-style.md#문장과-낱말)을 따른다.
- 오류와 로그는 스크린샷이 아니라 텍스트로 붙인다. 텍스트여야 검색된다.
- 비밀값과 개인 정보를 지우고 올린다.
- 보안 취약점은 공개 이슈로 올리지 않고 비공개 경로로 알린다.

## PR

- PR 하나에는 목적 하나만 담는다. 리팩터링과 동작 변경을 나눠야 리뷰어가 동작 변경을 놓치지 않는다.
- 제목은 [커밋 메시지](writing-style.md#커밋-메시지)의 제목 형식으로 쓴다.
- 본문은 PR 템플릿의 절을 모두 채운다. 문장 끝은 [문장과 낱말](writing-style.md#문장과-낱말)을 따른다.
- 이슈는 닫는 키워드(`Closes #123`)로 연결한다. GitHub, GitLab, Gitea는 PR이 병합되면 연결된 이슈를 닫는다.
- 되돌리기 어려운 결정을 담은 PR은 [결정 기록](decisions.md)을 함께 올린다.
- 코드가 바뀌면 그 코드를 설명하는 문서도 같은 PR에서 고친다. 따로 고치면 그사이에 문서가 틀린 정보가 된다.

## 함께 고칠 곳

이 문서를 바꾸면 저장소에 있는 템플릿 파일을 함께 고친다. 파일 위치는 [템플릿 위치](#템플릿-위치)에 있다.

## 검사

자동 검사는 없다. 리뷰에서 확인한다.

## 같이 보기

- [트러블슈팅](troubleshooting.md)
- [결정 기록](decisions.md)
