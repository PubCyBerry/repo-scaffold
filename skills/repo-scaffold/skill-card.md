# Skill Card: `repo-scaffold`

## Description

저장소를 에이전트가 문서로 탐색할 수 있는 형태로 스캐폴딩한다. AGENTS.md 문서 인덱스,
`docs/` 계층과 front matter 규약, 바로 쓰는 규약 문서 14종, `just verify` 하나로 좁힌 명령
레이어, 그 규약이 썩지 않게 잡아 두는 3단계 훅과 GitHub Actions 를 한 번에 세운다.

This skill is ready for commercial and non-commercial use under the MIT license.

## Owner

PubCyBerry <https://github.com/pubcyberry>

## License / Terms of Use

MIT. See [LICENSE](../../LICENSE).

## Use Case

새 저장소를 시작하거나, 이미 파일이 있는 저장소에 문서 규약을 얹으려는 개발자.
목표는 에이전트가 사전학습 기억이 아니라 저장소 안 문서를 근거로 판단하게 만드는 것이다.
부수 목표는 에이전트가 외울 명령을 하나로 줄이는 것이다. `just verify` 가 Definition of Done 이다.

## Deployment Geography

Global.

## Requirements / Dependencies

스캐폴딩 자체와 스캐폴딩 결과를 검증하는 단계는 의존성이 다르다.

| 단계 | 필요한 것 |
| --- | --- |
| 스캐폴딩 (`assets/scaffold.sh`) | bash, git, GNU sed. Windows는 Git Bash |
| 도구 설치 (`just bootstrap`) | uv, 네트워크. commitlint까지 깔려면 Node 22.12 이상 |
| 검증 (`just verify`) | `tools.txt`의 도구들. 없으면 로컬 SKIP, `CI=true`에서 FAIL |

`tools.txt`가 고정하는 도구는 열이다: rust-just 1.58.0, prek 0.4.13, shellcheck-py 0.11.0.1,
shfmt-py 4.0.0, actionlint-py 1.7.12.24, zizmor 1.29.0, rumdl 0.2.55, vale 3.13.0.0,
yamllint 1.38.0, check-jsonschema 0.38.0. 파이썬 도구(ruff, mypy, pytest, coverage)는
`pyproject.toml`의 dev 그룹에, commitlint 21.2.2는 `package.json`에 있다.

gitleaks, OSV-Scanner, lychee는 **CI 전용**이다. PyPI 밖이고 네트워크나 전체 이력을 요구해서
개발자 머신에 요구하지 않는다. 없으면 로컬 SKIP이고 CI의 전용 잡이 그 자리를 채운다.

- **Requires API key or external credential:** No
- **Credential type(s):** None. `zizmor`는 `GH_TOKEN`이 있으면 온라인 감사까지 하고 없으면
  `--offline`으로 돈다. 원격 GitHub 설정을 바꾸는 `scripts/apply-github-*.sh`는 `gh` 인증을
  쓰지만 **인자 없이 부르면 dry-run**이고 `--apply`를 줘야 실제로 바꾼다.

프롬프트, 로그, 출력에 비밀값을 넣지 않는다. 스킬이 생성하는 `check-secrets.sh` 훅은
staged 자격 증명을 커밋 전에 잡는 용도이며, 이미 유출된 값을 회수해 주지는 않는다.

## Known Risks and Mitigations

| Risk | Mitigation |
| --- | --- |
| 대상 저장소에 파일을 생성한다 | `--dry-run`이 PLAN/SKIP/OMIT/NOTE를 먼저 출력한다. 기존 파일은 절대 덮어쓰지 않는다 |
| 잘못된 `--target`으로 엉뚱한 디렉터리를 건드릴 수 있다 | git 저장소가 아니면 실패한다. `--init`은 명시할 때만 동작한다 |
| 설정 파일이 이미 있으면 우리 내용이 안 들어간다 | `NOTE` 판정으로 원본 경로를 짚어준다. TOML과 JSON은 자동 병합하지 않는다. 주석과 순서가 사라지면 의도를 알 수 없다 |
| 훅을 설치하지 않으면 인덱스가 낡는다 | `just bootstrap`이 훅 세 종류를 한 번에 건다. 낡은 인덱스는 없는 것보다 나쁘다 |
| `prek install`만 부르면 commit-msg와 pre-push가 안 걸린다 | `default_install_hook_types`를 설정에 두고 `check-hooks.sh`가 그 키와 실제 `stages:`를 대조한다 |
| 훅 설치가 전역 git 설정을 건드릴 우려 | `GIT_CONFIG_GLOBAL=/dev/null` 우회를 안내하고 전역 설정은 변경하지 않는다 |
| 린트 도구가 없으면 검사가 조용히 넘어간다 | 로컬 SKIP은 화면에 그대로 찍히고 `CI=true`에서는 FAIL이다. 막는 지점을 커밋에서 머지로 옮긴 것이다 |
| 규약 문서 14종이 팀 규칙과 충돌할 수 있다 | 기존 저장소에서는 같은 주제의 규약이 있으면 넣지 않는다. 처리는 [references/retrofit.md](references/retrofit.md)에 있다 |
| 룰셋 예제를 잘못 걸면 기본 브랜치가 잠긴다 | 예제로만 깔고 적용은 사람이 한다. 기본 예제가 1인 저장소를 가정해 본인 PR을 막는 설정을 받지 않게 하고, 승인자가 둘 이상일 때만 team 예제를 쓴다 |
| 라벨이 없으면 Issue Form이 라벨을 조용히 버린다 | `.github/labels.yml`을 단일 출처로 두고 `apply-github-labels.sh`가 만든다. `just labels-check`가 드리프트를 검사만 한다 |
| `just verify`와 훅이 갈릴 수 있다 | `verify`가 prek를 우회하는 대가다. `just check`로 대조한다. 자동 parity 검사는 넣지 않았다 |

## References

- [Agent Skills specification](https://agentskills.io/specification)
- [prek](https://prek.j178.dev/)
- [just](https://just.systems/man/en/)
- [rumdl](https://rumdl.dev/)
- [Vale](https://vale.sh/)
- [zizmor](https://docs.zizmor.sh/)
- [Conventional Commits](https://www.conventionalcommits.org/)
- [`skills` CLI](https://github.com/vercel-labs/skills)

## Skill Output

- **Output type(s):** Shell commands, generated files (Markdown, YAML, TOML, JSON, shell,
  Python), diagnostics
- **Output format:** 대상 저장소에 기록되는 파일 + 터미널 ADD/PLAN/SKIP/OMIT/NOTE/FAIL 리포트
- **Side effects:** `--target` 디렉터리 내부에만 기록한다. 생성한 경로만 `git add -N` 한다.
  원격 GitHub 설정은 바꾸지 않는다. 그쪽 스크립트는 dry-run이 기본이다

한 번 돌리면 105개 안팎의 파일이 생긴다. 다섯 덩어리다.

| 덩어리 | 내용 |
| --- | --- |
| 명령 레이어 | `Justfile`, `tools.txt`, `scripts/{bootstrap,doctor,fmt,fix,run-all}.sh` |
| 검증 | `tests/check-*.sh` 13종, `tests/run-tests.sh`, `.pre-commit-config.yaml`, `schemas/`, `scripts/docs_{freshness,graph}.py` |
| 문서 | `AGENTS.md`, `CLAUDE.md`, `README.md`, `docs/` 5계층, 규약 문서 14종, `docs/architecture/adr/` |
| 도구 설정 | `.rumdl.toml`, `.vale.ini`, `styles/`, `.shellcheckrc`, `.yamllint.yaml`, `.gitleaks.toml`, `lychee.toml`, `renovate.json`, `pyproject.toml`, `package.json`, `commitlint.config.mjs` |
| GitHub | 워크플로 6종, `.github/ISSUE_TEMPLATE/`, `pull_request_template.md`, `labels.yml`, `CODEOWNERS.example`, `rulesets/`, `scripts/{check_pr_metadata.py,apply-github-*.sh}` |

## Evaluation

- **Task set:** [`evals/evals.json`](evals/evals.json): 8 tasks (6 positive activation,
  2 negative activation)
- **Automated tests:** [`tests/smoke.sh`](tests/smoke.sh): 스캐폴딩 멱등성, 심링크 거부,
  경쟁 생성, 특수문자 치환, 그리고 스캐폴딩 결과가 자기가 배포한 검사 스크립트 전부를
  통과하는지 확인한다. 렌더된 `Justfile`이 실제로 파싱되는지, 검사기가 심어둔 결함을
  실제로 잡는지(루트 기준 링크, 중복 id, 금지 문자 커밋 제목, PR 계약 위반 4종과 면제
  경로)까지 본다.
  CI에서 ubuntu와 windows 양쪽에 매 PR 실행
- **Live agent benchmark:** 아직 실행하지 않았다. `BENCHMARK.md`가 없는 이유이며, 태스크셋은
  평가 러너가 붙는 즉시 돌릴 수 있도록 미리 넣어 두었다. 성능 수치를 인용하지 말 것.

## Skill Version

소스 커밋 SHA로 추적한다: `git log -1 --format=%h -- skills/repo-scaffold`.
