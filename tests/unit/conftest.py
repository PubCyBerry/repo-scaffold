# 문서 수명주기 검사기 단위 테스트가 함께 쓰는 준비물.
#
# 검사기는 PEP-723 스크립트라 import 하지 않고 uv run --script 로 부른다. 훅과 CI 와
# 사람이 부르는 방식이 그것뿐이므로, 그 경로를 그대로 테스트해야 계약을 테스트한 것이 된다.
#
# source drift 는 git 이력을 보므로 fixture 저장소에 실제로 커밋한다. 커밋 날짜는
# GIT_AUTHOR_DATE 와 GIT_COMMITTER_DATE 로 고정한다. 그래야 오늘이 언제든 결과가 같다.

import os
import shutil
import subprocess
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parents[2]
FIXTURES = Path(__file__).resolve().parent / "fixtures"

DOC_TEMPLATE = (FIXTURES / "doc.md.in").read_text(encoding="utf-8")
INDEX_TEMPLATE = (FIXTURES / "index.md.in").read_text(encoding="utf-8")
AGENTS_TEMPLATE = (FIXTURES / "agents.md.in").read_text(encoding="utf-8")


class DocsRepo:
    """검사기를 돌려볼 임시 git 저장소.

    테스트 파일은 이 클래스를 import 하지 않고 docs_repo fixture 로만 받는다.
    tests/unit 에는 __init__.py 가 없어서 pytest 가 conftest 를 최상위 모듈로 읽는데,
    mypy 는 explicit_package_bases 때문에 같은 파일을 tests.unit.conftest 로 읽는다.
    두 이름이 갈리므로 어느 쪽으로 import 해도 한쪽이 깨진다.
    """

    def __init__(self, root: Path) -> None:
        self.root = root
        (root / "docs").mkdir(parents=True)
        subprocess.run(
            ["git", "init", "-q", str(root)],
            check=True,
            capture_output=True,
        )
        self.write("AGENTS.md", AGENTS_TEMPLATE)
        self.write("docs/index.md", INDEX_TEMPLATE)

    def front(self, doc_id: str, extra: str = "", doc_type: str = "standard") -> str:
        """fixture 문서 하나의 front matter 를 만든다."""
        lines = [
            f"id: {doc_id}",
            "title: Fixture",
            f"type: {doc_type}",
            "status: active",
            "summary: Fixture document for the lifecycle checkers",
            "scope:",
            "  - docs/**",
            "read_when:",
            "  - Never. This is a fixture",
        ]
        if extra:
            lines.append(extra)
        return "\n".join(lines)

    def write(self, rel: str, text: str) -> None:
        """저장소 안에 파일 하나를 쓴다."""
        path = self.root / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text, encoding="utf-8")

    def doc(self, rel: str, front: str, title: str = "Fixture") -> None:
        """front matter 만 다른 문서 하나를 만든다."""
        body = DOC_TEMPLATE.replace("@FRONT@", front).replace("@TITLE@", title)
        self.write(rel, body)

    def link(self, target: str) -> None:
        """docs/index.md 에 링크를 더해 그 문서를 도달 가능하게 만든다."""
        path = self.root / "docs" / "index.md"
        text = path.read_text(encoding="utf-8")
        path.write_text(f"{text}\n- [fixture]({target})\n", encoding="utf-8")

    def git(self, *args: str, env: dict[str, str] | None = None) -> None:
        """저장소 안에서 git 명령 하나를 돌린다."""
        subprocess.run(
            [
                "git",
                "-C",
                str(self.root),
                "-c",
                "user.name=Fixture",
                "-c",
                "user.email=fixture@example.invalid",
                "-c",
                "commit.gpgsign=false",
                *args,
            ],
            check=True,
            capture_output=True,
            env=env,
        )

    def commit(self, when: str, message: str = "chore: fixture") -> None:
        """작업 트리를 통째로 커밋한다. when 이 그 커밋의 날짜가 된다."""
        env = dict(os.environ, GIT_AUTHOR_DATE=when, GIT_COMMITTER_DATE=when)
        self.git("add", "-A")
        self.git("commit", "-q", "--no-verify", "-m", message, env=env)

    def run(self, script: str, *args: str) -> subprocess.CompletedProcess[str]:
        """PEP-723 검사기를 이 저장소에 대고 돌린다."""
        return subprocess.run(
            [
                "uv",
                "run",
                "--script",
                str(REPO_ROOT / "scripts" / script),
                "--root",
                str(self.root),
                *args,
            ],
            capture_output=True,
            text=True,
            encoding="utf-8",
            env=dict(os.environ, PYTHONIOENCODING="utf-8"),
            check=False,
        )


@pytest.fixture
def docs_repo(tmp_path: Path) -> DocsRepo:
    """AGENTS.md 와 docs/index.md 만 있는 빈 fixture 저장소를 만든다."""
    if shutil.which("uv") is None:
        pytest.skip("uv 가 없어 PEP-723 검사기를 돌릴 수 없다")
    return DocsRepo(tmp_path / "repo")
