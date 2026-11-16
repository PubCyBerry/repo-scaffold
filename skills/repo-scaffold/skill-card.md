# Skill Card: `repo-scaffold`

## Description

에이전트가 사전학습 기억 대신 저장소의 문서를 근거로 일하도록, 대상 저장소에 최소한의 문서 체계와 검사를 추가합니다.
추가하는 파일은 자동 생성 문서 인덱스를 포함한 `AGENTS.md`, OKF 형식의 `docs/`, MADR 결정 기록 디렉터리, GitHub, GitLab, Gitea용 PR(MR) 템플릿과 이슈 템플릿, 인덱스를 최신으로 유지하는 pre-commit hook과 CI 잡, 기본 `.gitignore`와 `.gitattributes`입니다.
트러블슈팅 기록은 원격 저장소의 이슈로 관리합니다.

This skill is ready for commercial and non-commercial use under the MIT license.

## Owner

PubCyBerry <https://github.com/pubcyberry>

## License / Terms of Use

MIT. See [LICENSE](../../LICENSE).

## Use Case

새 저장소를 시작하거나 기존 저장소에 문서 체계를 도입하려는 개발자와 에이전트

## Deployment Geography

Global.

## Requirements / Dependencies

| 단계 | 필요한 것 |
| --- | --- |
| 스캐폴딩 (`assets/scaffold.sh`) | bash, git. Windows에서는 Git Bash |
| 검사 (`scripts/doc-index.sh`) | bash, find, sort, awk, cmp, tr. git 불필요. BusyBox에서도 동작 |
| GitLab CI 잡 | `alpine` 이미지에 `apk add bash` |

- **Requires API key or external credential:** No
- **Credential type(s):** None

## Known Risks and Mitigations

| Risk | Mitigation |
| --- | --- |
| 대상 저장소에 파일 생성 | `--dry-run`으로 계획을 먼저 출력. 기존 파일을 덮어쓰지 않음. noclobber로 써서 검사 이후에 생긴 파일도 보호 |
| 엉뚱한 디렉터리에 추가 | git 저장소의 루트가 아니면 중단. `--init`은 명시할 때만 동작 |
| 심링크를 따라 대상 밖에 쓰기 | 경로 중간이나 끝이 심링크면 쓰지 않고 `FAIL`로 보고 |
| 기존 hook 관리자 비활성화 | `core.hooksPath`나 다른 hook 설정이 있으면 변경하지 않고 `NOTE`로 알림 |
| 기존 `CLAUDE.md` 때문에 Claude Code가 `AGENTS.md`를 읽지 않음 | `CLAUDE.md`가 있으면 `NOTE`로 알림 |
| 기존 저장소에서 줄바꿈만 바뀐 diff 발생 | `.gitattributes`를 새로 추가할 때 CRLF로 커밋된 파일이 있으면 `NOTE`로 알리고 `git add --renormalize .` 안내 |
| hook을 켜지 않은 클론에서 인덱스가 낡음 | CI 잡이 같은 검사 실행 |
| 원격 저장소에 없는 라벨은 템플릿에서 무시됨 | 규약 문서에 forge별 라벨 생성 명령 기재 |

## References

- [Agent Skills specification](https://agentskills.io/specification)
- [Open Knowledge Format v0.2](https://github.com/GoogleCloudPlatform/knowledge-catalog/blob/main/okf/SPEC.md)
- [MADR 4.0](https://adr.github.io/madr/)
- [GitLab description templates](https://docs.gitlab.com/user/project/description_templates/)
- [Gitea issue and pull request templates](https://docs.gitea.com/usage/issue-pull-request-templates)

## Skill Output

- **Output type(s):** 대상 저장소에 기록되는 파일(Markdown, YAML, shell), 터미널 보고
- **Output format:** 파일마다 `ADD`/`PLAN`/`SKIP`/`NOTE`/`FAIL` 한 줄
- **Side effects:** 대상 저장소 안에만 기록. `core.hooksPath`를 저장소 설정에 기록하고, 실행 비트를 기록하려고 `.githooks/pre-commit` 하나만 스테이징. 네트워크 사용 없음

## Evaluation

- **Task set:** [`evals/evals.json`](evals/evals.json): positive와 negative 발동 케이스
- **Automated tests:** [`tests/smoke.sh`](tests/smoke.sh): 빈 저장소와 기존 저장소에 추가, 멱등성, github와 gitlab 형식, dry-run, `--init`, 심링크 거부, front matter 검사, 인덱스 재생성, CRLF 허용, pre-commit hook 동작. CI에서 Windows, macOS, ubuntu로 실행
- **Live agent benchmark:** 미실행. 성능 수치 인용 없음

## Skill Version

소스 커밋 SHA로 추적합니다(`git log -1 --format=%h -- skills/repo-scaffold`).
`v1-full` 태그에는 린터, 커밋 규약, 보안 스캔, GitHub 거버넌스까지 추가하는 판이 있습니다.
