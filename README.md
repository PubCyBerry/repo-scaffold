# repo-scaffold

**저장소를 에이전트가 탐색하기 좋은 형태로 스캐폴딩하는 Agent Skill.**

[![Agent Skills Spec](https://img.shields.io/badge/Agent%20Skills-Specification-blue)](https://agentskills.io)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

에이전트가 사전학습 기억이 아니라 저장소 안 문서를 근거로 판단하게 만드는 것이 목적이다.
그러려면 문서가 있는 것만으로 부족하고 세 가지가 성립해야 한다.

| 조건 | 수단 |
| --- | --- |
| 무엇이 어디 있는지 한 번에 안다 | `AGENTS.md` 의 자동 생성 문서 인덱스 |
| 열어보기 전에 열지 말지 판단한다 | front matter 의 `title`, `summary`, `read_when` |
| 규약이 시간이 지나도 안 썩는다 | prek 훅이 커밋마다 검증 |

이 저장소는 **`repo-scaffold` 스킬의 소스 저장소**다.
설치용 카탈로그는 [pubcyberry/skills](https://github.com/pubcyberry/skills) 이고,
여기 `skills/repo-scaffold/` 가 그쪽으로 자동 동기화된다.

## 설치

카탈로그를 통해 설치한다.

```bash
npx skills add pubcyberry/skills --skill repo-scaffold --agent claude-code
```

이 저장소에서 직접 설치할 수도 있다.

```bash
npx skills add pubcyberry/repo-scaffold
```

## 저장소 구조

```
.
├── skills/
│   └── repo-scaffold/
│       ├── SKILL.md          # 진입점 — frontmatter + 절차
│       ├── skill-card.md     # 소유자·라이선스·위험·출력 거버넌스 카드
│       ├── evals/evals.json  # 발동 정확도 태스크셋 (positive/negative)
│       ├── assets/           # 대상 저장소에 복사되는 템플릿과 스크립트
│       ├── references/       # 활성화 후 온디맨드로 읽는 상세 문서
│       └── tests/smoke.sh    # 멱등성, 심링크 거부, 스캐폴딩 결과 자가 검증
├── .pre-commit-config.yaml   # prek 훅. shellcheck, shfmt, actionlint, zizmor
├── .editorconfig             # 편집기와 shfmt 의 형식 기준
└── .github/
    ├── scripts/validate-skills.sh   # 필수 산출물 + frontmatter 검증
    └── workflows/validate.yml       # PR 마다 lint, audit, 검증, 스모크 테스트
```

`skills/` 를 저장소 루트에 두는 것은
[Agent Skills 권장 배치](https://github.com/NVIDIA/skills/blob/main/CONTRIBUTING.md#recommended-skill-directory-path)를 따른 것이다.
에이전트별 경로(`.claude/skills/`, `.codex/skills/`)에 원본을 두면 중복이 생긴다.

## 스킬 하나가 갖춰야 하는 산출물

| 파일 | 필수 | 역할 |
| --- | :---: | --- |
| `SKILL.md` | ✅ | 에이전트가 읽는 진입점. frontmatter 의 `name`, `description` 이 발동을 결정한다 |
| `skill-card.md` | ✅ | 소유자, 라이선스, 유스케이스, 알려진 위험과 완화, 출력 형식 |
| `evals/evals.json` | ✅ | 발동 정확도 태스크셋. **negative 케이스가 최소 1개** 있어야 한다 |
| `references/` | | 길어지는 내용. `SKILL.md` 는 짧게 두고 여기로 민다 |
| `tests/` | | 스크립트를 배포하는 스킬이면 스모크 테스트 |

CI 가 위 필수 항목을 검사한다. 누락되면 카탈로그 동기화 단계에서 스킬이 드롭된다.

## 로컬 검증

```bash
bash .github/scripts/validate-skills.sh     # frontmatter + 필수 산출물
bash skills/repo-scaffold/tests/smoke.sh    # 스캐폴딩 동작 + 결과물 자가 검증
prek run --all-files                        # shellcheck, shfmt, actionlint, zizmor
```

의존: `bash`, `git`, `yq`, `jq`. 훅과 린트는 아래를 추가로 요구한다.

```bash
uv tool install prek
for t in shellcheck-py shfmt-py actionlint-py zizmor; do uv tool install "$t"; done
prek install
```

`shfmt` 의 형식 기준은 `.editorconfig` 다. 명령줄에 형식 플래그를 주면 `.editorconfig` 가 무시되므로
훅에서도 CI 에서도 플래그 없이 부른다.

## 기여

[CONTRIBUTING.md](CONTRIBUTING.md) 를 본다. 보안 신고는 [SECURITY.md](SECURITY.md).

## 라이선스

MIT. [LICENSE](LICENSE) 참고.
