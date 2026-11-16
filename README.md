# repo-scaffold

에이전트가 사전학습 기억 대신 저장소의 문서를 근거로 일하도록 저장소를 구성하는 Agent Skill입니다.

[![Agent Skills Spec](https://img.shields.io/badge/Agent%20Skills-Specification-blue)](https://agentskills.io)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

필요한 도구는 `bash`와 `git`입니다. 이 저장소는 스킬의 원본이고, `skills/repo-scaffold/`는 설치용 카탈로그인 [pubcyberry/skills](https://github.com/pubcyberry/skills)로 자동 동기화됩니다.

## 추가되는 파일

| 묶음 | 파일 |
| --- | --- |
| 진입점 | `AGENTS.md`(문서 인덱스 자동 생성) |
| 문서 | `docs/`의 [OKF](https://github.com/GoogleCloudPlatform/knowledge-catalog/blob/main/okf/SPEC.md) 번들. [규약 문서](skills/repo-scaffold/assets/docs/standards/index.md), 결정 기록 디렉터리, 디렉터리마다 생성되는 `index.md` |
| 검사 | `scripts/doc-index.sh`, `.githooks/pre-commit`, CI 잡 |
| git 설정 | `.gitignore`, `.gitattributes` |
| 원격 저장소 | PR(MR) 템플릿, 이슈 템플릿(버그, 기능 요청, 트러블슈팅) |

GitHub, Gitea, Forgejo 저장소에는 `.github/` 아래에, GitLab 저장소에는 `.gitlab/` 아래와 `.gitlab-ci.yml`에 템플릿과 CI 설정을 추가합니다.

## 설치

```bash
npx skills add pubcyberry/skills --skill repo-scaffold --agent claude-code
```

이 저장소에서 직접 설치할 수도 있습니다.

```bash
npx skills add pubcyberry/repo-scaffold
```

## 사용

에이전트에게 "저장소 세팅해줘"처럼 요청하면 에이전트가 [SKILL.md](skills/repo-scaffold/SKILL.md)의 절차를 따릅니다. 직접 실행하는 방법은 다음과 같습니다.

```bash
bash skills/repo-scaffold/assets/scaffold.sh --dry-run /path/to/repo   # 계획만 출력
bash skills/repo-scaffold/assets/scaffold.sh /path/to/repo             # 적용
```

## 저장소 구조

```text
.
├── skills/repo-scaffold/
│   ├── SKILL.md              # 진입점. frontmatter와 절차
│   ├── skill-card.md         # 소유자, 라이선스, 위험과 완화
│   ├── evals/evals.json      # 발동 정확도 태스크셋 (positive, negative)
│   ├── assets/               # 대상 저장소에 복사되는 파일과 scaffold.sh
│   └── tests/smoke.sh        # 임시 저장소에서 확인하는 동작 테스트
└── .github/
    ├── scripts/validate-skills.sh   # 카탈로그와 같은 스킬 계약 검사
    └── workflows/validate.yml       # 계약 검사와 스모크 테스트
```

## 검증

```bash
bash .github/scripts/validate-skills.sh     # 스킬 계약 검사. yq, jq 필요
bash skills/repo-scaffold/tests/smoke.sh    # 스캐폴딩 동작 검사
```

CI는 계약 검사와 shellcheck를 ubuntu에서 실행하고, 스모크 테스트를 Windows, macOS, ubuntu에서 실행합니다.

## 기여

수정 대상은 `skills/repo-scaffold/`입니다. 템플릿 문서(`assets/docs/`)를 고쳤으면 `bash skills/repo-scaffold/assets/scripts/doc-index.sh`로 템플릿의 인덱스를 다시 만듭니다.
커밋 메시지와 PR을 포함한 이 저장소의 글은 [글쓰기 규칙](skills/repo-scaffold/assets/docs/standards/writing-style.md)을 따릅니다.
보안 취약점은 [SECURITY.md](SECURITY.md)의 절차로 신고합니다.

`v1-full` 태그에는 린터, 커밋 규약, 보안 스캔, GitHub 거버넌스까지 추가하는 판이 있습니다.

## 라이선스

MIT. [LICENSE](LICENSE) 참고.
