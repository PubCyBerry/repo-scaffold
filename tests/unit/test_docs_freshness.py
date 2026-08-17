# scripts/docs_freshness.py 의 판정을 확인한다.
#
# 신호 둘을 갈라서 본다. time 은 시간이 흐른 것뿐이라 WARN 이고, drift 는 문서와 코드가
# 갈라졌다는 뜻이라 FAIL 이다. 둘을 같은 심각도로 묶으면 어느 쪽도 신뢰받지 못한다.
#
# drift 는 파일 시스템 mtime 이 아니라 git 이력을 본다. 그래서 fixture 저장소에 날짜를
# 고정해 실제로 커밋한다.
#
# docs_repo 의 타입을 Any 로 적는 근거는 tests/unit/conftest.py 의 DocsRepo docstring 에 있다.

from typing import Any

DOC = "docs/standards/a.md"
SOURCE = "sources:\n  - src/thing.py"
WHEN = "2026-06-01T12:00:00+00:00"


def test_fresh(docs_repo: Any) -> None:
    front = docs_repo.front("standard-a", f"last_reviewed: 2026-06-30\n{SOURCE}")
    docs_repo.write("src/thing.py", "value = 1\n")
    docs_repo.doc(DOC, front)
    docs_repo.commit(WHEN)

    result = docs_repo.run("docs_freshness.py", "--only", "drift")

    assert result.returncode == 0, result.stdout
    assert "fresh: sources[0]='src/thing.py' 마지막 변경 2026-06-01" in result.stdout


def test_stale_by_time(docs_repo: Any) -> None:
    docs_repo.doc(DOC, docs_repo.front("standard-a", "last_reviewed: 2026-01-01"))
    args = ("--only", "time", "--today", "2026-12-31")

    warned = docs_repo.run("docs_freshness.py", *args)

    # 시간이 흐른 것뿐이라 커밋과 푸시를 막지 않는다.
    assert warned.returncode == 0, warned.stdout
    assert "stale-by-time" in warned.stdout
    assert "364일 지났다" in warned.stdout
    assert "검토 주기는 180일이다" in warned.stdout

    strict = docs_repo.run("docs_freshness.py", *args, "--strict")

    assert strict.returncode == 1


def test_fresh_by_time(docs_repo: Any) -> None:
    docs_repo.doc(DOC, docs_repo.front("standard-a", "last_reviewed: 2026-01-01"))
    args = ("--only", "time", "--today", "2026-03-01")

    result = docs_repo.run("docs_freshness.py", *args)

    assert result.returncode == 0, result.stdout
    assert "fresh: 59/180일" in result.stdout


def test_review_interval_days_overrides_the_default(docs_repo: Any) -> None:
    extra = "last_reviewed: 2026-01-01\nreview_interval_days: 30"
    docs_repo.doc(DOC, docs_repo.front("standard-a", extra))
    args = ("--only", "time", "--today", "2026-03-01")

    result = docs_repo.run("docs_freshness.py", *args)

    assert result.returncode == 0, result.stdout
    assert "stale-by-time" in result.stdout
    assert "검토 주기는 30일이다" in result.stdout


def test_source_drift(docs_repo: Any) -> None:
    front = docs_repo.front("standard-a", f"last_reviewed: 2026-01-01\n{SOURCE}")
    docs_repo.write("src/thing.py", "value = 1\n")
    docs_repo.doc(DOC, front)
    docs_repo.commit(WHEN)

    result = docs_repo.run("docs_freshness.py", "--only", "drift")

    assert result.returncode == 1
    assert "possibly-stale-source-drift" in result.stdout
    assert "sources[0]='src/thing.py' 가 2026-06-01 에 바뀌었고" in result.stdout
    assert "last_reviewed 를 2026-06-01 이상으로 올린다" in result.stdout


def test_missing_source(docs_repo: Any) -> None:
    extra = "last_reviewed: 2026-01-01\nsources:\n  - src/gone.py"
    docs_repo.doc(DOC, docs_repo.front("standard-a", extra))

    result = docs_repo.run("docs_freshness.py", "--only", "drift")

    assert result.returncode == 1
    assert "invalid-source-reference" in result.stdout
    assert "sources[0]='src/gone.py' 가 저장소에 없다" in result.stdout


def test_without_last_reviewed_nothing_is_claimed(docs_repo: Any) -> None:
    docs_repo.write("src/thing.py", "value = 1\n")
    docs_repo.doc(DOC, docs_repo.front("standard-a", SOURCE))
    docs_repo.commit(WHEN)

    result = docs_repo.run("docs_freshness.py")

    assert result.returncode == 0, result.stdout
    assert "last_reviewed 가 없다" in result.stdout
    assert "비교할 기준이 없다" in result.stdout


def test_decision_never_goes_stale_by_time(docs_repo: Any) -> None:
    extra = "last_reviewed: 2020-01-01"
    front = docs_repo.front("decision-0001-a", extra, doc_type="decision")
    docs_repo.doc("docs/architecture/adr/0001-a.md", front)
    args = ("--only", "time", "--today", "2026-12-31", "--strict")

    result = docs_repo.run("docs_freshness.py", *args)

    assert result.returncode == 0, result.stdout
    assert "시간으로 낡지 않는다" in result.stdout
