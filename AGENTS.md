# AGENTS.md

`repo-scaffold` 스킬의 소스 저장소다. 고칠 곳은 `skills/repo-scaffold/` 하나다.

- `skills/repo-scaffold/assets/`는 다른 저장소에 복사되는 템플릿이다.
  그 안의 `AGENTS.md`와 `docs/`는 이 저장소에 대한 지침이 아니다. [글쓰기](#글쓰기)에 적은 규칙 하나만 예외다.
- 템플릿 문서(`assets/docs/`)를 고치면 `bash skills/repo-scaffold/assets/scripts/doc-index.sh`로
  템플릿의 인덱스를 다시 만든다.
- 스킬의 동작이 바뀌면 `SKILL.md`, `skill-card.md`, `evals/evals.json`을 함께 고친다.

## 글쓰기

이 저장소의 문서, 주석, 커밋 메시지, 이슈, PR은 템플릿의 [글쓰기 규칙](skills/repo-scaffold/assets/docs/standards/writing-style.md)을 따른다.
이 저장소용 사본은 두지 않는다. 사본이 있으면 한쪽만 고쳐져서 두 규칙이 달라진다.

## 검증

끝내기 전에 두 검사를 통과시킨다.

```bash
bash .github/scripts/validate-skills.sh     # 스킬 계약. yq와 jq가 필요하다
bash skills/repo-scaffold/tests/smoke.sh    # 스캐폴딩 동작
```
