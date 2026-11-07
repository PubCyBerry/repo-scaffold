---
id: decision-0008-enforce-agent-behaviour-rules-in-harness-hooks
title: 0008. Enforce agent behaviour rules in harness hooks
type: decision
status: accepted
summary: Why rules that leave no trace in a diff moved into Claude Code and Codex hooks
scope:
  - scripts/agent-hooks
  - .claude/settings.json
  - .codex/hooks.json
read_when:
  - Before adding a rule that a coding agent has to follow
  - When deciding whether a check belongs in a commit hook or in the harness
related:
  - index-adr
  - standard-agent-harness
  - decision-0007-give-each-documentation-rule-one-checker
sources:
  - scripts/agent-hooks
  - tests/check-hooks.sh
---

# 0008. Enforce agent behaviour rules in harness hooks

## Context and problem statement

Every rule in this repository was enforced at one moment: the commit. prek hooks read staged
files, and continuous integration reads the branch. That covers rules about files and covers
nothing else.

Three groups of rules fell outside it.

The first is tool choice. [AGENTS.md](../../../AGENTS.md) says to search with `rg`, `fd`, and
`ast-grep` rather than with recursive `grep` and `find`, and [Python](../../standards/python.md)
says `uv` owns the environment. Which command an agent ran leaves no trace in the diff, so no
checker could see either rule. They were instructions with no consequence.

The second is the gate itself. `--no-verify` turns off every commit hook at once, and a commit
that used it looks exactly like a commit that passed. The check that would catch it is the
check it disabled.

The third is artifacts that never become files. [Writing Style](../../standards/writing-style.md)
puts reports, summaries, and chat answers in its scope, and Vale reads Markdown. That scope had
zero coverage. The same holds for the Definition of Done in [AGENTS.md](../../../AGENTS.md): no
file records that `just verify` was run and passed.

Meanwhile both agents used here, Claude Code and Codex, grew the same lifecycle hook interface:
the same events, the same JSON on standard input, the same exit code 2 to block a tool call.

## Considered options

| Option | Why not |
| --- | --- |
| Leave the rules as instructions and rely on the agent following them | That is the state that produced the gap. An instruction that nothing checks is a preference |
| Push everything into commit hooks | A commit hook cannot see a command that was never committed, nor an answer that was never written to a file |
| Write hooks for Claude Code only | Codex reads the same repository under the same rules. A rule enforced for one agent and not the other is a rule with a hole in it |
| Reimplement the file rules in hook scripts so the harness is self-contained | Two owners for one rule, which is the defect [0007](0007-give-each-documentation-rule-one-checker.md) removed |
| Add a hook layer that owns behaviour rules only, wired for both agents | Chosen |

## Decision outcome

The harness owns rules whose subject is the agent's behaviour. The commit gate keeps every rule
whose subject is a file.

The split is a question, not a preference: **does the rule leave a trace in the diff**. If it
does, a commit-time checker already owns it and the harness must not restate it. If it does not,
the harness is the only place the rule can live.

The hook layer is three scripts sharing one normalization library,
[scripts/agent-hooks/lib.sh](../../../scripts/agent-hooks/lib.sh), wired identically into
[.claude/settings.json](../../../.claude/settings.json) and
[.codex/hooks.json](../../../.codex/hooks.json).

- PreToolUse blocks a tool call whose arguments break a behaviour rule
- PostToolUse runs the existing checker for the file that was just written, and defines nothing
  of its own
- Stop checks the notation rules against this turn's answer, and refuses to end a turn where
  files changed and `just verify` never passed

Two properties keep the layer from decaying.

The two configuration files are compared against each other by
[tests/check-hooks.sh](../../../tests/check-hooks.sh). Wiring a hook for one agent and not the
other produces two rulesets and a green build, which is the same failure shape that
[tests/check-tool-versions.sh](../../../tests/check-tool-versions.sh) was written for.

Every rule is written narrow enough that no correct command matches it. Recursive `grep` is
blocked and a `grep` filtering a pipe is not. `--force` is blocked and `--force-with-lease` is
not. `pip` is blocked and `uv pip` is not. A hook that blocks correct work gets switched off,
and switching it off removes every rule in it rather than the one that misfired. The rule that
cannot be written narrowly stays an instruction in [AGENTS.md](../../../AGENTS.md), listed as
unenforced in [Agent Harness](../../standards/agent-harness.md).

## Consequences

What this makes easier:

- A rule about behaviour now has a consequence instead of a hope
- A violation of a file rule is reported when the file is written rather than at the commit
- The unenforced list is written down, so nobody assumes a rule is checked because it is documented

What this makes harder:

- The repository now ships executable code that runs on a contributor's machine before a tool
  call. That is reviewed as code, and [SECURITY.md](../../../SECURITY.md) says so
- The hooks need `jq`. Without it they allow every call and check nothing, which is the same
  bargain the commitlint step already takes
- A rule now has two possible homes, and picking the wrong one duplicates an owner. The question
  above is the test, and [tests/check-hooks.sh](../../../tests/check-hooks.sh) enforces the half
  of it that can be mechanized

## Related documents

- [Decision Records](index.md)
- [Agent Harness](../../standards/agent-harness.md)
- [0007. Give each documentation rule one checker](0007-give-each-documentation-rule-one-checker.md)
