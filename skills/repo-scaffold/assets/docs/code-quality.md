---
id: standard-code-quality
title: Code Quality
type: standard
status: active
summary: Simplicity, size and complexity limits, zero warnings policy, comments, error handling
scope:
  - "**"
read_when:
  - Writing or refactoring a function
  - Choosing between two implementations that both work
  - Deciding whether to add a comment
  - Handling or reporting an error
  - A linter, type checker, or compiler emits a warning
related:
  - standard-testing
  - standard-python
  - standard-code-review
  - standard-shell
---

# Code Quality

## Purpose

State what readable code looks like here, and set the limits that decide when code is too
large, too complex, or too quiet about failure. The limits are hard limits, not targets:
crossing one is a review finding, not a discussion.

## Scope

All source code in this repository, in every language. Language-specific rules live in their
own standard, such as [Shell](shell.md).

## Rules

### Simplicity

Write the plainest code that meets the requirement, and write it to be read. The next reader
is a person or an agent that has none of the context you have right now.

1. Prefer the ordinary construct over the clever one. A reader should not have to run the
   code in their head to know what it does
2. One function does one thing. A name that needs "and" in it describes two functions
3. Name a thing for what it holds or what it does, not for its type or its position
4. Extract an abstraction from repetition that already happened, never from repetition you
   expect
5. Delete dead code instead of commenting it out or hiding it behind a flag

Short is not the same as readable. Dropping a name, a guard clause, or a blank line saves a
line and costs a reading. Removing a branch nobody takes saves both.

The hard limits below are a ceiling, not a target. Code that sits at the ceiling and is hard
to follow is still a review finding.

### Hard limits

1. At most 100 lines per function, cyclomatic complexity at most 8
2. At most 5 positional parameters
3. Line length 100 characters
4. Absolute imports only. No relative (`..`) import paths
5. Google-style docstrings on non-trivial public APIs

A function that exceeds a limit is split, not annotated with an exemption.

### Typed interfaces

Where the language has a static type system, use it.

1. Every public function signature carries parameter and return types
2. A type checker runs in the pipeline, and its output falls under the zero warnings rule
3. Data entering the process from outside is validated at runtime before it is used

The first two are checked by a tool. The third is not, and it decides whether the other two
mean anything. A value read from a file, a request, or an environment variable has the type
somebody wrote down, not the type it turned out to have. Parsing it into a validated
structure at the edge is what makes every annotation behind that edge true.

Which type checker and which validator a language uses is decided in that language's own
standard, such as [Python](python.md).

### Zero warnings

Fix every warning from every tool: linters, type checkers, compilers, and test runners.

When a warning genuinely cannot be fixed, add an inline ignore with a comment giving the
reason. A bare ignore directive with no justification is a review finding.

Clean output is the baseline, not the goal. Warnings that are left alone train everyone to
stop reading the output.

### Comments

Code is self-documenting. If a comment is needed to explain **what** the code does, refactor
the code instead. A comment explains **why**: the constraint, the tradeoff, or the
non-obvious reason.

No commented-out code. Delete it. Version control already keeps it.

Comment prose follows [Writing Style](writing-style.md).

### Error handling

- Fail fast with a clear, actionable message
- Never swallow an exception silently
- Include context: which operation, which input, and the suggested fix

An error message is read by whoever has to act on it. Naming the failing operation and the
offending input is what makes it actionable.

### Dependencies

When adding a dependency, a CI action, or a tool version, look up the current stable version.
Never write one from memory unless the version was given to you.

## Checklist

- Can a reader tell what the code does without running it in their head?
- Does any function do two things that its name joins with "and"?
- Is any abstraction there for a repetition that has not happened yet?
- Is every function within 100 lines and complexity 8?
- Does any function take more than 5 positional parameters?
- Are all imports absolute?
- Do public APIs that are not trivial carry a Google-style docstring?
- Does every public function signature carry parameter and return types?
- Is data from outside the process validated before use rather than assumed?
- Is the output of every linter and type checker clean?
- Does every inline ignore carry a justification?
- Is there commented-out code left in the diff?
- Does every error path produce a message naming the operation and the input?

## Related documents

- [Python](python.md)
- [Testing](testing.md)
- [Code review](code-review.md)
- [Shell](shell.md)
- [Writing Style](writing-style.md)
