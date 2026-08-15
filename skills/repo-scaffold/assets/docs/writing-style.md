---
id: standard-writing-style
title: Writing Style
type: standard
status: active
summary: Language, tone, and notation rules for every written artifact
scope:
  - "**"
read_when:
  - Writing a document, report, or summary
  - Writing a commit message or a pull request description
  - Writing or reviewing a code comment
  - Naming a heading, table header, status, or option
  - Choosing between an em dash, a colon, and a comma
related:
  - standard-documentation
  - standard-commit-convention
  - standard-code-review
---

# Writing Style

## Purpose

Prose written in this repository reads as one voice regardless of who or what produced it.

This document covers language, tone, and notation. Document metadata and file layout are in [Documentation](docs/standards/documentation.md).

## Scope

Every written artifact, not only files under [docs/](docs/index.md):

- Documents under [docs/](docs/index.md) and the repository root files
- Code comments and docstrings
- Commit messages and pull request descriptions
- Reports, analyses, and summaries produced by an agent, including chat answers

Code and command output are reproduced verbatim and are never rewritten to match this style.

## Language

- **Everything under [docs/](docs/index.md) is written in English.** No exceptions.
- Technical terms, identifiers, commands, and paths keep their original form. They are not translated.
- In front matter, keys are English. Fixed-vocabulary values (`id`, `type`, `status`) are English. Free-text values follow the language of the document.
- Repository root files, code comments, and commit messages follow the team's working language. The English rule covers [docs/](docs/index.md) only.

## Tone

Plain and factual. Describe what a change does, not how much it matters.

A bug fix is a bug fix, not a stability improvement. Do not reach for these words:

```
critical, crucial, essential, significant, comprehensive, robust, elegant, seamless, powerful
```

- No marketing adjectives, no superlatives, no praise
- No hedging that carries no information: "basically", "just", "simply", "actually"
- State a limitation directly instead of softening it

Headings, table headers, list labels, status names, and options are short noun phrases, not sentences.

## Notation

Do not use these characters. Use the replacement instead.

| Target | Example | Replacement |
| --- | --- | --- |
| Interpunct, three or more items | `deploy·env·log` | `deploy, env, log` |
| Interpunct, two items | `build·start` | `build and start` |
| Em dash or en dash inside a sentence | `Warning — shared resource` | `Warning: shared resource` |
| Double hyphen inside a sentence | `Warning -- shared resource` | `Warning: shared resource` |
| Ditto mark | `〃` | Repeat the value |

Two exceptions:

- Command-line option prefixes such as `--no-cache`
- Code inside a code block

File sizes are written in MB, GB, or GiB. Raw byte counts are not used.

Dates are absolute: `2026-01-01`. Never "last week", "recently", or "currently".

## Checklist

- Is every document under [docs/](docs/index.md) written in English?
- Are headings and labels noun phrases rather than sentences?
- Does any sentence contain an em dash, an en dash, a double hyphen, or an interpunct?
- Are there marketing adjectives or superlatives that carry no information?
- Are all dates absolute?

## Related documents

- [Documentation](docs/standards/documentation.md)
- [Commit convention](docs/standards/commit-convention.md)
- [Code review](docs/standards/code-review.md)
