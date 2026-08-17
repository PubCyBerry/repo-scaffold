# shebang 을 두지 않는다. 이 파일은 uv run --script 로만 불리고 실행 권한을 받지 않는다.
# 권한 없는 파일에 shebang 이 있으면 ruff 가 EXE001 로 잡는다. 파일 권한이 없는
# Windows 에서는 그 규칙이 조용히 넘어가서 리눅스 CI 에서만 드러난다.
# /// script
# requires-python = ">=3.11"
# dependencies = []
# ///
"""PR 메타데이터 계약 검사. 제목, 본문의 9개 절, 이슈 연결을 본다.

단계는 셋이고 --only 로 고른다.

  title     제목이 Conventional Commits 헤더인가. 제목에 금지 문자가 있는가
  sections  필수 9개 절이 있고, 템플릿 주석을 걷어낸 뒤에도 내용이 남는가
  issue     닫는 키워드로 이슈를 걸었는가. 아니면 policy/skip-issue 라벨이 있는가

title 단계가 이 검사기의 존재 이유다. 이 저장소는 squash 로 머지하고 squash 커밋
제목의 기본값이 PR 제목이다. 즉 기본 브랜치에 남는 커밋 메시지는 PR 제목에서 합성되고,
commit-msg 훅은 브랜치 커밋만 보므로 그 문자열을 영원히 보지 못한다. 여기서 걸지 않으면
"Conventional Commits 를 강제한다" 가 정작 살아남는 커밋에 대해서만 거짓이 된다.

subject-case 는 commitlint 규칙을 그대로 옮기지 않고 "제목이 대문자 ASCII 로 시작하면
실패" 로 근사한다. commitlint 의 판정이 lodash 의 대소문자 변환에 의존해서 한국어처럼
대소문자가 없는 문자와 섞이면 재현하기 어렵다. 브랜치 커밋의 권위는 commitlint 에 있고,
여기서는 사람이 쓴 한 줄을 같은 방향으로 막는다.

fixup!, squash!, Merge, Revert 예외는 여기에 없다. 그것들은 git 이 만들거나 원문을
그대로 옮긴 커밋 제목이고, PR 제목은 언제나 사람이 손으로 쓴다.

입력은 환경변수다. 워크플로가 그렇게 넘기기 때문이고, 본문을 명령줄 인자로 넘기면
셸 주입 표면이 하나 생긴다. 테스트와 손으로 돌릴 때를 위해 인자로도 덮어쓸 수 있다.

  PR_TITLE   제목 한 줄
  PR_BODY    본문 전체
  PR_LABELS  라벨 이름의 JSON 배열. GitHub 의 toJson(...labels.*.name) 형식

이 파일은 줄 길이 88 과 100 에서 ruff format 결과가 같아야 한다. 파이썬을 쓰지 않는
저장소에는 pyproject.toml 이 없어서 ruff 가 기본값 88 로 돌고, 있으면 이 저장소 표준인
100 으로 돈다. 여러 줄로 나뉜 호출에는 마지막 인자 뒤에 쉼표를 남겨 그 형태를 고정한다.

사용법:
  uv run --script scripts/check_pr_metadata.py
  uv run --script scripts/check_pr_metadata.py --only title
  uv run --script scripts/check_pr_metadata.py --title 'fix: drop stray lock' --only title

종료 코드: FAIL 이 하나라도 있으면 1, 알 수 없는 옵션이면 2, 아니면 0
"""

import argparse
import io
import json
import os
import re
import sys
from pathlib import Path


def use_utf8() -> None:
    """표준 출력을 UTF-8 로 고정한다."""
    # Windows 의 기본 인코딩은 UTF-8 이 아니다. 파이프로 넘기면 한글 메시지가 깨지거나
    # UnicodeEncodeError 로 죽는다. 훅과 CI 는 언제나 파이프로 받는다.
    for stream in (sys.stdout, sys.stderr):
        if isinstance(stream, io.TextIOWrapper):
            stream.reconfigure(encoding="utf-8")


use_utf8()

ALL_PHASES = ("title", "sections", "issue")

# docs/standards/pull-request-lifecycle.md 의 표와 .github/pull_request_template.md 의
# 제목이 이 아홉과 글자 단위로 같아야 한다. 하나라도 어긋나면 템플릿대로 쓴 PR 이 막힌다.
REQUIRED_SECTIONS = (
    "Summary",
    "Motivation",
    "Linked issue",
    "Changes",
    "Scope / Non-goals",
    "Validation",
    "Risk / Compatibility",
    "Documentation",
    "Reviewer focus",
)

# commitlint 의 config-conventional 기본 type-enum 과 같다.
# 사람이 읽는 원본은 docs/standards/commit-convention.md 다.
TYPES = (
    "build",
    "chore",
    "ci",
    "docs",
    "feat",
    "fix",
    "perf",
    "refactor",
    "revert",
    "style",
    "test",
)

HEADER_MAX = 100

# commitlint 의 기본 header-pattern 과 같은 모양이다.
HEADER_RE = re.compile(r"^(\w*)(?:\(([\w$.\-*/ ]*)\))?(!)?: (.*)$")

# tests/check-commit-msg.sh 의 NOTATION 과 같은 목록이다. 원본은
# docs/standards/writing-style.md 의 Notation 표이고 Vale 은 마크다운만 보므로
# 커밋 제목과 PR 제목에는 각각의 검사기가 같은 규칙을 건다.
# hyphen 두 개는 앞뒤에 공백이 있을 때만 잡는다. --no-cache 같은 옵션 접두사는 예외다.
NOTATION = (
    ("interpunct", "·"),
    ("em dash", "—"),
    ("en dash", "–"),
    ("double hyphen", " -- "),
    ("ditto mark", "〃"),
)

SKIP_ISSUE_LABEL = "policy/skip-issue"

# GitHub 이 인식하는 닫는 키워드와 그 뒤의 이슈 참조. 짧은 형식과 URL 을 모두 받는다.
CLOSING_RE = re.compile(
    r"\b(?:close[sd]?|fix(?:e[sd])?|resolve[sd]?)\s+"
    r"(?:[\w.-]+/[\w.-]+)?#\d+\b"
    r"|\b(?:close[sd]?|fix(?:e[sd])?|resolve[sd]?)\s+"
    r"https?://\S*?/issues/\d+\b",
    re.IGNORECASE,
)

HEADING_RE = re.compile(r"^##[ \t]+(.+?)[ \t]*$")
COMMENT_RE = re.compile(r"<!--.*?-->", re.DOTALL)
FENCE_RE = re.compile(r"^[ \t]*(?:```|~~~)")


class Report:
    """판정을 세어 두었다가 마지막에 합계를 낸다."""

    def __init__(self) -> None:
        """카운터를 0 에서 시작한다."""
        self.passed = 0
        self.failed = 0
        self.skipped = 0

    def emit(self, verdict: str, target: str, reason: str = "") -> None:
        """판정 한 줄을 찍고 센다."""
        if verdict == "PASS":
            self.passed += 1
        elif verdict == "FAIL":
            self.failed += 1
        else:
            self.skipped += 1
        print(f"{verdict:<4} {target:<22} {reason}")


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    """명령줄 인자를 읽는다. 값이 없으면 환경변수를 쓴다."""
    parser = argparse.ArgumentParser(
        prog="check_pr_metadata.py",
        description="PR 제목, 본문 절, 이슈 연결을 검사한다",
    )
    parser.add_argument(
        "--only",
        default=",".join(ALL_PHASES),
        help=f"검사 단계를 쉼표로 고른다. 기본은 전부다: {' '.join(ALL_PHASES)}",
    )
    parser.add_argument("--title", default=None, help="PR 제목. 없으면 PR_TITLE")
    parser.add_argument("--body-file", default=None, help="본문 파일. 없으면 PR_BODY")
    parser.add_argument(
        "--label",
        action="append",
        default=None,
        help="라벨 이름. 여러 번 줄 수 있다. 없으면 PR_LABELS",
    )
    return parser.parse_args(argv)


def select_phases(raw: str) -> tuple[str, ...]:
    """쉼표로 이어진 단계 목록을 정규 순서로 되돌린다. 모르는 이름이면 죽는다."""
    wanted = [name for name in raw.split(",") if name]
    for name in wanted:
        if name not in ALL_PHASES:
            print(f"FAIL: 그런 검사 단계가 없다: {name}", file=sys.stderr)
            print(f"      쓸 수 있는 단계: {' '.join(ALL_PHASES)}", file=sys.stderr)
            raise SystemExit(2)
    return tuple(name for name in ALL_PHASES if name in wanted)


def load_labels(args: argparse.Namespace) -> set[str]:
    """라벨 집합을 만든다. 인자가 없으면 PR_LABELS 를 JSON 으로 읽는다."""
    if args.label is not None:
        return set(args.label)
    raw = os.environ.get("PR_LABELS", "") or "[]"
    try:
        parsed = json.loads(raw)
    except json.JSONDecodeError:
        # 라벨을 못 읽으면 조용히 빈 집합으로 넘어가지 않는다. 그러면
        # policy/skip-issue 가 붙은 PR 이 이유 없이 막힌다.
        print(f"WARN PR_LABELS 를 JSON 으로 읽지 못했다: {raw!r}", file=sys.stderr)
        return set()
    if isinstance(parsed, list):
        return {str(item) for item in parsed}
    return set()


def load_body(args: argparse.Namespace) -> str:
    """본문을 읽는다. 파일 인자가 없으면 PR_BODY 를 쓴다."""
    if args.body_file is not None:
        return Path(args.body_file).read_text(encoding="utf-8")
    return os.environ.get("PR_BODY", "") or ""


def load_title(args: argparse.Namespace) -> str:
    """제목을 읽는다. 인자가 없으면 PR_TITLE 을 쓴다."""
    if args.title is not None:
        return str(args.title)
    return os.environ.get("PR_TITLE", "") or ""


def split_sections(body: str) -> list[tuple[str, str]]:
    """본문을 `## 제목` 단위로 자른다. 코드 펜스 안의 `##` 는 제목이 아니다."""
    sections: list[tuple[str, list[str]]] = []
    fenced = False
    for line in body.splitlines():
        if FENCE_RE.match(line):
            fenced = not fenced
        elif not fenced:
            matched = HEADING_RE.match(line)
            if matched:
                sections.append((matched.group(1), []))
                continue
        if sections:
            sections[-1][1].append(line)
    return [(heading, "\n".join(lines)) for heading, lines in sections]


def subject_problems(subject: str) -> list[str]:
    """제목 본문의 문제를 모은다."""
    if not subject:
        return ["제목 본문이 비었다"]
    problems: list[str] = []
    if subject.endswith("."):
        problems.append("마침표로 끝내지 않는다")
    if subject[0].isascii() and subject[0].isupper():
        problems.append("소문자로 시작한다. commitlint 의 subject-case 다")
    return problems


def check_title_format(report: Report, title: str) -> None:
    """제목이 Conventional Commits 헤더인지 본다."""
    if len(title) > HEADER_MAX:
        report.emit("FAIL", "title length", f"{len(title)}자다. {HEADER_MAX}자 이하다")
    matched = HEADER_RE.match(title)
    if not matched:
        report.emit("FAIL", "title format", "'<type>(<scope>): <subject>' 가 아니다")
        return
    commit_type, _scope, _bang, subject = matched.groups()
    if commit_type != commit_type.lower():
        report.emit("FAIL", "title type", f"'{commit_type}' 는 소문자로 쓴다")
    elif commit_type not in TYPES:
        report.emit("FAIL", "title type", f"'{commit_type}' 는 type 목록 밖이다")
    problems = subject_problems(subject)
    for problem in problems:
        report.emit("FAIL", "title subject", problem)
    if not problems:
        report.emit("PASS", "title subject", subject)


def check_title_notation(report: Report, title: str) -> None:
    """제목에 금지 문자가 있는지 본다."""
    hit = False
    for name, char in NOTATION:
        if char in title:
            hit = True
            report.emit("FAIL", name, "제목에 있다. 표기는 writing-style.md 다")
    if not hit:
        report.emit("PASS", "title notation", "금지 문자 없음")


def check_title(report: Report, title: str) -> None:
    """제목 단계 전체."""
    if not title.strip():
        report.emit("FAIL", "title", "제목이 비었다. PR_TITLE 이 넘어오지 않았다")
        return
    check_title_format(report, title)
    check_title_notation(report, title)


def check_sections(report: Report, body: str) -> None:
    """필수 절이 있고 내용이 남는지 본다."""
    if not body.strip():
        report.emit("FAIL", "body", "본문이 비었다. 템플릿대로 채운다")
        return
    found = dict(split_sections(body))
    for name in REQUIRED_SECTIONS:
        if name not in found:
            report.emit("FAIL", name, "필수 절이 없다")
            continue
        # 템플릿의 HTML 주석은 내용이 아니다. 걷어낸 뒤에도 남는 것이 있어야 한다.
        content = COMMENT_RE.sub("", found[name]).strip()
        if not content:
            report.emit("FAIL", name, "필수 절이 비었다. 해당 없으면 N/A 라고 쓴다")
        else:
            report.emit("PASS", name, content.splitlines()[0][:40])


def check_issue(report: Report, body: str, labels: set[str]) -> None:
    """이슈를 걸었는지, 아니면 면제 라벨이 붙었는지 본다."""
    if SKIP_ISSUE_LABEL in labels:
        report.emit("PASS", "linked issue", f"{SKIP_ISSUE_LABEL} 라벨로 면제됨")
        return
    if CLOSING_RE.search(COMMENT_RE.sub("", body)):
        report.emit("PASS", "linked issue", "닫는 키워드로 이슈를 걸었다")
        return
    report.emit(
        "FAIL",
        "linked issue",
        f"'Closes #123' 처럼 이슈를 걸거나 {SKIP_ISSUE_LABEL} 라벨을 받는다",
    )


def main(argv: list[str] | None = None) -> int:
    """단계를 골라 돌리고 합계를 낸다."""
    args = parse_args(argv)
    phases = select_phases(args.only)
    title = load_title(args)
    body = load_body(args)
    labels = load_labels(args)

    report = Report()
    for index, phase in enumerate(phases, start=1):
        print(f"\n[{index}/{len(phases)}] {phase}")
        if phase == "title":
            check_title(report, title)
        elif phase == "sections":
            check_sections(report, body)
        else:
            check_issue(report, body, labels)

    print(f"\n결과: PASS {report.passed}, FAIL {report.failed}, SKIP {report.skipped}")
    if report.failed:
        print("\n규약: docs/standards/pull-request-lifecycle.md", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
