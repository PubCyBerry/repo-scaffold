---
type: Standard
title: Troubleshooting
description: Troubleshooting knowledge lives in the remote repository's issues; how to search, record, and close it there.
tags: [troubleshooting, issues]
---

# Troubleshooting

Troubleshooting records are issues in the remote repository (GitHub, GitLab, Gitea, or another
forge), not files in `docs/`. An issue keeps the error text searchable, holds the investigation
in its comments, links to the commits and pull requests that fixed the problem, and shows by
its open or closed state whether the problem is solved.

## Search before you debug

Search open **and** closed issues for the distinctive part of the error message.

| Forge | Command |
| --- | --- |
| GitHub | `gh issue list --state all --search "<error text>"` |
| GitLab | `glab issue list --all --search "<error text>"` |
| Gitea | `tea issues list --state all --keyword "<error text>"` |

If a closed issue matches, apply its resolution. If the resolution no longer works, reopen the
issue or comment on it with what changed.

## When to open one

Open an issue with the troubleshooting template when a problem:

- took real effort to diagnose, or
- is likely to happen again, as setup, environment, CI, dependency, and tooling problems are.

A defect in the product's own code is a bug report, not a troubleshooting record.

## What to record

- **Symptom**: the exact error text, pasted as text. Searchers match on it.
- **Environment**: operating system, versions, and anything else that could matter.
- **Steps to reproduce**
- **What was tried**: dead ends included, so nobody repeats them.
- **Cause** and **Resolution**: fill these in before closing.

Remove secrets and personal data before posting logs.

Close the issue once the resolution is written down. If the fix needs a code change, link the
pull request with a closing keyword, such as `Closes #123`.

## The label

The template applies the `troubleshooting` label. Create it once per repository; forges
drop labels that do not exist.

| Forge | Command |
| --- | --- |
| GitHub | `gh label create troubleshooting` |
| GitLab | `glab label create --name troubleshooting` |
| Gitea | `tea labels create --name troubleshooting --color "#d4c5f9"` |

## From issue to document

When a resolution turns into a standing rule, such as a required setup step or version,
write the rule into `docs/` and list the issue URL in that document's `sources`.
