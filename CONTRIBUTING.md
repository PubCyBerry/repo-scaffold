# 기여 가이드

이 저장소는 `repo-scaffold` 스킬의 **원본**이다. 스킬 수정은 여기서 하고,
[pubcyberry/skills](https://github.com/pubcyberry/skills) 카탈로그의 복사본은 건드리지 않는다.
카탈로그 쪽은 동기화 워크플로가 덮어쓰므로 거기서 고친 내용은 다음 sync 에 사라진다.

```
이 저장소 (원본)  ──sync──▶  pubcyberry/skills (카탈로그)  ──npx skills add──▶  사용자
     여기서 고친다              자동 생성. 손대지 않는다
```

## 변경 절차

0. 훅과 린트 도구를 설치한다. 클론마다 한 번이다.

   ```bash
   uv tool install prek
   for t in shellcheck-py shfmt-py actionlint-py zizmor; do uv tool install "$t"; done
   prek install
   ```

1. 브랜치를 판다.
2. `skills/repo-scaffold/` 아래를 고친다.
3. 아래 세 검증을 통과시킨다.

   ```bash
   prek run --all-files                        # shellcheck, shfmt, actionlint, zizmor
   bash .github/scripts/validate-skills.sh
   bash skills/repo-scaffold/tests/smoke.sh
   ```

4. PR 을 연다. CI 가 같은 검증을 다시 돌린다.

`assets/` 아래 셸 스크립트도 이 저장소의 `.editorconfig` 로 형식을 맞춘다.
스캐폴딩된 저장소가 받는 `.editorconfig` 와 같은 내용이라, 여기서 통과하면 거기서도 통과한다.

`assets/` 의 템플릿을 고쳤으면 스모크 테스트가 스캐폴딩 결과에 대해
`check-docs.sh`, `check-shell.sh`, `check-workflows.sh`, `check-env.sh`, `check-secrets.sh` 를 돌린다.
템플릿만 고치고 검증 스크립트를 안 고치면 거기서 잡힌다.

## `SKILL.md` 를 고칠 때

`description` 이 발동 정확도를 전부 결정한다. 무엇을 하는 스킬인지만 적으면 오발동한다.
세 가지를 모두 담는다.

| 요소 | 왜 |
| --- | --- |
| 무엇을 하는가 | 후보에 오르기 위해 |
| **언제 발동하는가** | 스킬 이름을 말하지 않는 실제 표현을 그대로 넣는다. 한국어와 영어 둘 다 |
| **언제 발동하지 않는가** | 인접 요청을 명시적으로 다른 곳으로 보낸다. 이게 없으면 과발동한다 |

`description` 은 1024자를 넘기지 않는다. CI 가 검사한다.

내용이 길어지면 `SKILL.md` 가 아니라 `references/` 로 민다.
`SKILL.md` 는 활성화 시점에 통째로 컨텍스트에 들어가고, `references/` 는 필요할 때만 읽힌다.

## `evals/evals.json` 을 같이 고친다

트리거 문구를 바꿨으면 태스크셋도 바꾼다. 형식:

```json
{
  "skill_name": "repo-scaffold",
  "evals": [
    {
      "id": "repo-scaffold.<kind>.<lang>.vN",
      "prompt": "실제 사용자가 칠 법한 문장",
      "expected_skill": "repo-scaffold",
      "expected_output": "기대 동작 한 문장",
      "assertions": ["검증 가능한 진술", "..."]
    }
  ]
}
```

- `expected_skill: null` 이면 **발동하면 안 되는** 케이스다. 최소 1개는 있어야 하고 CI 가 검사한다.
- positive 는 명시 호출 1개로 끝내지 말고, 스킬 이름을 말하지 않는 암묵 표현을 한국어·영어로 넣는다.

## 커밋

Conventional Commits 를 쓴다.

```
feat(repo-scaffold): add --lang en path to the doc index generator
fix(repo-scaffold): stop clobbering an existing .editorconfig
docs: clarify hook installation on Windows
chore: sync catalog metadata
```
