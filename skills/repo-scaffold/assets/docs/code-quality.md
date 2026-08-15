---
id: standard-code-quality
title: Code Quality
type: standard
status: active
summary: Size and complexity limits, zero warnings policy, comments, error handling
scope:
  - "**"
read_when:
  - Writing or refactoring a function
  - Deciding whether to add a comment
  - Handling or reporting an error
  - A linter, type checker, or compiler emits a warning
related:
  - standard-testing
  - standard-code-review
  - standard-shell
---

# Code Quality

## Purpose

Set the limits that decide when code is too large, too complex, or too quiet about failure. These are hard limits, not targets: crossing one is a review finding, not a discussion.

## Scope

All source code in this repository, in every language. Language-specific rules live in their own standard, such as [Shell](docs/standards/shell.md).

## Rules

### Hard limits

1. At most 100 lines per function, cyclomatic complexity at most 8
2. At most 5 positional parameters
3. Line length 100 characters
4. Absolute imports only. No relative (`..`) import paths
5. Google-style docstrings on non-trivial public APIs

A function that exceeds a limit is split, not annotated with an exemption.

### Zero warnings

Fix every warning from every tool: linters, type checkers, compilers, and test runners.

When a warning genuinely cannot be fixed, add an inline ignore with a comment giving the reason. A bare ignore directive with no justification is a review finding.

Clean output is the baseline, not the goal. Warnings that are left alone train everyone to stop reading the output.

### Comments

Code is self-documenting. If a comment is needed to explain **what** the code does, refactor the code instead. A comment explains **why**: the constraint, the tradeoff, or the non-obvious reason.

No commented-out code. Delete it. Version control already keeps it.

Comment prose follows [Writing Style](docs/standards/writing-style.md).

### Error handling

- Fail fast with a clear, actionable message
- Never swallow an exception silently
- Include context: which operation, which input, and the suggested fix

An error message is read by whoever has to act on it. Naming the failing operation and the offending input is what makes it actionable.

### Dependencies

When adding a dependency, a CI action, or a tool version, look up the current stable version. Never write one from memory unless the version was given to you.

## Checklist

- Is every function within 100 lines and complexity 8?
- Does any function take more than 5 positional parameters?
- Are all imports absolute?
- Do public APIs that are not trivial carry a Google-style docstring?
- Is the output of every linter and type checker clean?
- Does every inline ignore carry a justification?
- Is there commented-out code left in the diff?
- Does every error path produce a message naming the operation and the input?

## Related documents

- [Testing](docs/standards/testing.md)
- [Code review](docs/standards/code-review.md)
- [Shell](docs/standards/shell.md)
- [Writing Style](docs/standards/writing-style.md)
