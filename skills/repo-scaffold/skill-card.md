# Skill Card: `repo-scaffold`

## Description

에이전트가 사전학습 기억이 아니라 저장소 안의 문서를 근거로 일하게 만드는 최소 구조를 깐다.
자동 생성 문서 인덱스가 든 `AGENTS.md`, OKF 형식의 `docs/`, MADR 결정 기록 자리,
원격 저장소 이슈로 관리하는 트러블슈팅, GitHub·GitLab·Gitea 에서 쓰는 PR(MR) 과 이슈 템플릿,
인덱스가 낡지 않게 막는 pre-commit 훅과 CI 잡 하나다.

This skill is ready for commercial and non-commercial use under the MIT license.

## Owner

PubCyBerry <https://github.com/pubcyberry>

## License / Terms of Use

MIT. See [LICENSE](../../LICENSE).

## Use Case

새 저장소를 시작하거나, 이미 파일이 있는 저장소에 문서 체계를 얹으려는 개발자와 에이전트.

## Deployment Geography

Global.

## Requirements / Dependencies

| 단계 | 필요한 것 |
| --- | --- |
| 스캐폴딩 (`assets/scaffold.sh`) | bash, git. Windows 는 Git Bash |
| 검사 (`scripts/doc-index.sh`) | bash, find, sort, awk, cmp, tr. git 은 쓰지 않는다. BusyBox 에서도 돈다 |
| GitLab CI 잡 | `alpine` 이미지에 `apk add bash` |

- **Requires API key or external credential:** No
- **Credential type(s):** None

## Known Risks and Mitigations

| Risk | Mitigation |
| --- | --- |
| 대상 저장소에 파일을 만든다 | `--dry-run` 이 계획을 먼저 보여준다. 기존 파일은 덮어쓰지 않는다. noclobber 로 써서 검사한 뒤에 생긴 파일도 덮어쓰지 않는다 |
| 엉뚱한 디렉터리에 깔 수 있다 | git 저장소의 루트가 아니면 멈춘다. `--init` 은 명시할 때만 동작한다 |
| 심링크를 따라 대상 밖에 쓸 수 있다 | 경로 중간이나 끝이 심링크면 쓰지 않고 `FAIL` 로 보고한다 |
| 기존 훅 관리자를 끌 수 있다 | `core.hooksPath` 나 다른 훅 설정이 있으면 바꾸지 않고 `NOTE` 로 알린다 |
| 기존 `CLAUDE.md` 때문에 Claude Code 가 `AGENTS.md` 를 읽지 않는다 | `CLAUDE.md` 가 있으면 `NOTE` 로 알린다 |
| 훅을 켜지 않은 클론에서 인덱스가 낡는다 | CI 잡이 같은 검사를 돌린다 |
| 템플릿의 라벨이 원격에 없으면 버려진다 | 규약 문서가 라벨 생성 명령을 forge 별로 적는다 |

## References

- [Agent Skills specification](https://agentskills.io/specification)
- [Open Knowledge Format v0.2](https://github.com/GoogleCloudPlatform/knowledge-catalog/blob/main/okf/SPEC.md)
- [MADR 4.0](https://adr.github.io/madr/)
- [GitLab description templates](https://docs.gitlab.com/user/project/description_templates/)
- [Gitea issue and pull request templates](https://docs.gitea.com/usage/issue-pull-request-templates)

## Skill Output

- **Output type(s):** 대상 저장소에 기록되는 파일(Markdown, YAML, shell), 터미널 보고
- **Output format:** 파일마다 `ADD`/`PLAN`/`SKIP`/`NOTE`/`FAIL` 한 줄
- **Side effects:** 대상 저장소 안에만 쓴다. `core.hooksPath` 를 저장소 설정에 쓰고,
  실행 비트를 기록하려고 `.githooks/pre-commit` 하나를 스테이징한다. 네트워크를 쓰지 않는다

## Evaluation

- **Task set:** [`evals/evals.json`](evals/evals.json): positive 와 negative 발동 케이스
- **Automated tests:** [`tests/smoke.sh`](tests/smoke.sh): 빈 저장소와 기존 저장소에 깔기,
  멱등성, github 와 gitlab 형식, dry-run, `--init`, 심링크 거부, front matter 검사,
  인덱스 재생성, CRLF 허용, pre-commit 훅 동작. CI 에서 ubuntu, macOS, windows 에서 돈다
- **Live agent benchmark:** 아직 실행하지 않았다. 성능 수치를 인용하지 않는다

## Skill Version

소스 커밋 SHA 로 추적한다: `git log -1 --format=%h -- skills/repo-scaffold`.
린터, 커밋 규약, 보안 스캔, GitHub 거버넌스까지 깔던 이전 판은 `v1-full` 태그에 있다.
