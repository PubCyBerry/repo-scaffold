# 기여 가이드

이 저장소는 `repo-scaffold` 스킬의 **원본**이다. 스킬 수정은 여기서 하고,
[pubcyberry/skills](https://github.com/pubcyberry/skills) 카탈로그의 복사본은 건드리지 않는다.
카탈로그 쪽은 동기화 워크플로가 덮어쓰므로 거기서 고친 내용은 다음 sync 에 사라진다.

```text
이 저장소 (원본)  ──sync──▶  pubcyberry/skills (카탈로그)  ──npx skills add──▶  사용자
     여기서 고친다              자동 생성. 손대지 않는다
```

## 준비

클론마다 한 번이다. `just` 하나만 손으로 깔고 나머지는 `just bootstrap` 이 채운다.

```bash
uv tool install rust-just
just bootstrap
just doctor
```

`just bootstrap` 이 하는 일은 넷이다. [tools.txt](tools.txt) 의 도구 설치, `uv sync`,
`npm ci`, 그리고 pre-commit 과 commit-msg 와 pre-push 훅 설치다.
훅 세 종류를 다 걸어야 한다. 하나라도 빠지면 그 스테이지의 검사가 한 번도 안 돈다.

## 변경 절차

1. 브랜치를 판다.
2. `skills/repo-scaffold/` 아래를 고친다.
3. `just verify` 를 통과시킨다. 이것이 Definition of Done 이다.

   ```bash
   just verify
   ```

4. 스킬 계약과 스모크 테스트를 돌린다. 이 둘은 이 저장소만의 검사라
   배포되는 Justfile 에 없다.

   ```bash
   bash .github/scripts/validate-skills.sh
   bash skills/repo-scaffold/tests/smoke.sh
   ```

5. PR 을 연다. CI 가 같은 검증을 다시 돌린다.

`just verify` 가 통과하지 않으면 작업이 끝난 것이 아니다.
무엇이 도는지는 [Justfile](Justfile) 에 있고, `just` 를 인자 없이 치면 목록이 나온다.

## 자기 적용

이 저장소는 자기가 배포하는 것을 자기에게 적용한 상태다. 루트의 `AGENTS.md`, `docs/`,
`Justfile`, `tests/check-*.sh`, `scripts/` 는 전부 `assets/` 의 템플릿에서 나왔다.

**템플릿을 고쳤으면 루트의 복사본도 같이 고친다.** 두 벌은 자동으로 동기화되지 않는다.
`assets/` 만 고치고 루트를 두면 이 저장소가 옛 판으로 자기를 검사하게 된다.

예외는 결정 기록에 적혀 있다. 거기 없는 차이는 결정이 아니라 결함이다.

| 항목 | 차이 | 근거 |
| --- | --- | --- |
| `.pre-commit-config.yaml` | `skill-contract` 훅 하나가 더 있다 | [ADR 0002](docs/architecture/adr/0002-dogfood-the-scaffold-in-its-own-source-repository.md) |
| `.rumdl.toml`, `tests/check-prose.sh` | `skills/*/assets/` 를 검사에서 뺀다 | 같은 문서 |
| `.github/workflows/validate.yml` | 룰셋 예제에 없는 잡 이름을 쓴다 | [ADR 0003](docs/architecture/adr/0003-keep-the-skill-contract-workflow-outside-the-shipped-job-names.md) |
| `SECURITY.md` | 취약점 신고 정책이다 | [ADR 0004](docs/architecture/adr/0004-keep-the-vulnerability-policy-at-security-md.md) |

`assets/` 의 템플릿을 고쳤으면 스모크 테스트가 임시 저장소에 렌더해서
배포되는 검사 스크립트 전부를 돌린다. 템플릿만 고치고 검사 스크립트를 안 고치면 거기서 잡힌다.

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
- positive 는 명시 호출 1개로 끝내지 말고, 스킬 이름을 말하지 않는 암묵 표현을 한국어와 영어로 넣는다.

## 커밋과 PR

Conventional Commits 를 쓴다. **제목은 소문자로 시작한다.**
commitlint 의 `subject-case` 가 commit-msg 훅에서 검사하고, 같은 규격을 `pr-policy`
워크플로가 PR 제목에도 건다. squash 머지가 PR 제목으로 커밋을 합성하기 때문이다.

```text
feat(repo-scaffold): add --lang en path to the doc index generator
fix(repo-scaffold): stop clobbering an existing .editorconfig
docs: clarify hook installation on Windows
chore: sync catalog metadata
```

제목에 가운뎃점과 대시를 쓰지 않는다. 규칙은
[docs/standards/writing-style.md](docs/standards/writing-style.md) 에 있고,
`tests/check-commit-msg.sh` 가 도구 없이도 그 부분만은 검사한다.

PR 본문은 [PR 템플릿](.github/pull_request_template.md) 의 아홉 절을 채운다.
이슈를 걸거나 `policy/skip-issue` 라벨을 받아야 `pr-policy` 가 통과한다.
