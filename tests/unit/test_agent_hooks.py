# scripts/agent-hooks/ 훅의 판정을 확인한다.
#
# 훅을 import 하지 않고 셸로 부른다. Claude Code 와 Codex 가 부르는 방식이 그것뿐이라,
# 그 경로를 그대로 돌려야 계약을 확인한 것이 된다. 입력은 표준 입력의 JSON 이고
# 판정은 종료 코드다. 0 이 통과, 2 가 차단이다.
#
# 두 에이전트의 페이로드를 각각 넣는다. 도구 이름과 편집 키가 달라서, 한쪽만 통과하는
# 정규화는 나머지 에이전트에서 규칙을 통째로 끈다.
#
# 오탐 케이스가 차단 케이스만큼 많다. 정상 명령을 막는 훅은 사람이 훅을 꺼버리므로,
# 막지 말아야 할 것을 막지 않는지가 같은 무게의 계약이다.

import json
import shutil
import subprocess
from collections.abc import Iterator, Mapping
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parents[2]
HOOK_DIR = REPO_ROOT / "scripts" / "agent-hooks"

PRE_TOOL_USE = HOOK_DIR / "pre-tool-use.sh"
STOP = HOOK_DIR / "stop.sh"

ALLOW = 0
DENY = 2

# 윈도우에서 subprocess 는 PATH 보다 System32 를 먼저 뒤진다. 거기 있는 bash.exe 는 WSL
# 실행기라 C:/ 경로를 열지 못한다. 실행 파일을 미리 찾아 절대 경로로 부른다.
BASH = shutil.which("bash")


@pytest.fixture(autouse=True)
def _require_tools() -> Iterator[None]:
    if BASH is None:
        pytest.skip("bash 가 없어 훅을 돌릴 수 없다")
    if shutil.which("jq") is None:
        pytest.skip("jq 가 없어 훅이 페이로드를 읽지 못한다")
    yield


def run_hook(
    script: Path,
    payload: Mapping[str, object],
    cwd: Path = REPO_ROOT,
) -> subprocess.CompletedProcess[str]:
    """훅 하나를 페이로드와 함께 돌리고 결과를 그대로 돌려준다.

    경로는 POSIX 형태로 넘긴다. 윈도우 경로를 그대로 주면 bash 가 역슬래시를
    이스케이프로 읽어 파일을 못 찾는다.
    """
    return subprocess.run(
        [str(BASH), script.as_posix()],
        input=json.dumps(payload),
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        cwd=cwd,
        check=False,
    )


@pytest.fixture
def work_repo(tmp_path: Path) -> Path:
    """기본 브랜치가 아닌 브랜치에 서 있는 빈 저장소.

    push 규칙과 완료 정의 표시는 현재 브랜치와 .git 디렉터리를 본다. 이 저장소에서
    돌리면 판정이 실행하는 사람의 브랜치와 훅 표시 상태에 따라 달라진다.
    """
    root = tmp_path / "work"
    root.mkdir()
    subprocess.run(["git", "init", "-q", str(root)], check=True, capture_output=True)
    subprocess.run(
        ["git", "-C", str(root), "checkout", "-q", "-b", "work"],
        check=True,
        capture_output=True,
    )
    return root


def bash_payload(command: str) -> dict[str, object]:
    """셸 도구 페이로드. 두 에이전트 모두 도구 이름이 Bash 다."""
    return {
        "hook_event_name": "PreToolUse",
        "tool_name": "Bash",
        "tool_input": {"command": command},
    }


def claude_edit_payload(path: str, old: str, new: str) -> dict[str, object]:
    """Claude Code 의 Edit 페이로드."""
    return {
        "hook_event_name": "PreToolUse",
        "tool_name": "Edit",
        "tool_input": {"file_path": path, "old_string": old, "new_string": new},
    }


def codex_patch_payload(patch: str) -> dict[str, object]:
    """Codex 의 apply_patch 페이로드. 경로가 패치 본문 안에 있다."""
    return {
        "hook_event_name": "PreToolUse",
        "tool_name": "apply_patch",
        "tool_input": {"input": patch},
    }


@pytest.mark.parametrize(
    "command",
    [
        "grep -rn pattern .",
        "grep -R pattern src",
        "egrep --include=*.py pattern .",
        "find . -name '*.py'",
        "git commit --no-verify -m 'x'",
        "git commit -n -m 'x'",
        "pip install requests",
        "python -m venv .venv",
        "poetry add requests",
        "cat .env",
    ],
)
def test_shell_rule_denies(command: str) -> None:
    result = run_hook(PRE_TOOL_USE, bash_payload(command))
    assert result.returncode == DENY, f"막았어야 한다: {command}\n{result.stderr}"
    assert result.stderr.strip(), "차단에는 사유가 붙어야 한다"


@pytest.mark.parametrize(
    "command",
    [
        "rg -n pattern",
        "fd --extension py",
        "ast-grep --pattern 'fetch($$$)'",
        "gh pr list | grep open",
        "grep pattern one-file.txt",
        "uv pip install requests",
        "uv run pytest",
        "uv sync",
        "cat .env.example",
        "just verify",
    ],
)
def test_shell_rule_allows(command: str) -> None:
    result = run_hook(PRE_TOOL_USE, bash_payload(command))
    assert result.returncode == ALLOW, f"막지 말았어야 한다: {command}\n{result.stderr}"


def test_force_push_denied(work_repo: Path) -> None:
    result = run_hook(PRE_TOOL_USE, bash_payload("git push --force origin HEAD"), cwd=work_repo)
    assert result.returncode == DENY


def test_lease_push_allowed(work_repo: Path) -> None:
    """리뷰가 읽은 커밋을 지우지 않는 push 는 막지 않는다."""
    payload = bash_payload("git push --force-with-lease origin HEAD")
    assert run_hook(PRE_TOOL_USE, payload, cwd=work_repo).returncode == ALLOW


def test_push_to_default_branch_denied(tmp_path: Path) -> None:
    root = tmp_path / "onmain"
    root.mkdir()
    subprocess.run(["git", "init", "-q", "-b", "main", str(root)], check=True, capture_output=True)
    result = run_hook(PRE_TOOL_USE, bash_payload("git push -u origin HEAD"), cwd=root)
    assert result.returncode == DENY


def test_last_reviewed_denied_for_claude() -> None:
    payload = claude_edit_payload(
        "docs/standards/shell.md",
        "status: active",
        "status: active\nlast_reviewed: 2026-01-01",
    )
    assert run_hook(PRE_TOOL_USE, payload).returncode == DENY


def test_last_reviewed_denied_for_codex() -> None:
    patch = "*** Update File: docs/standards/shell.md\n+last_reviewed: 2026-01-01\n"
    assert run_hook(PRE_TOOL_USE, codex_patch_payload(patch)).returncode == DENY


def test_edit_that_keeps_an_existing_last_reviewed_is_allowed() -> None:
    """이미 그 줄을 갖고 있는 문서를 다른 이유로 고치는 것은 막지 않는다."""
    payload = claude_edit_payload(
        "docs/standards/documentation.md",
        "## Purpose",
        "## Purpose\n\nAn added sentence.",
    )
    assert run_hook(PRE_TOOL_USE, payload).returncode == ALLOW


def test_generated_directory_denied() -> None:
    payload = {
        "hook_event_name": "PreToolUse",
        "tool_name": "Write",
        "tool_input": {"file_path": "docs/generated/schema.md", "content": "x"},
    }
    assert run_hook(PRE_TOOL_USE, payload).returncode == DENY


def test_generated_index_block_denied() -> None:
    payload = claude_edit_payload(
        "AGENTS.md",
        "placeholder",
        "[Docs Index]|root: .|docs:{index.md}",
    )
    assert run_hook(PRE_TOOL_USE, payload).returncode == DENY


def test_stop_reports_banned_notation(tmp_path: Path, work_repo: Path) -> None:
    transcript = tmp_path / "transcript.jsonl"
    lines = [
        {"type": "user", "message": {"content": "질문"}},
        {
            "type": "assistant",
            "message": {"content": [{"type": "text", "text": "결론 — 이렇게 한다"}]},
        },
    ]
    transcript.write_text(
        "\n".join(json.dumps(line, ensure_ascii=False) for line in lines) + "\n",
        encoding="utf-8",
    )
    payload = {
        "hook_event_name": "Stop",
        "stop_hook_active": False,
        "transcript_path": transcript.as_posix(),
    }
    result = run_hook(STOP, payload, cwd=work_repo)
    assert result.returncode == DENY
    assert "금칙 문자" in result.stderr


def test_stop_skips_code_blocks(tmp_path: Path, work_repo: Path) -> None:
    """명령과 도구 출력은 그대로 옮기는 것이 규칙이라 코드는 검사 대상이 아니다."""
    transcript = tmp_path / "transcript.jsonl"
    answer = "출력은 다음과 같다.\n\n```text\nusage: tool -- flag\n```\n\n끝."
    lines = [
        {"type": "user", "message": {"content": "질문"}},
        {"type": "assistant", "message": {"content": [{"type": "text", "text": answer}]}},
    ]
    transcript.write_text(
        "\n".join(json.dumps(line, ensure_ascii=False) for line in lines) + "\n",
        encoding="utf-8",
    )
    payload = {
        "hook_event_name": "Stop",
        "stop_hook_active": False,
        "transcript_path": transcript.as_posix(),
    }
    assert run_hook(STOP, payload, cwd=work_repo).returncode == ALLOW


def test_stop_passes_through_when_already_blocked_once(work_repo: Path) -> None:
    """한 번 막은 뒤에는 통과시킨다. 같은 지적으로 무한히 막히면 턴이 끝나지 않는다."""
    payload = {"hook_event_name": "Stop", "stop_hook_active": True}
    assert run_hook(STOP, payload, cwd=work_repo).returncode == ALLOW
