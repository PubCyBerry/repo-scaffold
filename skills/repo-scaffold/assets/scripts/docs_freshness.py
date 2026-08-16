# shebang 을 두지 않는다. 이 파일은 uv run --script 로만 불리고 실행 권한을 받지 않는다.
# 권한 없는 파일에 shebang 이 있으면 ruff 가 EXE001 로 잡는다. 파일 권한이 없는
# Windows 에서는 그 규칙이 조용히 넘어가서 리눅스 CI 에서만 드러난다.
# /// script
# requires-python = ">=3.11"
# dependencies = []
# ///
"""문서 수명주기 검사. 시간과 source drift 두 신호를 따로 낸다.

신호 둘은 서로 독립이고 심각도가 다르다.

  time   오늘 - last_reviewed 가 review_interval_days 를 넘었는가.
         시간이 흐른 것뿐이라 WARN 이고 종료 코드에 반영되지 않는다.
  drift  sources 에 적힌 경로가 last_reviewed 이후에 git 이력에서 바뀌었는가.
         사람이 쓴 내용과 코드가 갈라졌다는 뜻이라 FAIL 이다.

drift 는 파일 시스템의 mtime 이 아니라 git 이력을 본다. clone, checkout, 포맷터가
mtime 을 바꾸므로 mtime 은 "내용이 바뀌었는가" 를 답하지 못한다.

last_reviewed 를 자동으로 올리지 않는다. 사람이 문서를 다시 읽은 사실만 그 값을 바꾼다.
도구가 올리면 값은 "마지막 검토일" 이 아니라 "마지막 실행일" 이 되어 뜻을 잃는다.

의존성이 없다. front matter 파서를 직접 갖고 있고, 읽을 수 없는 줄은 추측하지 않고
파일과 행 번호를 붙여 실패한다. YAML 문법의 권위는 schemas/docs-frontmatter.schema.json
을 검사하는 tests/check-docs-metadata.sh 에 있다.

이 파일은 줄 길이 88 과 100 에서 ruff format 결과가 같아야 한다. 파이썬을 쓰지 않는
저장소에는 pyproject.toml 이 없어서 ruff 가 기본값 88 로 돌고, 있으면 이 저장소 표준인
100 으로 돈다. 두 자리에서 결과가 갈리면 tests/check-python.sh 가 둘 중 한쪽에서 반드시
실패한다. 여러 줄로 나뉜 호출에는 마지막 인자 뒤에 쉼표를 남겨 그 형태를 고정한다.

사용법:
  uv run --script scripts/docs_freshness.py
  uv run --script scripts/docs_freshness.py --only drift
  uv run --script scripts/docs_freshness.py --today 2026-12-31 --strict

종료 코드: FAIL 이 하나라도 있으면 1, 알 수 없는 옵션이면 2, 아니면 0
"""

import argparse
import io
import re
import subprocess
import sys
from datetime import UTC, date, datetime
from pathlib import Path


def use_utf8() -> None:
    """표준 출력을 UTF-8 로 고정한다."""
    # Windows 의 기본 인코딩은 UTF-8 이 아니다. 파이프로 넘기면 한글 메시지가 깨지거나
    # UnicodeEncodeError 로 죽는다. 훅과 CI 는 언제나 파이프로 받는다.
    for stream in (sys.stdout, sys.stderr):
        if isinstance(stream, io.TextIOWrapper):
            stream.reconfigure(encoding="utf-8")


use_utf8()

ALL_PHASES = ("time", "drift")

# type 별 검토 주기 기본값. front matter 의 review_interval_days 가 있으면 그것이 이긴다.
# 0 은 시간으로 낡지 않는다는 뜻이다. decision 은 그때의 판단을 남긴 기록이라 낡지 않는다.
DEFAULT_INTERVALS = {
    "index": 365,
    "standard": 180,
    "guide": 180,
    "reference": 365,
    "generated": 90,
    "decision": 0,
}
FALLBACK_INTERVAL = 180

FM_KEY = re.compile(r"^([A-Za-z_][A-Za-z0-9_]*):[ \t]*(.*)$")
FM_ITEM = re.compile(r"^[ \t]+-[ \t]+(.*)$")

FrontMatter = dict[str, "str | list[str]"]


class DocError(Exception):
    """문서 하나를 읽지 못했을 때 난다."""


def unquote(raw: str) -> str:
    """스칼라 값에서 감싼 따옴표 한 겹을 벗긴다."""
    text = raw.strip()
    if len(text) >= 2 and text[0] == text[-1] and text[0] in "\"'":
        return text[1:-1]
    return text


def absorb(data: FrontMatter, key: str, line: str, number: int) -> str:
    """머리말 한 줄을 넣고 이어질 목록이 붙을 키를 돌려준다."""
    item = FM_ITEM.match(line)
    if item is not None:
        if not key:
            raise DocError(f"{number}행: 어느 키에도 속하지 않는 목록 항목이다")
        current = data.get(key)
        if isinstance(current, str) and current:
            raise DocError(f"{number}행: '{key}' 는 이미 스칼라 값을 갖고 있다")
        bucket = current if isinstance(current, list) else []
        bucket.append(unquote(item.group(1)))
        data[key] = bucket
        return key
    pair = FM_KEY.match(line)
    if pair is None:
        raise DocError(f"{number}행: 읽을 수 없는 줄이다: {line.strip()}")
    if pair.group(1) in data:
        raise DocError(f"{number}행: '{pair.group(1)}' 키가 두 번 나온다")
    data[pair.group(1)] = unquote(pair.group(2))
    return pair.group(1)


def read_front_matter(path: Path) -> FrontMatter:
    """문서 첫머리의 front matter 를 읽는다."""
    lines = path.read_text(encoding="utf-8").splitlines()
    if not lines or lines[0].strip() != "---":
        raise DocError("front matter 가 없다. 첫 줄이 '---' 여야 한다")
    data: FrontMatter = {}
    key = ""
    for number, line in enumerate(lines[1:], start=2):
        stripped = line.strip()
        if stripped == "---":
            return data
        if not stripped or stripped.startswith("#"):
            continue
        key = absorb(data, key, line, number)
    raise DocError("front matter 를 닫는 '---' 가 없다")


def fm_str(data: FrontMatter, key: str) -> str:
    """스칼라 값을 읽는다. 없으면 빈 문자열이다."""
    value = data.get(key, "")
    return value if isinstance(value, str) else ""


def fm_list(data: FrontMatter, key: str) -> list[str]:
    """목록 값을 읽는다. 스칼라 하나면 한 항목짜리 목록으로 본다."""
    value = data.get(key)
    if isinstance(value, list):
        return value
    return [value] if isinstance(value, str) and value else []


class Report:
    """판정을 세어 마지막에 집계한다."""

    def __init__(self) -> None:
        """빈 집계로 시작한다."""
        self.counts = {"PASS": 0, "WARN": 0, "FAIL": 0, "SKIP": 0}

    def add(self, verdict: str, target: str, detail: str = "") -> None:
        """판정 한 줄을 낸다."""
        self.counts[verdict] += 1
        print(f"{verdict:<4} {target:<48} {detail}")

    def banner(self, index: int, total: int, name: str) -> None:
        """단계 머리글을 낸다."""
        print()
        print(f"[{index}/{total}] {name}")

    def summary(self) -> None:
        """집계를 낸다."""
        counts = self.counts
        print()
        print(
            f"결과: PASS {counts['PASS']}, WARN {counts['WARN']}, "
            f"FAIL {counts['FAIL']}, SKIP {counts['SKIP']}"
        )


class Doc:
    """검사 대상 문서 하나."""

    def __init__(self, rel: str, data: FrontMatter) -> None:
        """머리말에서 수명주기에 필요한 값만 뽑아 둔다."""
        self.rel = rel
        self.data = data
        self.type = fm_str(data, "type")
        self.last_reviewed = fm_str(data, "last_reviewed")
        # generated_from 은 "이 문서가 생성된 원본" 이므로 서술 대상 경로와 성질이 같다.
        # 따로 두면 생성 문서가 drift 검사를 받으려고 같은 경로를 두 번 적어야 한다.
        self.sources = fm_list(data, "sources") + fm_list(data, "generated_from")

    def interval(self) -> int:
        """검토 주기를 돌려준다. front matter 값이 없으면 type 별 기본값이다."""
        raw = fm_str(self.data, "review_interval_days")
        if not raw:
            return DEFAULT_INTERVALS.get(self.type, FALLBACK_INTERVAL)
        if not raw.isdigit():
            raise DocError(f"review_interval_days='{raw}' 는 0 이상의 정수가 아니다")
        return int(raw)

    def reviewed_on(self) -> date:
        """last_reviewed 를 날짜로 돌려준다."""
        try:
            return date.fromisoformat(self.last_reviewed)
        except ValueError as error:
            raise DocError(
                f"last_reviewed='{self.last_reviewed}' 를 날짜로 읽을 수 없다. YYYY-MM-DD 로 적는다"
            ) from error


def collect_docs(docs_root: Path, root: Path, report: Report) -> list[Doc]:
    """docs/ 아래 문서를 모은다. 읽지 못한 문서는 FAIL 로 남기고 뺀다."""
    docs: list[Doc] = []
    paths = sorted(p for p in docs_root.rglob("*") if p.suffix in {".md", ".mdx"})
    for path in paths:
        rel = path.relative_to(root).as_posix()
        try:
            docs.append(Doc(rel, read_front_matter(path)))
        except DocError as error:
            report.add("FAIL", rel, f"front matter 를 읽지 못했다: {error}")
    return docs


def git_last_change(root: Path, target: str) -> str:
    """경로를 마지막으로 바꾼 커밋 날짜를 YYYY-MM-DD 로 돌려준다. 이력이 없으면 빈 문자열이다."""
    result = subprocess.run(
        ["git", "-C", str(root), "log", "-1", "--format=%cs", "--", target],
        capture_output=True,
        text=True,
        check=False,
    )
    return result.stdout.strip() if result.returncode == 0 else ""


def check_time(docs: list[Doc], today: date, report: Report) -> None:
    """시간 기준 신선도를 본다. 낡은 문서는 WARN 이다."""
    for doc in docs:
        if not doc.last_reviewed:
            report.add(
                "SKIP",
                doc.rel,
                "last_reviewed 가 없다. 사람이 검토한 뒤 채운다",
            )
            continue
        try:
            reviewed, interval = doc.reviewed_on(), doc.interval()
        except DocError as error:
            report.add("FAIL", doc.rel, str(error))
            continue
        if interval == 0:
            report.add(
                "SKIP",
                doc.rel,
                f"review_interval_days=0. type {doc.type} 은 시간으로 낡지 않는다",
            )
            continue
        age = (today - reviewed).days
        if age > interval:
            report.add(
                "WARN",
                doc.rel,
                f"stale-by-time: last_reviewed={doc.last_reviewed} 에서 {age}일 지났다. "
                f"검토 주기는 {interval}일이다. 고치기: 문서를 다시 읽고 last_reviewed 를 "
                f"{today.isoformat()} 로 올린다",
            )
        else:
            report.add("PASS", doc.rel, f"fresh: {age}/{interval}일")


def drift_of(root: Path, doc: Doc, report: Report) -> None:
    """문서 하나의 source drift 를 본다."""
    reviewed = doc.reviewed_on() if doc.last_reviewed else None
    for index, source in enumerate(doc.sources):
        label = f"sources[{index}]='{source}'"
        if not (root / source).exists():
            report.add(
                "FAIL",
                doc.rel,
                f"invalid-source-reference: {label} 가 저장소에 없다. "
                f"고치기: 경로를 고치거나 그 항목을 지운다",
            )
            continue
        changed = git_last_change(root, source)
        if not changed:
            report.add(
                "SKIP",
                doc.rel,
                f"{label} 에 git 이력이 없다. 아직 커밋되지 않았다",
            )
            continue
        if reviewed is None:
            report.add(
                "SKIP",
                doc.rel,
                f"{label} 는 last_reviewed 가 없어 비교할 기준이 없다",
            )
            continue
        if date.fromisoformat(changed) > reviewed:
            report.add(
                "FAIL",
                doc.rel,
                f"possibly-stale-source-drift: {label} 가 {changed} 에 바뀌었고 "
                f"last_reviewed={doc.last_reviewed} 보다 뒤다. 고치기: 문서를 다시 읽고 "
                f"맞으면 last_reviewed 를 {changed} 이상으로 올린다",
            )
        else:
            report.add("PASS", doc.rel, f"fresh: {label} 마지막 변경 {changed}")


def check_drift(root: Path, docs: list[Doc], report: Report) -> None:
    """선언된 sources 가 last_reviewed 이후에 바뀌었는지 본다."""
    for doc in docs:
        if not doc.sources:
            report.add(
                "SKIP",
                doc.rel,
                "sources 가 없다. 서술 대상 경로를 적으면 검사한다",
            )
            continue
        try:
            drift_of(root, doc, report)
        except DocError as error:
            report.add("FAIL", doc.rel, str(error))


def select_phases(raw: str) -> list[str]:
    """쉼표로 이어진 단계 목록을 정규 순서로 되돌린다."""
    wanted = [name for name in raw.split(",") if name]
    usable = " ".join(ALL_PHASES)
    for name in wanted:
        if name not in ALL_PHASES:
            print(f"FAIL: 그런 검사 단계가 없다: {name}", file=sys.stderr)
            print(f"      쓸 수 있는 단계: {usable}", file=sys.stderr)
            raise SystemExit(2)
    return [name for name in ALL_PHASES if name in wanted]


def local_today() -> date:
    """오늘 날짜를 지역 시간대 기준으로 돌려준다."""
    return datetime.now(tz=UTC).astimezone().date()


def git_toplevel() -> str:
    """현재 디렉터리가 속한 저장소 루트를 돌려준다."""
    result = subprocess.run(
        ["git", "rev-parse", "--show-toplevel"],
        capture_output=True,
        text=True,
        check=False,
    )
    if result.returncode != 0:
        raise SystemExit("FAIL: git 저장소가 아니다")
    return result.stdout.strip()


def parse_args() -> argparse.Namespace:
    """명령줄 인자를 읽는다."""
    parser = argparse.ArgumentParser(
        prog="docs_freshness.py",
        description="문서 수명주기 검사. 시간 기준 신선도와 source drift 를 따로 낸다",
    )
    parser.add_argument(
        "--root",
        default="",
        help="저장소 루트. 기본은 git rev-parse --show-toplevel",
    )
    parser.add_argument(
        "--docs",
        default="docs",
        help="문서 디렉터리. 루트 기준 상대 경로",
    )
    parser.add_argument(
        "--only",
        default="",
        help=f"검사 단계. {','.join(ALL_PHASES)} 중에서 고른다",
    )
    parser.add_argument(
        "--today",
        default="",
        help="오늘 날짜. YYYY-MM-DD. 테스트가 쓴다",
    )
    parser.add_argument(
        "--strict",
        action="store_true",
        help="WARN 도 실패로 친다. 예약 CI 가 쓴다",
    )
    return parser.parse_args()


def main() -> int:
    """검사를 돌리고 종료 코드를 돌려준다."""
    args = parse_args()
    phases = select_phases(args.only) if args.only else list(ALL_PHASES)
    if not phases:
        raise SystemExit("FAIL: 돌릴 검사 단계가 없다")
    root = Path(args.root or git_toplevel()).resolve()
    docs_root = root / args.docs
    if not docs_root.is_dir():
        print(f"SKIP {args.docs}/ 가 없다")
        return 0

    report = Report()
    docs = collect_docs(docs_root, root, report)
    if not docs:
        print(f"SKIP {args.docs}/ 에 문서가 없다")
        return 1 if report.counts["FAIL"] else 0

    print(f"대상 문서: {len(docs)}개")
    today = date.fromisoformat(args.today) if args.today else local_today()
    for index, phase in enumerate(phases, start=1):
        if phase == "time":
            report.banner(
                index,
                len(phases),
                f"시간 기준 신선도 (오늘 {today.isoformat()})",
            )
            check_time(docs, today, report)
        else:
            report.banner(index, len(phases), "source drift (git 이력 기준)")
            check_drift(root, docs, report)

    report.summary()
    failed = report.counts["FAIL"] + (report.counts["WARN"] if args.strict else 0)
    if failed:
        print("규약: docs/standards/documentation.md", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
