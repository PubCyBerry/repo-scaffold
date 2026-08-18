---
id: standard-writing-style
title: Writing Style
type: standard
status: active
summary: Language, tone, stateless phrasing, and notation rules for every written artifact
scope:
  - "**"
read_when:
  - Writing a document, report, or summary
  - Writing a commit message or a pull request description
  - Writing or reviewing a code comment
  - Explaining why something is the way it is
  - Naming a heading, table header, status, or option
  - Choosing between an em dash, a colon, and a comma
sources:
  - tests/check-prose.sh
  - tests/check-commit-msg.sh
  - .vale.ini
  - styles
related:
  - standard-documentation
  - standard-commit-convention
  - standard-code-review
---

# Writing Style

## Purpose

Prose written in this repository reads as one voice regardless of who or what produced it.

This document covers language, tone, stateless phrasing, and notation. Document metadata and
file layout are in [Documentation](documentation.md).

## Scope

Every written artifact, not only files under [docs/](../index.md):

- Documents under [docs/](../index.md) and the repository root files
- Code comments and docstrings
- Commit messages and pull request descriptions
- Reports, analyses, and summaries produced by an agent, including chat answers

Code and command output are reproduced verbatim and are never rewritten to match this style.

## Language

- **Everything under [docs/](../index.md) is written in English.** No exceptions.
- Technical terms, identifiers, commands, and paths keep their original form. They are not translated.
- In front matter, keys are English. Fixed-vocabulary values (`id`, `type`, `status`) are
  English. Free-text values follow the language of the document.
- Repository root files, code comments, and commit messages follow the team's working
  language. The English rule covers [docs/](../index.md) only.

## Tone

Plain and factual. Describe what a change does, not how much it matters.

A bug fix is a bug fix, not a stability improvement. Do not reach for these words:

```text
critical, crucial, essential, significant, comprehensive, robust, elegant, seamless, powerful
```

- No marketing adjectives, no superlatives, no praise
- No hedging that carries no information: "basically", "just", "simply", "actually"
- State a limitation directly instead of softening it

Headings, table headers, list labels, status names, and options are short noun phrases, not sentences.

## Stateless prose

Every document, comment, and instruction describes the repository as it is now. It never
describes the change that produced it.

A reader arrives with no memory of the previous version, and that reader is usually an agent
with no way to check. Prose that leans on the change history sends them looking for a state
that is not in the working tree.

| Do not write | Write instead |
| --- | --- |
| The hook now runs at pre-push | The hook runs at pre-push |
| Renamed from `check-lint.sh` | (nothing; the name is the only name) |
| We used to call `npx`, so this calls the binary directly | `npx` resolves the version at run time, so this calls the binary directly |
| Added in this pull request | (nothing) |
| The old ruleset locked out solo owners | A ruleset that requires one approval locks out a solo owner |

The rule covers three things a reader cannot verify: what a file was called before, what the
behavior used to be, and when a line was added. The reason behind a decision is not history
and belongs in the text, stated as a fact about the present.

Two places record change on purpose, and they are exempt: the commit message, whose subject is
the change, and an architecture decision record, whose `status` and `supersedes` fields are the
mechanism for retiring a decision.

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

## What is checked mechanically

`just prose` runs Vale over every tracked Markdown file. Vale holds two jobs here and no
others: it is a **prose policy linter** and a **terminology linter**. It is not a grammar
checker, not a writing-quality evaluator, and not a spell checker. Korean spelling in
particular cannot be checked with Vale, so the Korean rules below are curated blacklists, not
a dictionary.

Rule definitions live in the `styles` directory, one file per rule, grouped into `Project`
(character rules, script independent), `English`, and `Korean`. Each rule is derived from a
rule stated above; none is invented.

| Rule above | Vale rule | Level |
| --- | --- | --- |
| Interpunct, em dash, en dash, double hyphen, ditto mark | `Project.Punctuation` | error |
| File sizes in MB, GB, GiB | `Project.ByteCounts` | error |
| The nine marketing adjectives | `English.Tone`, `Korean.Tone` | error |
| The four empty hedges | `English.Hedges`, `Korean.RedundantExpressions` | warning |
| Absolute dates | `English.Dates`, `Korean.Tone` | error |
| One sentence-ending style per repository | `Korean.SentenceEndings` | error |
| Terms, loanwords, product names | `Korean.Terminology`, `Korean.ForeignWords`, `Korean.ProductNames` | error |
| Full-width punctuation and space before a mark | `Korean.Punctuation` | error |
| Spacing and redundant collocations | `Korean.SpacingPatterns` | warning |

The English rules are applied to `docs` only and the Korean rules to the repository root
files only. Applying both everywhere would flag the command runner `just` as an empty hedge on
every commit.

Only `error` fails a commit. A `warning` is reported and does not block, because every rule at
that level has a legitimate use that a regular expression cannot tell apart. A hook that
produces false positives teaches people to pass `--no-verify`, which turns off every hook at
once.

General Korean spacing and redundancy detection needs a morphological analyzer and is not
expressible as a regular expression, so it is not attempted. `그중` and `그 중`, `안된다` and
`안 된다`, `한번` and `한 번` are each correct in some contexts and wrong in others.

Code spans and code blocks are skipped. Commands and tool output are reproduced verbatim.

A commit message is inside the scope above and outside Vale's reach, because Vale reads
Markdown. The Notation table is applied to the commit subject instead by
[tests/check-commit-msg.sh](../../tests/check-commit-msg.sh) at the `commit-msg` stage, from the
same five entries. The commit body is left to review; the reason is in
[Commit convention](commit-convention.md).

Everything else in this document is a policy for people. It is not enforced by a tool and is
still binding.

## Checklist

- Is every document under [docs/](../index.md) written in English?
- Are headings and labels noun phrases rather than sentences?
- Does any sentence contain an em dash, an en dash, a double hyphen, or an interpunct?
- Are there marketing adjectives or superlatives that carry no information?
- Are all dates absolute?
- Does any sentence describe a previous state, a rename, or the change itself?
- Does `just prose` pass?

## Related documents

- [Documentation](documentation.md)
- [Commit convention](commit-convention.md)
- [Code review](code-review.md)
