---
id: index-standards
title: Standards
type: index
status: active
summary: Rules that must be followed, by area
scope:
  - docs/standards/**
read_when:
  - Before writing code or documents
  - When a review needs a rule to cite
related:
  - index-docs
---

# Standards

## Purpose

Collect the rules whose violation is a review finding in this repository.

## Scope

Applies regardless of component or language. Rules that apply to a single product go into
that domain directory instead.

## Reading order

1. Open the document whose `scope` covers the file you are about to touch.
2. [Writing Style](writing-style.md) applies to everything written, including reports and
   commit messages. Read it once and keep it.
3. Open the rest on demand. Do not load all of them up front.

## Documents

| Document | Contents |
| --- | --- |
| [Documentation](documentation.md) | File naming, path notation, front matter, document structure |
| [Writing Style](writing-style.md) | Language, tone, notation, for every written artifact |
| [Code Quality](code-quality.md) | Size and complexity limits, zero warnings, comments, error handling |
| [Testing](testing.md) | Behavior over implementation, edge coverage, mocking boundaries |
| [Code Review](code-review.md) | Review order, finding format, options and recommendation |
| [Review Feedback](review-feedback.md) | Severity markers, GitHub review decisions, branch history |
| [Commit Convention](commit-convention.md) | Pre-commit gate, message format, branch policy, pull requests |
| [Shell](shell.md) | Strict mode, shellcheck and shfmt gates |
| [Python](python.md) | Ruff and mypy settings derived from code quality, test layout |
| [GitHub Actions](github-actions.md) | SHA pinning, least privilege, actionlint and zizmor gates |
| [Issue Lifecycle](issue-lifecycle.md) | Issue states, triage checklist, acceptance, stale handling |
| [Triage Labels](triage-labels.md) | Label axes, label meanings, the file that creates them |
| [Pull Request Lifecycle](pull-request-lifecycle.md) | Description contract, readiness gate, merge queue |
| [GitHub Enforcement](github-enforcement.md) | What GitHub enforces, what CI enforces, what people do |

## Related documents

- [Document index](../index.md)
