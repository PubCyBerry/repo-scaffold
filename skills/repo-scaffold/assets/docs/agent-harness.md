---
id: standard-agent-harness
title: Agent Harness
type: standard
status: active
summary: Enforcement layers, the rules the harness hooks own, what stays unenforced
scope:
  - "**"
read_when:
  - Adding a rule that a coding agent has to follow
  - A hook blocked a tool call and the reason is unclear
  - Wiring hooks for Claude Code or Codex
  - Deciding whether a rule can be checked mechanically at all
sources:
  - scripts/agent-hooks
  - .claude/settings.json
  - .codex/hooks.json
  - tests/check-hooks.sh
related:
  - standard-commit-convention
  - standard-documentation
  - standard-writing-style
  - standard-python
---

# Agent Harness

## Purpose

Say where each rule is enforced when the author is a coding agent, and say which rules are not
enforced at all.

Commit hooks and continuous integration read files. An agent's tool choice, the gate it turned
off, and the answer it wrote in chat never reach a file, so no commit-time checker can see
them. The agent harness is the only place those rules can be enforced.

## Scope

Claude Code and Codex working in this repository. Both read [AGENTS.md](../../AGENTS.md) and
both run the hooks in [scripts/agent-hooks/lib.sh](../../scripts/agent-hooks/lib.sh) and its
siblings.

## Rules

### The layers

| Layer | Mechanism | Trigger | Effect |
| --- | --- | --- | --- |
| Commit gate | prek hooks, CI | commit, push, pull request | Blocks |
| Permission list | `permissions.deny` and `ask` | Before a tool call, static patterns | Blocks |
| PreToolUse | Hook script | Before a tool call, reads the arguments | Blocks |
| PostToolUse | Hook script | After a file is written | Reports at once |
| Stop | Hook script | When the turn tries to end | Blocks |
| Instructions | [AGENTS.md](../../AGENTS.md) | Always | None |

### One rule, one owner

A rule that a commit-time checker already owns is never restated in a hook. The hook calls that
same checker. [scripts/agent-hooks/post-tool-use.sh](../../scripts/agent-hooks/post-tool-use.sh)
holds no rule of its own: it maps a file extension to a script under `tests` and runs it. What
it changes is the trigger, not the rule. A rule defined in two places drifts the moment one of
them is edited, and nothing reports the disagreement.

[tests/check-hooks.sh](../../tests/check-hooks.sh) fails when that script calls anything outside
`tests`.

### What the hooks own

These rules exist nowhere else, because a diff does not record them.

| Rule | Hook | Stated in |
| --- | --- | --- |
| Search with `rg`, `fd`, and `ast-grep` rather than recursive `grep` and `find` | PreToolUse | [AGENTS.md](../../AGENTS.md) |
| No `--no-verify`, and no `git commit -n` | PreToolUse | [Commit Convention](commit-convention.md) |
| No direct push to the default branch | PreToolUse | [Commit Convention](commit-convention.md) |
| No `--force` push. `--force-with-lease` is allowed | PreToolUse | [Review Feedback](review-feedback.md) |
| Only `uv` manages the Python environment | PreToolUse | [Python](python.md) |
| No command prints the contents of the environment file | PreToolUse | [Shell](shell.md) |
| No tool writes `last_reviewed` | PreToolUse | [Documentation](documentation.md) |
| No hand edit of [docs/generated](../generated/index.md), of a document declaring `edit_policy: generated`, or of the generated index block in [AGENTS.md](../../AGENTS.md) | PreToolUse | [Documentation](documentation.md) |
| Notation rules apply to an answer written in chat | Stop | [Writing Style](writing-style.md) |
| `just verify` passes before the work is called done | Stop | [AGENTS.md](../../AGENTS.md) |

The last two need the harness because the artifact is not a file. Vale reads Markdown and never
sees a chat answer, and no checker can observe that a person considered the work finished.

### One hook script, two agents

Claude Code and Codex take the same hook events, the same JSON on standard input, and the same
exit code 2 to block. They differ in the name of the tool that writes a file: `Edit` and `Write`
against `apply_patch`. [scripts/agent-hooks/lib.sh](../../scripts/agent-hooks/lib.sh) absorbs
that difference, so a rule is written once.

| Concern | Claude Code | Codex |
| --- | --- | --- |
| Configuration | [.claude/settings.json](../../.claude/settings.json) | [.codex/hooks.json](../../.codex/hooks.json) |
| File writing tool | `Edit`, `Write`, `MultiEdit`, `NotebookEdit` | `apply_patch` |
| Static permission list | `permissions.allow`, `deny`, `ask` | Not available. The PreToolUse hook carries it |

Both configuration files are checked against each other. A hook wired on one side and not the
other means two agents follow two rulesets while every check stays green, so
[tests/check-hooks.sh](../../tests/check-hooks.sh) compares the event and script pairs and fails
when they differ.

### A false positive turns the harness off

A hook that blocks a correct command teaches everyone to switch hooks off, and that removes
every rule at once, not the one that misfired. It is the failure mode `--no-verify` already has,
described in [Commit Convention](commit-convention.md).

So every rule above is written narrow.

- Recursive search is blocked. A `grep` that filters the output of another command is not
- `--force` is blocked. `--force-with-lease` is not
- `pip` is blocked. `uv pip` is not
- A line that the edit adds is examined. A line the file already held is not

When a rule cannot be stated narrowly enough to avoid a false positive, it does not become a
hook. It stays in [AGENTS.md](../../AGENTS.md) as an instruction.

### Missing tools

The hooks read their input with `jq`. Where `jq` is absent the hook allows the call and does
nothing, the same bargain the commitlint step takes in
[tests/check-commit-msg.sh](../../tests/check-commit-msg.sh). A hook that always runs and a hook
that always works are different things, and the difference shows on a machine that skipped
`just bootstrap`.

### What stays unenforced

Written down, binding, and checked by people only. Each fails the narrowness test above.

- The review order and the severity markers in [Code Review](code-review.md) and
  [Review Feedback](review-feedback.md)
- Asking the author before changing their code
- Testing behavior rather than implementation, and the mocking boundary, in [Testing](testing.md)
- A comment that explains why rather than what, and one function doing one thing
- Looking up the current version of a dependency rather than recalling one
- Whether a pull request section says something real. Its presence is checked by
  [scripts/check_pr_metadata.py](../../scripts/check_pr_metadata.py)

### Hooks run arbitrary commands

A hook is a command that runs on the machine of whoever cloned the repository, before the tool
call it guards. Treat a change to the two configuration files or to
[scripts/agent-hooks/lib.sh](../../scripts/agent-hooks/lib.sh) and its siblings as a change to
executable code, and review it that way. The reporting path for anything worse is in
[SECURITY.md](../../SECURITY.md).

## Checklist

- Does the new rule already have a checker? Then call it from the hook rather than restating it
- Can the rule be stated so that no correct command matches it?
- Is the rule wired for both agents rather than one?
- Does the block message name what was blocked and what to do instead?
- Does `just hooks` pass?

## Related documents

- [Commit Convention](commit-convention.md)
- [Documentation](documentation.md)
- [Writing Style](writing-style.md)
- [Python](python.md)
- [Shell](shell.md)
