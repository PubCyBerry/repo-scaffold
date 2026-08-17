# scripts/check_pr_metadata.py 의 판정을 확인한다.
#
# 검사기를 import 하지 않고 uv run --script 로 부른다. 워크플로와 사람이 부르는 방식이
# 그것뿐이라, 그 경로를 그대로 돌려야 계약을 확인한 것이 된다.
#
# 입력은 환경변수로 넘긴다. 워크플로가 그렇게 넘기기 때문이다.

import os
import shutil
import subprocess
from collections.abc import Iterator
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parents[2]
SCRIPT = REPO_ROOT / "scripts" / "check_pr_metadata.py"
TEMPLATE = REPO_ROOT / ".github" / "pull_request_template.md"

SECTIONS = (
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

GOOD_TITLE = "feat(policy): reject an empty pull request section"


@pytest.fixture(autouse=True)
def _require_uv() -> Iterator[None]:
    if shutil.which("uv") is None:
        pytest.skip("uv 가 없어 PEP-723 검사기를 돌릴 수 없다")
    yield


def body_with(drop: str = "", blank: str = "", issue: str = "Closes #12") -> str:
    parts: list[str] = []
    for name in SECTIONS:
        if name == drop:
            continue
        parts.append(f"## {name}")
        if name == blank:
            parts.append("<!-- template comment only -->")
        elif name == "Linked issue":
            parts.append(issue)
        else:
            parts.append(f"content for {name}")
        parts.append("")
    return "\n".join(parts)


def run(
    title: str = GOOD_TITLE,
    body: str | None = None,
    labels: str = "[]",
    args: tuple[str, ...] = (),
) -> subprocess.CompletedProcess[str]:
    env = dict(
        os.environ,
        PR_TITLE=title,
        PR_BODY=body_with() if body is None else body,
        PR_LABELS=labels,
        PYTHONIOENCODING="utf-8",
    )
    return subprocess.run(
        ["uv", "run", "--script", str(SCRIPT), *args],
        capture_output=True,
        text=True,
        encoding="utf-8",
        env=env,
        check=False,
    )


def test_valid_pull_request() -> None:
    result = run()

    assert result.returncode == 0, result.stdout
    assert "FAIL 0" in result.stdout


def test_capitalized_subject() -> None:
    result = run(title="feat(policy): Reject an empty section")

    assert result.returncode == 1
    assert "소문자로 시작한다" in result.stdout


def test_capitalized_type() -> None:
    result = run(title="Feat(policy): reject an empty section")

    assert result.returncode == 1
    assert "소문자로 쓴다" in result.stdout


def test_korean_subject_passes() -> None:
    result = run(title="feat(policy): 빈 절을 막는다")

    assert result.returncode == 0, result.stdout


def test_title_not_conventional() -> None:
    result = run(title="add a refresh token")

    assert result.returncode == 1
    assert "형식이 아니다" in result.stdout or "가 아니다" in result.stdout


def test_title_unknown_type() -> None:
    result = run(title="feature: add a refresh token")

    assert result.returncode == 1
    assert "type 목록 밖이다" in result.stdout


def test_title_trailing_period() -> None:
    result = run(title="fix: drop the stray lock.")

    assert result.returncode == 1
    assert "마침표로 끝내지 않는다" in result.stdout


def test_title_too_long() -> None:
    result = run(title="fix: " + ("a" * 120))

    assert result.returncode == 1
    assert "자 이하다" in result.stdout


def test_title_banned_character() -> None:
    result = run(title="feat: 셸·YAML 설정 정리")

    assert result.returncode == 1
    assert "interpunct" in result.stdout


def test_missing_section() -> None:
    result = run(body=body_with(drop="Validation"))

    assert result.returncode == 1
    assert "필수 절이 없다" in result.stdout
    assert "Validation" in result.stdout


def test_empty_section() -> None:
    result = run(body=body_with(blank="Risk / Compatibility"))

    assert result.returncode == 1
    assert "필수 절이 비었다" in result.stdout


def test_missing_issue_link() -> None:
    result = run(body=body_with(issue="No issue for this one"))

    assert result.returncode == 1
    assert "이슈를 걸거나" in result.stdout


def test_skip_issue_label_exempts() -> None:
    result = run(
        body=body_with(issue="No issue for this one"),
        labels='["policy/skip-issue"]',
    )

    assert result.returncode == 0, result.stdout
    assert "라벨로 면제됨" in result.stdout


def test_issue_url_accepted() -> None:
    link = "Fixes https://github.com/o/r/issues/42"
    result = run(body=body_with(issue=link))

    assert result.returncode == 0, result.stdout


def test_heading_inside_code_fence_is_not_a_section() -> None:
    fenced = "```text\n## Validation\n```\n\n" + body_with(drop="Validation")
    result = run(body=fenced)

    assert result.returncode == 1
    assert "필수 절이 없다" in result.stdout


def test_shipped_template_is_not_a_valid_body() -> None:
    # 템플릿 그대로 낸 PR 은 통과하면 안 된다. HTML 주석을 걷어내면 내용이 없다.
    result = run(body=TEMPLATE.read_text(encoding="utf-8"))

    assert result.returncode == 1
    assert "필수 절이 비었다" in result.stdout


def test_only_title_phase() -> None:
    result = run(body="", args=("--only", "title"))

    assert result.returncode == 0, result.stdout
    assert "sections" not in result.stdout


def test_unknown_phase_exits_two() -> None:
    result = run(args=("--only", "nosuchphase"))

    assert result.returncode == 2
    assert "그런 검사 단계가 없다" in result.stderr


def test_help_lists_phases() -> None:
    result = run(args=("--help",))

    assert result.returncode == 0
    assert "--only" in result.stdout
