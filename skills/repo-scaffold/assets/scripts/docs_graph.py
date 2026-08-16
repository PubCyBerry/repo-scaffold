# shebang 을 두지 않는다. 이 파일은 uv run --script 로만 불리고 실행 권한을 받지 않는다.
# 권한 없는 파일에 shebang 이 있으면 ruff 가 EXE001 로 잡는다. 파일 권한이 없는
# Windows 에서는 그 규칙이 조용히 넘어가서 리눅스 CI 에서만 드러난다.
# /// script
# requires-python = ">=3.11"
# dependencies = []
# ///
"""문서 그래프 검사. id, 참조, 대체 관계, 선언된 소스, 도달 가능성을 본다.

단계는 다섯이고 --only 로 고른다.

  id            id 중복과 표기 형식. id 는 <type>-<slug> 다
  refs          related 와 supersedes 대상이 실재하는가. 자기 참조인가
  supersession  대체 관계가 성립하는가. 순환인가. 대체된 문서가 아직 살아 있는가
  sources       sources 와 generated_from 에 적힌 경로가 실재하는가
  orphans       AGENTS.md 와 docs/index.md 에서 링크로 닿는가

orphans 는 WARN 이다. 아직 인덱스에 줄을 안 넣었을 뿐인 새 문서가 많고, 그것으로
커밋을 막으면 --no-verify 가 습관이 된다. --strict 를 주면 실패로 친다.

의존성이 없다. front matter 파서를 직접 갖고 있고, 읽을 수 없는 줄은 추측하지 않고
파일과 행 번호를 붙여 실패한다. YAML 문법의 권위는 schemas/docs-frontmatter.schema.json
을 검사하는 tests/check-docs-metadata.sh 에 있다.

파서가 scripts/docs_freshness.py 와 겹친다. PEP-723 스크립트는 저장소의 패키지 설정
없이 혼자 돌아야 하므로 공용 모듈로 빼지 않는다.

이 파일은 줄 길이 88 과 100 에서 ruff format 결과가 같아야 한다. 파이썬을 쓰지 않는
저장소에는 pyproject.toml 이 없어서 ruff 가 기본값 88 로 돌고, 있으면 이 저장소 표준인
100 으로 돈다. 두 자리에서 결과가 갈리면 tests/check-python.sh 가 둘 중 한쪽에서 반드시
실패한다. 여러 줄로 나뉜 호출에는 마지막 인자 뒤에 쉼표를 남겨 그 형태를 고정한다.

사용법:
  uv run --script scripts/docs_graph.py
  uv run --script scripts/docs_graph.py --only id,refs
  uv run --script scripts/docs_graph.py --strict

종료 코드: FAIL 이 하나라도 있으면 1, 알 수 없는 옵션이면 2, 아니면 0
"""

import argparse
import io
import posixpath
import re
import subprocess
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

ALL_PHASES = ("id", "refs", "supersession", "sources", "orphans")

# 도달 가능성의 출발점. 에이전트가 저장소를 여는 두 지점이다.
ROOT_DOCS = ("AGENTS.md", "docs/index.md")

TYPE_ENUM = ("index", "standard", "guide", "reference", "generated", "decision")

# 더 읽을 필요가 없어진 상태. 이 상태가 아니면 다른 문서가 대체했다고 볼 수 없다.
RETIRED = ("deprecated", "outdated", "archived", "stale", "superseded", "rejected")

ID_PATTERN = re.compile(r"^[a-z0-9]+(-[a-z0-9]+)+$")
LINK_PATTERN = re.compile(r"\]\(([^)]+)\)")
FENCE_PATTERN = re.compile(r"^[ \t]*```")
EXTERNAL_PATTERN = re.compile(r"^(https?|mailto|ftp|tel):")

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
        """머리말에서 그래프에 필요한 값만 뽑아 둔다."""
        self.rel = rel
        self.id = fm_str(data, "id")
        self.type = fm_str(data, "type")
        self.status = fm_str(data, "status")
        self.related = fm_list(data, "related")
        self.supersedes = fm_list(data, "supersedes")
        self.sources = fm_list(data, "sources") + fm_list(data, "generated_from")


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


def check_id(docs: list[Doc], report: Report) -> None:
    """문서 id 의 중복과 표기 형식을 본다."""
    owners: dict[str, list[str]] = {}
    for doc in docs:
        owners.setdefault(doc.id, []).append(doc.rel)
    for doc in docs:
        holders = owners[doc.id]
        if len(holders) > 1:
            report.add(
                "FAIL",
                doc.rel,
                f"id='{doc.id}' 가 {len(holders)}개 문서에 있다: {', '.join(holders)}. "
                f"고치기: 한 문서만 남기고 나머지 id 를 바꾼다",
            )
        elif not ID_PATTERN.match(doc.id):
            report.add(
                "FAIL",
                doc.rel,
                f"id='{doc.id}' 는 <type>-<slug> 형식이 아니다. "
                f"고치기: 소문자와 숫자와 하이픈으로 '{doc.type}-<slug>' 처럼 적는다",
            )
        elif doc.id.split("-")[0] != doc.type and doc.type in TYPE_ENUM:
            report.add(
                "WARN",
                doc.rel,
                f"id='{doc.id}' 의 앞머리가 type='{doc.type}' 과 다르다. "
                f"고치기: '{doc.type}-' 로 시작하게 바꾼다",
            )
        else:
            report.add("PASS", doc.rel, f"id={doc.id}")


def check_one_ref(
    doc: Doc, field: str, values: list[str], index_of: dict[str, Doc], report: Report
) -> None:
    """참조 필드 하나의 대상이 실재하는지 본다."""
    for index, target in enumerate(values):
        label = f"{field}[{index}]='{target}'"
        if target == doc.id:
            report.add(
                "FAIL",
                doc.rel,
                f"{label} 가 자기 자신이다. 고치기: 그 항목을 지운다",
            )
        elif target not in index_of:
            report.add(
                "FAIL",
                doc.rel,
                f"{label} 를 가진 문서가 없다. 고치기: id 오타를 고치거나 그 항목을 지운다",
            )
        else:
            report.add("PASS", doc.rel, f"{label} -> {index_of[target].rel}")


def check_refs(docs: list[Doc], index_of: dict[str, Doc], report: Report) -> None:
    """참조한 id 가 실재하는지, 자기 참조인지 본다."""
    for doc in docs:
        if not doc.related and not doc.supersedes:
            report.add("SKIP", doc.rel, "related 와 supersedes 가 없다")
            continue
        check_one_ref(doc, "related", doc.related, index_of, report)
        check_one_ref(doc, "supersedes", doc.supersedes, index_of, report)


def supersession_cycle(doc: Doc, index_of: dict[str, Doc]) -> list[str]:
    """대체 사슬을 따라가 doc 자신에게 돌아오면 그 경로를 돌려준다."""
    stack = [(doc, [doc.id])]
    seen: set[str] = set()
    while stack:
        current, path = stack.pop()
        for target in current.supersedes:
            following = index_of.get(target)
            if following is None:
                continue
            if target == doc.id:
                return [*path, target]
            if target not in seen:
                seen.add(target)
                stack.append((following, [*path, target]))
    return []


def warn_retired_related(doc: Doc, index_of: dict[str, Doc], report: Report) -> None:
    """이미 물러난 문서를 related 가 가리키면 알린다."""
    for target in doc.related:
        old = index_of.get(target)
        if old is not None and old.status in RETIRED:
            report.add(
                "WARN",
                doc.rel,
                f"related='{target}' 가 가리키는 {old.rel} 의 status 가 '{old.status}' 다. "
                f"고치기: 대체 문서를 가리키거나 그 항목을 지운다",
            )


def check_supersession(
    docs: list[Doc],
    index_of: dict[str, Doc],
    report: Report,
) -> None:
    """대체 관계가 성립하는지 본다."""
    for doc in docs:
        warn_retired_related(doc, index_of, report)
        if not doc.supersedes:
            report.add("SKIP", doc.rel, "supersedes 가 없다")
            continue
        sound = True
        cycle = supersession_cycle(doc, index_of)
        if cycle:
            sound = False
            report.add(
                "FAIL",
                doc.rel,
                f"supersedes 사슬이 순환한다: {' -> '.join(cycle)}. "
                f"고치기: 사슬 한 곳에서 supersedes 항목을 지운다",
            )
        for target in doc.supersedes:
            old = index_of.get(target)
            if old is not None and old.status not in RETIRED:
                sound = False
                report.add(
                    "FAIL",
                    doc.rel,
                    f"supersedes='{target}' 인데 {old.rel} 의 status 가 아직 '{old.status}' 다. "
                    f"고치기: 그 문서 status 를 {', '.join(RETIRED)} 중 맞는 값으로 바꾼다",
                )
        if sound:
            report.add("PASS", doc.rel, f"{len(doc.supersedes)}개 문서를 대체한다")


def check_sources(root: Path, docs: list[Doc], report: Report) -> None:
    """선언된 소스 경로가 실재하는지 본다."""
    for doc in docs:
        if not doc.sources:
            report.add("SKIP", doc.rel, "sources 가 없다")
            continue
        for index, source in enumerate(doc.sources):
            label = f"sources[{index}]='{source}'"
            if (root / source).exists():
                report.add("PASS", doc.rel, f"{label} 실재한다")
            else:
                report.add(
                    "FAIL",
                    doc.rel,
                    f"{label} 가 저장소에 없다. 고치기: 경로를 고치거나 그 항목을 지운다",
                )


def links_of(root: Path, rel: str) -> list[str]:
    """문서 하나가 링크로 가리키는 저장소 안 마크다운 경로를 돌려준다."""
    targets: list[str] = []
    fence = False
    base = posixpath.dirname(rel)
    for line in (root / rel).read_text(encoding="utf-8").splitlines():
        if FENCE_PATTERN.match(line):
            fence = not fence
            continue
        if fence:
            continue
        for raw in LINK_PATTERN.findall(line):
            target = raw.split("#")[0].strip()
            if not target or EXTERNAL_PATTERN.match(target) or target.startswith("/"):
                continue
            resolved = posixpath.normpath(posixpath.join(base, target))
            if resolved.endswith((".md", ".mdx")) and (root / resolved).is_file():
                targets.append(resolved)
    return targets


def check_orphans(root: Path, docs: list[Doc], report: Report) -> None:
    """AGENTS.md 와 docs/index.md 에서 링크로 닿지 않는 문서를 찾는다."""
    by_id = {doc.id: doc.rel for doc in docs}
    extra: dict[str, list[str]] = {}
    for doc in docs:
        # front matter 의 참조도 간선이다. 인덱스에 줄이 있으면 링크로도 닿지만,
        # 다른 문서가 related 로 끌어오는 문서를 고아로 부르면 알림이 시끄러워진다.
        refs = doc.related + doc.supersedes
        extra[doc.rel] = [by_id[ref] for ref in refs if ref in by_id]
    starts = [rel for rel in ROOT_DOCS if (root / rel).is_file()]
    if not starts:
        report.add("SKIP", "orphans", f"출발점이 없다: {', '.join(ROOT_DOCS)}")
        return
    seen: set[str] = set()
    frontier = list(starts)
    while frontier:
        rel = frontier.pop()
        if rel in seen:
            continue
        seen.add(rel)
        frontier.extend(links_of(root, rel) + extra.get(rel, []))
    for doc in docs:
        if doc.rel in seen:
            report.add("PASS", doc.rel, "루트에서 닿는다")
        else:
            report.add(
                "WARN",
                doc.rel,
                f"고아 문서다. {' 와 '.join(ROOT_DOCS)} 에서 링크로 닿지 않는다. "
                f"고치기: 그 디렉터리 index.md 에 한 줄 넣는다",
            )


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
        prog="docs_graph.py",
        description="문서 그래프 검사. id, 참조, 대체 관계, 선언된 소스, 도달 가능성을 본다",
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
    parser.add_argument("--strict", action="store_true", help="WARN 도 실패로 친다")
    return parser.parse_args()


def run_phase(phase: str, root: Path, docs: list[Doc], report: Report) -> None:
    """단계 하나를 돌린다."""
    index_of = {doc.id: doc for doc in docs}
    if phase == "id":
        check_id(docs, report)
    elif phase == "refs":
        check_refs(docs, index_of, report)
    elif phase == "supersession":
        check_supersession(docs, index_of, report)
    elif phase == "sources":
        check_sources(root, docs, report)
    else:
        check_orphans(root, docs, report)


PHASE_TITLE = {
    "id": "id 중복과 형식",
    "refs": "related, supersedes 대상",
    "supersession": "대체 관계",
    "sources": "선언된 소스 경로",
    "orphans": "도달 가능성",
}


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
    for index, phase in enumerate(phases, start=1):
        report.banner(index, len(phases), PHASE_TITLE[phase])
        run_phase(phase, root, docs, report)

    report.summary()
    failed = report.counts["FAIL"] + (report.counts["WARN"] if args.strict else 0)
    if failed:
        print("규약: docs/standards/documentation.md", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
