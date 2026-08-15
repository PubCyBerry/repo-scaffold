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
---

# Code Review

## Purpose

Make review findings concrete enough to act on without a follow-up conversation.

## Scope

Every review of a diff, branch, or pull request in this repository, whether performed by a person or an agent.

## Rules

### Sync before reviewing

Fetch the latest remote state first.

```bash
git fetch origin
```

Reviewing a stale base produces findings for code that is already gone.

### Review in order

Evaluate in this order and stop escalating once a level fails badly enough to require rework:

1. **Architecture** — is this the right shape? A correct implementation of the wrong design is still wrong
2. **Code quality** — limits, naming, error handling, per [Code quality](docs/standards/code-quality.md)
3. **Tests** — do they test behavior, and do they cover the error paths, per [Testing](docs/standards/testing.md)
4. **Performance** — only after the first three hold

Reporting a variable name before reporting a broken abstraction wastes the author's attention.

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

Review prose follows [Writing Style](docs/standards/writing-style.md): plain, factual, no praise padding.

## Checklist

- Was `git fetch origin` run before the review?
- Does every finding carry a `file:line` reference?
- Are architecture problems reported before naming problems?
- Where the fix is not obvious, are options with tradeoffs presented and one recommended?
- Was the author asked before any change was applied?

## Related documents

- [Code quality](docs/standards/code-quality.md)
- [Testing](docs/standards/testing.md)
- [Commit convention](docs/standards/commit-convention.md)
- [Writing Style](docs/standards/writing-style.md)
