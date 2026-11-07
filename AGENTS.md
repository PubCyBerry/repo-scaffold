# AGENTS.md

`repo-scaffold` 스킬의 소스 저장소다. 고칠 곳은 `skills/repo-scaffold/` 하나다.

- `skills/repo-scaffold/assets/` 는 다른 저장소에 복사되는 템플릿이다.
  그 안의 `AGENTS.md` 와 `docs/` 는 이 저장소에 대한 지침이 아니다.
- 템플릿 문서(`assets/docs/`)를 고치면 `bash skills/repo-scaffold/assets/scripts/doc-index.sh` 로
  템플릿의 인덱스를 다시 만든다.
- 스킬의 동작이 바뀌면 `SKILL.md`, `skill-card.md`, `evals/evals.json` 을 함께 고친다.

## 검증

끝내기 전에 두 검사를 통과시킨다.

```bash
bash .github/scripts/validate-skills.sh     # 스킬 계약. yq 와 jq 가 필요하다
bash skills/repo-scaffold/tests/smoke.sh    # 스캐폴딩 동작
```
