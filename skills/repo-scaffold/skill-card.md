# Skill Card — `repo-scaffold`

## Description

저장소를 에이전트가 문서로 탐색할 수 있는 형태로 스캐폴딩한다. AGENTS.md 문서 인덱스,
`docs/` 계층과 front matter 규약, 바로 쓰는 규약 문서 8종, 그리고 그 규약이 썩지 않게
잡아 두는 커밋 훅을 한 번에 세운다.

This skill is ready for commercial and non-commercial use under the MIT license.

## Owner

PubCyBerry — <https://github.com/pubcyberry>

## License / Terms of Use

MIT. See [LICENSE](../../LICENSE).

## Use Case

새 저장소를 시작하거나, 이미 파일이 있는 저장소에 문서 규약을 얹으려는 개발자.
목표는 에이전트가 사전학습 기억이 아니라 저장소 안 문서를 근거로 판단하게 만드는 것이다.

## Deployment Geography

Global.

## Requirements / Dependencies

- bash, git, GNU sed. Windows는 Git Bash 기준.
- 훅 설치 단계에서만: prek(단일 바이너리, `uv tool install prek` 또는 `brew install prek`)와 다운로드용 네트워크.
- 셸/워크플로 훅이 부르는 도구: `shellcheck`, `shfmt`, `actionlint`, `zizmor`.
  없으면 로컬에서는 SKIP이고 `CI=true`인 환경에서 FAIL이다.
- **Requires API key or external credential:** No
- **Credential type(s):** None (zizmor는 `GH_TOKEN`이 있으면 온라인 감사까지 하고, 없으면 `--offline`으로 돈다)

프롬프트, 로그, 출력에 비밀값을 넣지 않는다. 스킬이 생성하는 `check-secrets.sh` 훅은
staged 자격 증명을 커밋 전에 잡는 용도이며, 이미 유출된 값을 회수해 주지는 않는다.

## Known Risks and Mitigations

| Risk | Mitigation |
| --- | --- |
| 대상 저장소에 파일을 생성한다 | `--dry-run`이 PLAN/SKIP을 먼저 출력한다. 기존 파일은 절대 덮어쓰지 않는다 |
| 잘못된 `--target`으로 엉뚱한 디렉터리를 건드릴 수 있다 | git 저장소가 아니면 실패한다. `--init`은 명시할 때만 동작한다 |
| 훅을 설치하지 않으면 인덱스가 낡는다 | SKILL.md 6절이 훅 설치를 필수 단계로 명시한다. 낡은 인덱스는 없는 것보다 나쁘다 |
| 훅 설치가 전역 git 설정을 건드릴 우려 | `GIT_CONFIG_GLOBAL=/dev/null` 우회를 안내하고 전역 설정은 변경하지 않는다 |
| 린트 도구가 없으면 검사가 조용히 넘어간다 | 로컬 SKIP은 화면에 그대로 찍히고, `CI=true`인 환경에서는 FAIL이다. 막는 지점을 커밋에서 머지로 옮긴 것이다 |
| 규약 문서 8종이 팀 규칙과 충돌할 수 있다 | 기존 저장소에서는 같은 주제의 규약이 있으면 넣지 않는다. 처리는 [references/retrofit.md](references/retrofit.md)에 있다 |

## References

- [Agent Skills specification](https://agentskills.io/specification)
- [prek](https://prek.j178.dev/)
- [pre-commit](https://pre-commit.com/)
- [zizmor](https://docs.zizmor.sh/)
- [`skills` CLI](https://github.com/vercel-labs/skills)

## Skill Output

- **Output type(s):** Shell commands, generated files (Markdown, YAML, shell scripts), diagnostics
- **Output format:** 대상 저장소에 기록되는 파일 + 터미널 PLAN/SKIP/FAIL 리포트
- **Side effects:** `--target` 디렉터리 내부에만 기록한다. 생성한 경로만 `git add -N` 한다

## Evaluation

- **Task set:** [`evals/evals.json`](evals/evals.json) — 6 tasks (4 positive activation, 2 negative activation)
- **Automated tests:** [`tests/smoke.sh`](tests/smoke.sh) — 스캐폴딩 멱등성, 심링크 거부, 경쟁 생성, 그리고
  스캐폴딩 결과가 자기가 배포한 검증 5종(docs/shell/workflows/env/secrets)을 통과하는지 확인. CI에서 매 PR 실행
- **Live agent benchmark:** 아직 실행하지 않았다. `BENCHMARK.md`가 없는 이유이며, 태스크셋은
  평가 러너가 붙는 즉시 돌릴 수 있도록 미리 넣어 두었다. 성능 수치를 인용하지 말 것.

## Skill Version

소스 커밋 SHA로 추적한다 — `git log -1 --format=%h -- skills/repo-scaffold`.
