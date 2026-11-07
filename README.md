# repo-scaffold

**에이전트가 문서를 근거로 일하게 만드는 저장소 스캐폴딩 Agent Skill.**

[![Agent Skills Spec](https://img.shields.io/badge/Agent%20Skills-Specification-blue)](https://agentskills.io)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

에이전트가 사전학습 기억이 아니라 저장소 안의 문서를 근거로 판단하게 만드는 것이 목적이다.
대상 저장소에 파일 열일곱 개를 깔고, 요구하는 도구는 `bash` 와 `git` 뿐이다.

이 저장소는 **`repo-scaffold` 스킬의 소스 저장소**다. 설치용 카탈로그는
[pubcyberry/skills](https://github.com/pubcyberry/skills) 이고, `skills/repo-scaffold/` 가
그쪽으로 자동 동기화된다.

## 깔리는 것

| 묶음 | 파일 |
| --- | --- |
| 진입점 | `AGENTS.md`. 문서 인덱스가 자동으로 들어간다 |
| 문서 | `docs/` 의 [OKF](https://github.com/GoogleCloudPlatform/knowledge-catalog/blob/main/okf/SPEC.md) 번들. 규약 다섯 개, 결정 기록 자리, 디렉터리마다 생성되는 `index.md` |
| 검사 | `scripts/doc-index.sh`, `.githooks/pre-commit`, CI 잡 하나 |
| 원격 저장소 | PR(MR) 템플릿과 이슈 템플릿 셋(버그, 기능 요청, 트러블슈팅) |

GitHub, Gitea, Forgejo 저장소는 `.github/` 를, GitLab 저장소는 `.gitlab/` 과 `.gitlab-ci.yml` 을 받는다.

## 규약

| 규약 | 문서 |
| --- | --- |
| `docs/` 는 OKF v0.2 번들이다. 문서마다 front matter 에 `type`, `title`, `description` 을 둔다 | `documentation.md` |
| 되돌리기 어려운 결정은 MADR 4.0 형식으로 `docs/decisions/` 에 남긴다 | `decisions.md` |
| 트러블슈팅은 원격 저장소의 이슈로 남긴다 | `troubleshooting.md` |
| 이슈와 PR(MR) 이 담아야 하는 것 | `issues-and-pull-requests.md` |
| 글의 언어(문서는 한국어, 스크립트 출력은 영어), 구성, 문장, 표기와 낡지 않게 쓰는 방법 | `writing-style.md` |

원본은 [skills/repo-scaffold/assets/docs/standards/](skills/repo-scaffold/assets/docs/standards/) 에 있다.

## 설치

```bash
npx skills add pubcyberry/skills --skill repo-scaffold --agent claude-code
```

이 저장소에서 직접 설치할 수도 있다.

```bash
npx skills add pubcyberry/repo-scaffold
```

## 사용

에이전트에게 "저장소 세팅해줘" 처럼 요청하면 [SKILL.md](skills/repo-scaffold/SKILL.md) 의 절차를 따른다.
직접 실행하려면 다음과 같다.

```bash
bash skills/repo-scaffold/assets/scaffold.sh --dry-run /path/to/repo   # 계획만 본다
bash skills/repo-scaffold/assets/scaffold.sh /path/to/repo             # 적용한다
```

## 저장소 구조

```text
.
├── skills/repo-scaffold/
│   ├── SKILL.md              # 진입점. frontmatter 와 절차
│   ├── skill-card.md         # 소유자, 라이선스, 위험과 완화
│   ├── evals/evals.json      # 발동 정확도 태스크셋 (positive, negative)
│   ├── assets/               # 대상 저장소에 복사되는 파일과 scaffold.sh
│   └── tests/smoke.sh        # 임시 저장소에 깔아서 동작을 확인한다
└── .github/
    ├── scripts/validate-skills.sh   # 카탈로그와 같은 스킬 계약 검사
    └── workflows/validate.yml       # 계약 검사와 스모크 테스트
```

## 검증

```bash
bash .github/scripts/validate-skills.sh     # 스킬 계약. yq 와 jq 가 필요하다
bash skills/repo-scaffold/tests/smoke.sh    # 스캐폴딩 동작
```

CI 는 계약 검사와 shellcheck 를 ubuntu 에서, 스모크 테스트를 ubuntu, macOS, windows 에서 돌린다.

## 기여

`skills/repo-scaffold/` 만 고친다. 템플릿 문서(`assets/docs/`)를 고쳤으면
`bash skills/repo-scaffold/assets/scripts/doc-index.sh` 로 템플릿의 인덱스를 다시 만든다.
보안 신고는 [SECURITY.md](SECURITY.md) 를 따른다.

린터, 커밋 규약, 보안 스캔, GitHub 거버넌스까지 깔던 이전 판은 `v1-full` 태그에 있다.

## 라이선스

MIT. [LICENSE](LICENSE) 참고.
