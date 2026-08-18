# 기존 저장소에 얹기

이미 파일이 있는 저장소에 적용할 때만 읽는다. 빈 저장소면 [SKILL.md](../SKILL.md) 절차로 충분하다.

## 원칙

스크립트는 기존 파일을 건드리지 않는다. `SKIP` 으로 보고만 하고 넘어간다.
**병합은 사람이 판단할 일이다.** 에이전트가 임의로 기존 규약을 덮지 않는다.

## 진단

```bash
SKILL_DIR="$HOME/.claude/skills/repo-scaffold"
bash "$SKILL_DIR/assets/scaffold.sh" --target /path/to/repo --dry-run
```

`PLAN` 이 빠진 규약, `SKIP` 이 이미 있는 규약이다. 이 목록을 그대로 사용자에게 보고한다.
`NOTE` 는 손으로 합쳐야 하는 설정 파일이고 `OMIT` 은 이 저장소에 불필요하다고 판정한 것이다.
판정이 틀렸으면 `--with python` 처럼 강제한다.

적용한 뒤에는 환경부터 본다. FAIL 을 읽기 전에 무엇이 SKIP 인지 알아야 한다.

```bash
just doctor     # 무엇이 없고 무엇이 어긋났는지. 아무것도 바꾸지 않는다
just verify     # 전체 검사. 기존 저장소의 첫 실행은 대량으로 FAIL 이 난다
```

## SKIP 항목 처리

| 이미 있는 파일 | 확인할 것 |
| --- | --- |
| `AGENTS.md` | `<!-- DOC-INDEX:START -->` 와 `<!-- DOC-INDEX:END -->` 두 줄이 있는가. 없으면 인덱스 생성이 실패한다 |
| `.gitattributes` | `* text=auto eol=lf` 와 `*.sh text eol=lf` 가 있는가 |
| `.gitignore` | `.env` 가 있는가. 없으면 이미 커밋됐는지부터 확인한다 |
| `.pre-commit-config.yaml` | 기존 훅과 `repos: - repo: local` 블록을 합친다. 훅 id 가 겹치면 안 된다 |
| `.editorconfig` | `[*.{sh,bash}]` 절이 있는가. 없으면 `shfmt` 가 탭 들여쓰기를 기본값으로 잡아 기존 스크립트를 전부 지적한다 |
| `.env.example` | 실제 `.env` 와 키 집합이 같은가. `check-env.sh` 로 확인한다 |
| `docs/` | 디렉터리명이 `standards`, `guides`, `references`, `generated`, `architecture` 와 다르면 `check-docs.sh` 의 `expected_type` 이 빈 값을 돌려주고 type 검사를 건너뛴다 |
| `docs/standards/` | 같은 주제를 다루는 기존 규약이 있으면 새 문서를 넣지 않는다. 규칙이 두 벌이 되는 것이 없는 것보다 나쁘다 |
| `Justfile` | 기존 레시피와 이름이 겹치는지 본다. `verify` 가 이미 있으면 어느 쪽이 Definition of Done 인지 정한다 |
| `pyproject.toml` | `NOTE` 로 보고된다. `[tool.ruff]` 와 `[dependency-groups]` 를 손으로 옮긴다. TOML 은 자동 병합하지 않는다 |
| `package.json` | `NOTE` 로 보고된다. `devDependencies` 에 commitlint 두 개를 넣고 `npm install` 로 잠금 파일을 다시 만든다. 우리 `package-lock.json` 을 남의 `package.json` 위에 얹으면 `npm ci` 가 죽는다 |

### AGENTS.md 에 마커가 없을 때

가장 흔한 경우다. 문서 인덱스 절을 통째로 추가한다.

```markdown
## 문서 인덱스

pre-commit hook으로 커밋 직전에 자동 생성한다.

<!-- DOC-INDEX:START -->
<!-- DOC-INDEX:END -->
```

넣고 나서 인덱스를 생성한다.

```bash
git add -N -- AGENTS.md scripts/gen-doc-index.sh docs
bash scripts/gen-doc-index.sh
```

마커 사이에 손으로 쓴 내용을 넣으면 다음 커밋에 사라진다.

### .gitattributes 를 새로 넣었을 때

이미 CRLF 로 커밋된 파일이 있으면 속성만 바꿔서는 저장소 안 내용이 안 바뀐다. 한 번 재정규화한다.

```bash
git add --renormalize .
git status          # 줄바꿈만 바뀐 파일이 잔뜩 뜬다. 별도 커밋으로 분리한다
```

기능 변경과 같은 커밋에 넣지 않는다. diff 가 전부 줄바꿈으로 덮인다.

## 문서 검사 FAIL 대처

검사기마다 보는 것이 다르다. 메시지 앞머리로 어느 검사기가 낸 것인지 가른다.

`tests/check-docs.sh` 는 front matter 와 본문, 경로, 산문을 잇는 규칙을 본다.

| 메시지 | 조치 |
| --- | --- |
| `H1 ... 이 title ... 과 다름` | 본문 첫 H1 제목과 front matter `title` 을 같게 맞춘다 |
| `위치 기준 type 은 X 인데 Y` | 문서를 옮기거나 `type` 을 고친다. 디렉터리와 `type` 은 1:1이다 |
| `front matter 에 title 이 없다` | 필수 키가 빠졌다. 아래 스키마 검사가 같은 것을 다시 지적한다 |
| `저장소 안 경로는 링크로 쓴다` | 백틱을 마크다운 링크로 바꾼다. 링크 대상은 그 문서 기준 상대 경로 |

`tests/check-docs-metadata.sh` 는 front matter 의 값 계약과 문서 사이 관계를 본다.

| 메시지 | 조치 |
| --- | --- |
| `front matter 가 없다` | 문서 맨 앞에 `---` 블록을 넣는다. 필수 7개는 `id title type status summary scope read_when` |
| `'...' is a required property` | 빠진 키만 채운다. 값이 없으면 키를 넣지 않는 것이 아니라 값을 정한다 |
| `'...' is not one of [...]` (`type`) | `index standard guide reference generated decision` 여섯 개만 쓴다. `decision` 은 `docs/architecture/adr/` 전용이다 |
| `'...' is not one of [...]` (`status`) | 규약 표를 본다. `index` 는 `active` 만 쓴다 |
| `does not match '[^.]$'` | `summary` 를 명사나 명사구로 끝낸다. 마침표를 뺀다 |
| `id='...' 가 N개 문서에 있다` | 문서를 복사해 만들면 자주 난다. `<type>-<slug>` 로 새 id 를 준다 |
| `... 를 가진 문서가 없다` | `related` 와 `supersedes` 는 파일 경로가 아니라 `id` 로 적는다 |
| `sources[N]='...' 가 저장소에 없다` | 경로를 고치거나 그 항목을 지운다 |

rumdl 은 링크 대상과 앵커를 본다.

| 메시지 | 조치 |
| --- | --- |
| `[MD057] Relative link '...' does not exist` | 파일이 옮겨졌거나 오타다. 옛 규약의 루트 기준 링크도 여기서 걸린다. 아래 링크 규약 전환 절차를 따른다 |
| `[MD057] Absolute link '...'` | `/` 로 시작하는 링크를 문서 기준 상대 경로로 고친다 |
| `[MD051] ...` | 앵커가 가리키는 제목이 없다. 제목을 고쳤으면 링크도 같이 고친다 |

문서가 많아 한 번에 못 고치면 `status: draft` 로 두고 넘기지 않는다.
`status` 는 문서의 유효성이지 정리 상태가 아니다. 고칠 때까지 FAIL 을 남겨두는 편이 낫다.

## 링크 규약 전환

이 스킬의 예전 판은 in-repo 링크를 **저장소 루트 기준**으로 썼다. 지금은 **문서 기준 상대 경로**다.
예전 판으로 스캐폴딩한 저장소는 링크가 전부 걸린다.

바꾸는 이유는 rumdl 의 cross-file 앵커 검사다. rumdl 은 링크 대상을 링크가 있는 문서의 디렉터리
기준으로만 해석하고, 설정으로 바꿀 수 없으며, 못 찾으면 **조용히 건너뛴다**. 루트 기준을 유지하면
루트 문서 밖에서는 앵커 검사가 영원히 0% 다. 대가는 문서를 옮길 때 링크를 같이 고쳐야 하는 것이다.

전환은 기계적이다. 판정 기준이 "링크 대상이 저장소 루트에서 실제로 존재하는가" 하나뿐이라
외부 URL, 앵커 전용 링크, 절대 경로는 건드리지 않는다.

```bash
uv run --no-project --python 3.13 - <<'PY'
import os, pathlib, re, subprocess

root = pathlib.Path(subprocess.check_output(
    ["git", "rev-parse", "--show-toplevel"], text=True).strip())
link_re = re.compile(r"\]\(([^)\s]+?)(#[^)]*)?\)")
skip_re = re.compile(r"^(https?:|mailto:|#|/|\.\.?/)")

for name in subprocess.check_output(
        ["git", "ls-files", "--", "*.md"], text=True).splitlines():
    path = root / name
    src = path.read_text(encoding="utf-8")

    def sub(m):
        target, frag = m.group(1), m.group(2) or ""
        if skip_re.match(target) or not (root / target).exists():
            return m.group(0)
        rel = os.path.relpath(root / target, path.parent).replace(os.sep, "/")
        return f"]({rel}{frag})"

    out = link_re.sub(sub, src)
    if out != src:
        path.write_text(out, encoding="utf-8", newline="\n")
        print(name)
PY
```

돌린 뒤 확인한다. 링크 변환만 따로 커밋한다. 다른 변경과 섞으면 diff 를 읽을 수 없다.

```bash
rumdl check .
```

남는 것은 셋뿐이다.

| 남는 경우 | 조치 |
| --- | --- |
| 대상이 저장소에 없어 그대로 남은 링크 | 원래 깨진 링크다. 실제 경로를 찾아 고친다 |
| 코드 블록 안 예시 링크 | 스크립트가 건드리지 않는다. 규약을 보여주는 예시면 손으로 고친다 |
| 같은 템플릿이 여러 깊이에 깔리는 문서 | 하드코딩한 상대 경로가 한쪽에서만 맞는다. 치환 키로 뺀다 |

## 문서 메타데이터를 늘릴 때

필수 7개는 예전 판과 같다. 선택 키 둘이 새로 생겼고 **둘 다 없어도 통과한다.**
없으면 그 검사가 SKIP 이라는 뜻이지 실패가 아니다. 한 번에 다 채우려 하지 않는다.

| 키 | 무엇을 켜나 | 없으면 |
| --- | --- | --- |
| `sources` | source drift. 그 경로가 `last_reviewed` 이후에 바뀌면 push 가 막힌다 | SKIP. 문서가 낡아도 아무도 모른다 |
| `review_interval_days` | 검토 주기. 없으면 `type` 별 기본값을 쓴다 | 기본값으로 동작한다 |

`sources` 는 문서가 **서술하는** 저장소 경로이고 `scope` 는 문서가 **적용되는** 범위다.
둘은 다르다. `documentation.md` 의 `scope` 는 `docs/**` 이지만 `sources` 는
`tests/check-docs.sh` 다.

`last_reviewed` 는 사람이 문서를 다시 읽었을 때만 손으로 올린다. 도구가 올리지 않는다.
자동으로 올리면 아무도 안 읽은 문서가 영원히 최신으로 보고된다.

먼저 검사가 실제로 도는지부터 확인한다. `sources` 에 적은 경로가 아직 커밋되지 않았으면
git 이력이 없어 SKIP 이다. 초록 불이 곧 미검사인 상태를 만들지 않는다.

```bash
bash tests/check-docs-metadata.sh --only drift
bash tests/check-docs-metadata.sh --only time     # WARN 만 낸다. 종료 코드를 바꾸지 않는다
```

### `docs/architecture/` 를 새로 넣을 때

`type` enum 이 다섯에서 여섯으로 늘었다. `decision` 이 추가됐고
`docs/architecture/adr/` 아래에서만 쓴다. `docs/architecture/` 바로 아래는 `reference` 다.

`decision` 의 `status` enum 도 다르다. `proposed accepted rejected superseded` 넷이고
`active` 는 쓰지 않는다. 결정 기록은 한 번 쓰고 고치지 않는다. 결정이 바뀌면 새 기록을 쓰고
옛 기록의 `status` 를 `superseded` 로 바꾼 뒤 새 기록에 `supersedes` 를 적는다.

기존 저장소에 `docs/adr/` 나 `docs/decisions/` 가 이미 있으면 옮길지 말지부터 정한다.
옮기면 링크가 전부 깨지고, 그것은 rumdl 의 MD057 이 잡아준다.
안 옮기면 `expected_type` 이 빈 값을 돌려주고 type 검사가 조용히 꺼진다. 옮기는 편이 낫다.

### `docs_graph.py` 의 id 앞머리 WARN

`id` 는 `<type>-<slug>` 규약이다. 기존 저장소는 이 규약을 몰랐으므로 **첫 실행에서 대량으로
WARN 이 뜬다.** WARN 은 종료 코드를 바꾸지 않으므로 막지 않는다. 한꺼번에 고치려 하지 말고
문서를 손댈 때마다 하나씩 고친다. `id` 를 바꾸면 그 id 를 가리키는 `related` 와 `supersedes`
를 같이 고쳐야 하고, 그 짝은 같은 검사가 잡아준다.

## 파이썬 계층을 얹을 때

`pyproject.toml` 이 이미 있으면 `NOTE` 다. 스캐폴딩은 TOML 을 병합하지 않는다.
`[tool.ruff]` 와 `[tool.mypy]` 블록을 원본에서 손으로 옮긴다.

한도는 발명한 것이 아니라 `docs/standards/code-quality.md` 의 hard limit 을 기계로 옮긴
것이다. 한도를 바꾸려면 그 문서를 먼저 고친다. 반대 방향은 없다.

`mypy` 는 신규 저장소 기준으로 `strict = true` 다. 기존 저장소에 그대로 켜면 첫 실행에서
수백 개가 뜨고, 그 상태는 타입을 고치게 만들지 않고 검사를 끄게 만든다. 세 단계로 나눈다.

1. **통과 baseline 을 만든다.** `strict` 를 끄고 돌려 통과하는 지점을 찾는다.
   모듈별 `[[tool.mypy.overrides]]` 로 아직 못 고친 모듈만 완화한다
2. **신규 회귀를 차단한다.** 이 상태로 pre-push 훅과 CI 를 켠다. 새로 쓰는 코드는 이미 엄격하다
3. **override 를 하나씩 지운다.** 모듈 하나를 고칠 때마다 그 override 를 지운다.
   전부 지워지면 `strict = true` 다

`ruff` 는 반대로 처음부터 전부 켠다. `just fix` 가 자동으로 고칠 수 있는 지적이 대부분이고,
남는 것은 실제 결함이다. 형식은 `just fmt` 가 한 번에 맞추고 **형식 변경만 따로 커밋한다.**

## 커밋 규약을 얹을 때

`commitlint` 는 **앞으로의 커밋만** 본다. 이미 머지된 이력은 재검사하지 않으므로
과거 커밋이 규약을 어겼어도 문제되지 않는다. 이력을 다시 쓰지 않는다.

바뀌는 것은 앞으로다. `subject-case` 규칙 때문에 **커밋 제목은 소문자로 시작해야 한다.**
`feat(api): Add retry` 는 탈락이고 `feat(api): add retry` 는 통과한다. 한국어 제목은 통과한다.

| 형태 | 판정 | 근거 |
| --- | --- | --- |
| `fixup!`, `squash!` 접두 | 통과 | `git rebase --autosquash` 를 깨지 않는다 |
| `Merge branch ...` | 통과 | git 이 만드는 문자열이라 사람이 못 고친다 |
| `revert:` | 통과 | `git revert` 가 만드는 형식이다 |
| 대문자로 시작하는 제목 | **탈락** | `subject-case` |
| 100자를 넘는 제목 | **탈락** | `header-max-length` |

PR 제목도 같은 제약을 받는다. squash 머지가 PR 제목으로 커밋을 합성하면 commitlint 는
그 문자열을 영원히 못 보므로, `pr-policy` 워크플로가 PR 제목을 따로 검사한다.

`node_modules` 를 못 까는 환경이면 형식 검사는 로컬 SKIP 이고 CI FAIL 이다.
제목의 금지 문자 검사는 도구를 쓰지 않으므로 그 환경에서도 계속 돈다.

## 거버넌스를 얹을 때

**라벨을 가장 먼저 만든다.** 순서를 바꾸면 조용히 망가진다.

```bash
bash scripts/apply-github-labels.sh            # dry-run. 무엇이 바뀌는지만 본다
bash scripts/apply-github-labels.sh --apply    # 실제로 만든다
```

라벨이 없을 때의 실패 양상이 소비자마다 다르고, 둘은 아무 소리도 내지 않는다.

| 소비자 | 라벨이 없으면 | 알아채나 |
| --- | --- | --- |
| Issue Form | GitHub 이 **라벨을 조용히 버린다.** 수명주기가 시작되지 않는다 | 아니오 |
| `actions/stale` | 아무것도 안 맞아 매일 초록으로 아무 일도 안 한다 | 아니오 |
| `pr-policy` | `policy/skip-issue` 를 붙일 수 없어 **사소한 PR 이 전부 막힌다** | 예 |

그다음이 룰셋이다. 두 벌 중 하나를 고른다.

| 예제 | 쓸 곳 |
| --- | --- |
| `default-branch.example.json` | 기본값. 1인 저장소를 가정한다. 승인 0건이고 관리자 우회를 남긴다 |
| `default-branch.team.example.json` | 리뷰어가 둘 이상. 승인 1건 + 코드 소유자 승인 |

1인 저장소에 team 예제를 걸면 **본인 PR 을 영원히 머지하지 못한다.** 승인 1건과 코드 소유자
승인을 자기 자신이 줄 수 없기 때문이다. 복구는 룰셋을 다시 지우는 것뿐이다.

required check 이름은 워크플로의 **잡 이름**이지 파일명이 아니다. 기본값은
`quality` `tests` `docs` `security` `pr-policy` 다. 대상 저장소의 잡 이름이 다르면
룰셋 JSON 을 그 이름으로 고친다. 안 고치면 모든 PR 이 오지 않는 검사를 영원히 기다린다.

`pr-policy` 를 도입 직후 required check 로 올리지 않는다. 열려 있는 PR 이 전부 막힌다.
한 사이클 돌려 보고 올린다.

## check-markdown.sh FAIL 대처

| 메시지 | 조치 |
| --- | --- |
| `MD013` (줄 길이) | 기준은 `.editorconfig` 와 같은 100 이다. 표와 코드 블록은 예외다. 산문은 손으로 접는다 |
| `MD025` (최상위 제목 둘) | `.rumdl.toml` 의 `front-matter-title = ""` 가 빠졌다. front matter 의 `title` 을 H1 으로 세는 기본값 탓이다 |
| `MD051` (앵커 없음) | 대상 문서의 제목이 바뀌었다. 앵커는 GitHub 규칙으로 만든다 |
| `MD057` (링크 대상 없음) | 위 링크 규약 전환을 먼저 돌린다 |
| `MD031`, `MD040` 등 형식 | `just fmt` 가 대부분 자동으로 고친다 |

`rumdl fmt` 는 파일을 바꾸므로 훅에서 부르지 않는다. 훅은 `rumdl check` 만 부른다.

## check-prose.sh FAIL 대처

Vale 은 산문 정책 검사기이자 용어 검사기다. 문법 검사기도, 맞춤법 검사기도 아니다.

| 증상 | 조치 |
| --- | --- |
| `Korean.SentenceEndings` 가 잔뜩 뜬다 | 저장소 문체가 경어체다. 평서형으로 바꾸거나 `styles/Korean/SentenceEndings.yml` 의 `raw` 를 뒤집는다 |
| 용어 규칙이 팀 용어와 다르다 | `styles/Korean/Terminology.yml` 의 `swap` 을 팀 용어로 갈아끼운다. 이 파일은 출발점이지 정답이 아니다 |
| 오탐이 난다 | 그 규칙의 `level` 을 `warning` 으로 내린다. warning 은 종료 코드에 반영되지 않아 커밋을 막지 않는다 |
| 초록인데 아무것도 안 잡히는 것 같다 | 한국어 규칙에 `nonword: true` 나 `raw:` 가 있는지 본다. 없으면 ASCII 낱말 경계 탓에 조용히 아무것도 검사하지 않는다 |
| `미설치` 인데 SKIP | Vale 은 첫 실행에 네트워크로 실행 파일을 받는다. 받기 전에는 로컬 SKIP 이고 CI 에서 FAIL 이다 |

## check-shell.sh FAIL 대처

기존 스크립트가 있는 저장소면 첫 실행에서 거의 전부 걸린다. 정상이다.

| 메시지 | 조치 |
| --- | --- |
| `형식 불일치` | `shfmt -w` 로 한 번에 고치고 **형식 변경만 따로 커밋한다.** 기능 변경과 섞으면 diff 가 전부 공백으로 덮인다 |
| `지적 있음` (shellcheck) | 지적을 고친다. 진짜 예외면 그 줄 위에 `# shellcheck disable=SCxxxx  # 사유` 를 붙인다. 사유 없는 disable 은 다시 리뷰 대상이다 |
| `미설치` 인데 SKIP | 로컬에서는 막지 않는다. CI 에서 FAIL 이므로 머지 전에는 반드시 설치해서 돌린다 |

`shfmt` 결과가 예상과 다르면 `.editorconfig` 부터 본다. `[*.{sh,bash}]` 절이 없으면 탭이 기본값이다.
명령줄에 형식 플래그를 주면 `.editorconfig` 가 무시되므로 어디서도 주지 않는다.

## check-workflows.sh FAIL 대처

| 메시지 | 조치 |
| --- | --- |
| `unpinned-uses` (zizmor) | `uses:` 를 40자 커밋 SHA 로 고정하고 뒤에 버전 주석을 단다. SHA 는 그 자리에서 조회한다 |
| `artipacked` (zizmor) | checkout step 에 `persist-credentials: false` 를 넣는다. 그 토큰으로 push 하는 step 이 뒤에 있을 때만 예외다 |
| `excessive-permissions` (zizmor) | 워크플로 맨 위에 `permissions:` 를 선언하고 `contents: read` 에서 시작한다 |
| `template-injection` (zizmor) | `run:` 안에 `${{ }}` 를 직접 넣지 않는다. `env:` 로 넘기고 변수로 참조한다 |
| actionlint 지적 | 표현식과 step 안 셸 문제다. `shellcheck` 가 설치돼 있으면 actionlint 가 그것까지 본다 |

## 훅 설치 충돌

| 증상 | 원인과 조치 |
| --- | --- |
| 설치가 `core.hooksPath` 때문에 거부된다 | 전역 `core.hooksPath` 가 걸려 있다. `GIT_CONFIG_GLOBAL=/dev/null prek install` 로 설치한다. 전역 설정은 바뀌지 않는다 |
| 기존 `.git/hooks/pre-commit` 이 있다 | `.legacy` 로 백업되고 이어서 호출된다. 백업 파일이 생겼는지 확인한다 |
| 훅이 아예 안 돈다 | 클론마다 설치가 필요하다. `just bootstrap` 을 했는지 확인한다 |
| commit-msg 와 pre-push 훅만 안 돈다 | `prek install` 을 손으로 불렀고 `default_install_hook_types` 가 없거나 무시됐다. `just bootstrap` 이 세 종류를 명시적으로 건다. `just doctor` 가 디스크의 훅 파일을 보고한다 |
| 훅이 매번 통째로 실패한다 | `prek run --all-files` 로 원인을 먼저 본다. 커밋을 막은 채로 방치하면 `--no-verify` 가 습관이 된다 |
| 이미 pre-commit 을 쓰고 있다 | 설정 파일이 같아 실행기만 바꾸면 된다. `pre-commit uninstall` 후 `prek install` 한다. 둘 다 설치하면 훅이 두 번 돈다 |

## 자격 증명이 이미 커밋돼 있을 때

`check-secrets.sh --all` 이 추적 파일 전체를 훑는다. 걸리면 순서가 정해져 있다.

1. **해당 토큰을 즉시 폐기하고 재발급한다.** 이력 정리보다 먼저다
2. 값을 `.env` 로 옮기고 `.env.example` 에 빈 키를 넣는다
3. 노출 범위를 보고한다. 저장소, 브랜치, 시점을 적는다
4. 이력에서 지울지는 그다음 판단이다. 이미 push 된 이력을 강제로 다시 쓰지 않는다

오탐이면 그 줄 끝에 `secret-scan: allow` 주석을 붙인다. 패턴 자체를 지우지 않는다.
