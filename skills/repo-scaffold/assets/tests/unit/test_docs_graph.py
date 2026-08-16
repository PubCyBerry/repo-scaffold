# scripts/docs_graph.py 의 판정을 확인한다.
#
# 검사기를 import 하지 않고 uv run --script 로 부른다. 훅과 CI 와 사람이 부르는 방식이
# 그것뿐이라, 그 경로를 그대로 돌려야 계약을 확인한 것이 된다.
#
# docs_repo 의 타입을 Any 로 적는 근거는 tests/unit/conftest.py 의 DocsRepo docstring 에 있다.

from typing import Any


def test_valid_graph(docs_repo: Any) -> None:
    front = docs_repo.front("standard-a", "related:\n  - standard-b")
    docs_repo.doc("docs/standards/a.md", front)
    docs_repo.doc("docs/standards/b.md", docs_repo.front("standard-b"))
    docs_repo.link("standards/a.md")
    docs_repo.link("standards/b.md")

    result = docs_repo.run("docs_graph.py", "--strict")

    assert result.returncode == 0, result.stdout
    assert "WARN 0, FAIL 0" in result.stdout


def test_duplicate_id(docs_repo: Any) -> None:
    docs_repo.doc("docs/standards/a.md", docs_repo.front("standard-same"))
    docs_repo.doc("docs/standards/b.md", docs_repo.front("standard-same"))

    result = docs_repo.run("docs_graph.py", "--only", "id")

    assert result.returncode == 1
    assert "id='standard-same' 가 2개 문서에 있다" in result.stdout
    assert "docs/standards/a.md" in result.stdout
    assert "docs/standards/b.md" in result.stdout


def test_id_format(docs_repo: Any) -> None:
    docs_repo.doc("docs/standards/a.md", docs_repo.front("Standard_A"))

    result = docs_repo.run("docs_graph.py", "--only", "id")

    assert result.returncode == 1
    assert "id='Standard_A' 는 <type>-<slug> 형식이 아니다" in result.stdout


def test_missing_related_target(docs_repo: Any) -> None:
    front = docs_repo.front("standard-a", "related:\n  - standard-nope")
    docs_repo.doc("docs/standards/a.md", front)

    result = docs_repo.run("docs_graph.py", "--only", "refs")

    assert result.returncode == 1
    assert "related[0]='standard-nope' 를 가진 문서가 없다" in result.stdout


def test_missing_supersedes_target(docs_repo: Any) -> None:
    front = docs_repo.front("standard-a", "supersedes:\n  - standard-nope")
    docs_repo.doc("docs/standards/a.md", front)

    result = docs_repo.run("docs_graph.py", "--only", "refs")

    assert result.returncode == 1
    assert "supersedes[0]='standard-nope' 를 가진 문서가 없다" in result.stdout


def test_self_reference(docs_repo: Any) -> None:
    front = docs_repo.front("standard-a", "related:\n  - standard-a")
    docs_repo.doc("docs/standards/a.md", front)

    result = docs_repo.run("docs_graph.py", "--only", "refs")

    assert result.returncode == 1
    assert "related[0]='standard-a' 가 자기 자신이다" in result.stdout


def test_superseded_document_must_not_stay_active(docs_repo: Any) -> None:
    front = docs_repo.front("standard-new", "supersedes:\n  - standard-old")
    docs_repo.doc("docs/standards/new.md", front)
    docs_repo.doc("docs/standards/old.md", docs_repo.front("standard-old"))

    result = docs_repo.run("docs_graph.py", "--only", "supersession")

    assert result.returncode == 1
    assert "status 가 아직 'active' 다" in result.stdout


def test_orphan_is_a_warning(docs_repo: Any) -> None:
    docs_repo.doc("docs/standards/lonely.md", docs_repo.front("standard-lonely"))

    warned = docs_repo.run("docs_graph.py", "--only", "orphans")

    assert warned.returncode == 0, warned.stdout
    assert "고아 문서다" in warned.stdout

    strict = docs_repo.run("docs_graph.py", "--only", "orphans", "--strict")

    assert strict.returncode == 1


def test_unknown_phase_is_rejected(docs_repo: Any) -> None:
    result = docs_repo.run("docs_graph.py", "--only", "nosuchphase")

    assert result.returncode == 2
    assert "그런 검사 단계가 없다" in result.stderr
