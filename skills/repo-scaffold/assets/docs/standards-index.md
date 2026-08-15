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

Applies regardless of component or language. Rules that apply to a single product go into that domain directory instead.

## Reading order

1. Open the document whose `scope` covers the file you are about to touch.
2. [Writing Style](docs/standards/writing-style.md) applies to everything written, including reports and commit messages. Read it once and keep it.
3. Open the rest on demand. Do not load all of them up front.

## Documents

| Document | Contents |
| --- | --- |
| [Documentation](docs/standards/documentation.md) | File naming, path notation, front matter, document structure |
| [Writing Style](docs/standards/writing-style.md) | Language, tone, notation, for every written artifact |
| [Code Quality](docs/standards/code-quality.md) | Size and complexity limits, zero warnings, comments, error handling |
| [Testing](docs/standards/testing.md) | Behavior over implementation, edge coverage, mocking boundaries |
| [Code Review](docs/standards/code-review.md) | Review order, finding format, options and recommendation |
| [Commit Convention](docs/standards/commit-convention.md) | Pre-commit gate, message format, branch policy, pull requests |
| [Shell](docs/standards/shell.md) | Strict mode, shellcheck and shfmt gates |
| [GitHub Actions](docs/standards/github-actions.md) | SHA pinning, least privilege, actionlint and zizmor gates |

## Related documents

- [Document index](docs/index.md)
