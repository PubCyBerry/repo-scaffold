---
id: standard-code-review
title: Code Review
type: standard
status: active
summary: Review order, finding format, options and recommendation before changing anything
scope:
  - "**"
read_when:
  - Reviewing a diff, a branch, or a pull request
  - Reporting a problem found in someone else's change
  - Deciding whether a finding is worth raising
related:
  - standard-code-quality
  - standard-testing
  - standard-commit-convention
  - standard-review-feedback
---

# Code Review

## Purpose

Make review findings concrete enough to act on without a follow-up conversation.

## Scope

Every review of a diff, branch, or pull request in this repository, whether performed by a
person or an agent.

How a finding is marked, what it does to the GitHub review decision, and what the author may do
to the branch afterwards are in [Review Feedback](review-feedback.md). This document covers what
to look at and in what order.

## Rules

### Sync before reviewing

Fetch the latest remote state first.

```bash
git fetch origin
```

Reviewing a stale base produces findings for code that is already gone.

### Review in order

Work down this list and stop escalating once a level fails badly enough to require rework.

| Order | Area | The question |
| --- | --- | --- |
| 1 | Intent | Does the change actually solve the linked problem? |
| 2 | Scope | Is unrelated work mixed in? |
| 3 | Correctness | Are the normal, edge, failure, and concurrency paths right? |
| 4 | Architecture | Are boundaries, abstractions, ownership, and dependencies appropriate? |
| 5 | Tests | Would they catch the regression this change could introduce? |
| 6 | Security | Are trust boundaries, inputs, permissions, secrets, dependencies handled? |
| 7 | Compatibility | Does it affect an API, config, schema, stored data, or environment? |
| 8 | Maintainability | Can the next maintainer understand and safely change this? |
| 9 | Performance | Are the hot paths, resource use, and scaling characteristics acceptable? |
| 10 | Documentation | Do documents, examples, comments, and runbooks match the behavior? |

Reporting a variable name before reporting a broken abstraction wastes the author's attention.
A correct implementation of the wrong design is still wrong, which is why intent and scope come
before correctness rather than after it.

Deterministic tooling already owns formatting, linting, types, schemas, and basic test failures.
Do not spend review attention on them unless a tool failed to cover the case.

### Report each finding the same way

For every finding:

1. Describe it concretely, with a `file:line` reference
2. When the fix is not obvious, present the options with their tradeoffs
3. Recommend one
4. Ask before changing anything

A finding with no location is not a finding. A recommendation with no tradeoff is an assertion.

### What not to raise

- Formatting that a formatter already owns. Fix the formatter configuration instead
- Style preferences with no rule behind them. If it matters, write it into a standard first
- Restating a finding that another comment already covers

Review prose follows [Writing Style](writing-style.md): plain, factual, no praise padding.

## Checklist

- Was `git fetch origin` run before the review?
- Was the list walked in order, starting from intent rather than from naming?
- Does every finding carry a `file:line` reference?
- Where the fix is not obvious, are options with tradeoffs presented and one recommended?
- Does every finding carry a severity marker, per [Review Feedback](review-feedback.md)?
- Was the author asked before any change was applied?

## Related documents

- [Review Feedback](review-feedback.md)
- [Code quality](code-quality.md)
- [Testing](testing.md)
- [Commit convention](commit-convention.md)
- [Writing Style](writing-style.md)
