# AGENTS.md

`repo-scaffold` 스킬의 원본 저장소다. 수정 대상은 `skills/repo-scaffold/`다.

- `skills/repo-scaffold/assets/`는 다른 저장소에 복사되는 템플릿이다. 그 안의 `AGENTS.md`와 `docs/`는 이 저장소의 지침이 아니고, [글쓰기](#글쓰기)에 적은 규칙 하나만 예외다.
- 템플릿 문서(`assets/docs/`)를 고치면 `bash skills/repo-scaffold/assets/scripts/doc-index.sh`로 템플릿의 인덱스를 다시 만든다.
- 스킬의 동작이 바뀌면 `SKILL.md`, `skill-card.md`, `evals/evals.json`을 함께 고친다.

## 글쓰기

이 저장소의 문서, 주석, 커밋 메시지, 이슈, PR은 템플릿의 [글쓰기 규칙](skills/repo-scaffold/assets/docs/standards/writing-style.md)을 따른다. 사본을 두면 한쪽만 고쳐지므로 이 저장소용 사본은 두지 않는다.

## 검증

작업을 끝내기 전에 다음 검사를 통과시킨다.

```bash
bash .github/scripts/validate-skills.sh     # 스킬 계약 검사. yq, jq 필요
bash skills/repo-scaffold/tests/smoke.sh    # 스캐폴딩 동작 검사
```
