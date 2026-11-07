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
| 규약이 시간이 지나도 안 썩는다 | prek 훅과 CI 가 커밋마다 검증 |

이 저장소는 **`repo-scaffold` 스킬의 소스 저장소**다.
설치용 카탈로그는 [pubcyberry/skills](https://github.com/pubcyberry/skills) 이고,
여기 `skills/repo-scaffold/` 가 그쪽으로 자동 동기화된다.

동시에 이 저장소는 **자기가 배포하는 것을 자기에게 적용한 상태**다. 루트의 `AGENTS.md`,
`docs/`, `Justfile`, `tests/check-*.sh`, `scripts/` 는 전부 `assets/` 의 템플릿에서 나온 것이다.
배포물이 실제로 도는지는 여기서 먼저 드러난다.

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

```text
.
├── skills/repo-scaffold/      # 스킬 원본. 여기를 고친다
│   ├── SKILL.md               # 진입점. frontmatter 와 절차
│   ├── skill-card.md          # 소유자, 라이선스, 위험, 출력 거버넌스 카드
│   ├── evals/evals.json       # 발동 정확도 태스크셋 (positive/negative)
│   ├── assets/                # 대상 저장소에 복사되는 템플릿과 스크립트
│   ├── references/            # 활성화 후 온디맨드로 읽는 상세 문서
│   └── tests/smoke.sh         # 멱등성, 심링크 거부, 스캐폴딩 결과 자가 검증
│
├── Justfile                   # 공개 명령 인터페이스. just verify 가 DoD
├── AGENTS.md                  # 에이전트 진입점. 문서 인덱스가 자동 생성된다
├── docs/                      # 문서 5계층. 규약 문서 15종
├── tests/check-*.sh           # 검증 스크립트. 훅과 Justfile 이 직접 부른다
├── scripts/                   # bootstrap, doctor, tool-help, fmt, fix, 문서 검사기
│   └── agent-hooks/           # Claude Code 와 Codex 가 함께 무는 PreToolUse/PostToolUse/Stop 훅
├── styles/                    # Vale 규칙. Project, English, Korean
├── schemas/                   # front matter JSON Schema
└── .github/
    ├── scripts/validate-skills.sh   # 필수 산출물 + frontmatter 검증
    └── workflows/                   # validate 는 스킬 계약, 나머지는 배포물과 같은 것
```

`skills/` 를 저장소 루트에 두는 것은
[Agent Skills 권장 배치](https://github.com/NVIDIA/skills/blob/main/CONTRIBUTING.md#recommended-skill-directory-path)를 따른 것이다.
에이전트별 경로(`.claude/skills/`, `.codex/skills/`)에 원본을 두면 중복이 생긴다.

## 스킬 하나가 갖춰야 하는 산출물

| 파일 | 필수 | 역할 |
| --- | :---: | --- |
| `SKILL.md` | 예 | 에이전트가 읽는 진입점. frontmatter 의 `name`, `description` 이 발동을 결정한다 |
| `skill-card.md` | 예 | 소유자, 라이선스, 유스케이스, 알려진 위험과 완화, 출력 형식 |
| `evals/evals.json` | 예 | 발동 정확도 태스크셋. **negative 케이스가 최소 1개** 있어야 한다 |
| `references/` | | 길어지는 내용. `SKILL.md` 는 짧게 두고 여기로 민다 |
| `tests/` | | 스크립트를 배포하는 스킬이면 스모크 테스트 |

CI 가 위 필수 항목을 검사한다. 누락되면 카탈로그 동기화 단계에서 스킬이 드롭된다.

## 로컬 검증

명령은 하나다. 무엇이 도는지는 [Justfile](Justfile) 에 있다.

```bash
uv tool install rust-just    # just 하나만 손으로 깐다
just bootstrap               # 나머지 도구, 의존성, git 훅. 클론마다 한 번
just doctor                  # 환경 진단
just verify                  # Definition of Done
```

`just verify` 가 통과하지 않으면 작업이 끝난 것이 아니다.
`just` 를 인자 없이 치면 레시피 목록이 나온다.

스킬 계약과 스모크 테스트는 `just verify` 밖에 있다. 이 저장소만의 검사라서
배포되는 Justfile 에 넣지 않았다.

```bash
bash .github/scripts/validate-skills.sh     # frontmatter + 필수 산출물
bash skills/repo-scaffold/tests/smoke.sh    # 스캐폴딩 동작 + 결과물 자가 검증
```

의존: `bash`, `git`, `uv`. 스킬 계약 검사는 `yq` 와 `jq` 를 추가로 쓴다.
나머지 도구의 고정 버전은 [tools.txt](tools.txt) 에 있고 `just bootstrap` 이 설치한다.

Windows 는 Git Bash 가 필요하다. Git for Windows 기본 설치는 `Git\cmd` 만 PATH 에 넣고
`bash.exe` 를 넣지 않는다. `just doctor` 가 해석된 bash 를 출력한다.

`shfmt` 의 형식 기준은 `.editorconfig` 다. 명령줄에 형식 플래그를 주면 `.editorconfig` 가
무시되므로 훅에서도 CI 에서도 플래그 없이 부른다.

## 이 저장소가 배포물과 다른 점

자기 적용에는 한계가 있다. 갈라진 곳은 일곱이고 전부 결정 기록에 근거가 있다.
목록은 한 곳에만 둔다. [CONTRIBUTING.md 의 자기 적용 절](CONTRIBUTING.md#자기-적용) 이다.
같은 표를 두 곳에 두면 그 표부터 갈린다.

크게는 셋이다. `.pre-commit-config.yaml` 은 배포물 그대로에 `skill-contract` 훅 하나를
얹었고, 검사 설정 넷은 `assets/` 아래 템플릿을 검사 대상에서 빼며,
`SECURITY.md` 는 배포되는 자격 증명 규약이 아니라 취약점 신고 정책이다.

## 기여

[CONTRIBUTING.md](CONTRIBUTING.md) 를 본다. 보안 신고는 [SECURITY.md](SECURITY.md).

## 라이선스

MIT. [LICENSE](LICENSE) 참고.
