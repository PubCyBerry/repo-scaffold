---
id: standard-commit-convention
title: Commit Convention
type: standard
status: active
summary: Pre-commit gate, commit message format, branch policy, pull request description
scope:
  - "**"
read_when:
  - Writing a commit message
  - Preparing to commit or push a change
  - Opening a pull request or writing its description
  - Setting up hooks or a worktree for parallel work
related:
  - standard-code-review
  - standard-writing-style
  - standard-documentation
---

# Commit Convention

## Purpose

Keep history readable and keep broken work out of shared branches.

## Scope

Every commit, branch, and pull request in this repository.

## Rules

### Before committing

1. Re-read the diff for unnecessary complexity, redundant code, and unclear naming
2. Run the tests relevant to the change, not the full suite
3. Run the linters and the type checker, and fix everything before committing

Hooks run the repository's own checks; see [README.md](README.md) for what each hook covers.

### Commit messages

- Imperative mood
- Subject line at most 72 characters
- One logical change per commit

Write a body only when the reason is not obvious from the diff. The body explains why, never what.

### Branch and history policy

- Never push directly to the default branch. Use a feature branch and a pull request
- Never amend or rebase a commit that is already pushed to a shared branch
- Never commit secrets, API keys, or credentials. Use `.env` (ignored by `.gitignore`) and environment variables. Rules are in [SECURITY.md](SECURITY.md)

### Hooks

Install the hook runner once per clone. Without it, none of the checks run.

```bash
prek install
prek run --all-files
```

Keep hook repositories current on a cooldown so a freshly published release is not adopted the day it lands.

```bash
prek update --cooldown-days 7
```

### Worktrees

Parallel agents each work in their own git worktree. Never share a working directory between two agents running at the same time.

```bash
git worktree add ../repo-<branch> <branch>
```

Two agents in one directory overwrite each other's edits and stage each other's files.

### Pull requests

Describe what the code does now. Not discarded approaches, not prior iterations, not alternatives that were considered. Only what is in the diff.

Language is plain and factual, per [Writing Style](docs/standards/writing-style.md).

## Checklist

- Did the relevant tests, linters, and type checker pass before the commit?
- Is the subject line imperative and at most 72 characters?
- Does the commit contain exactly one logical change?
- Is the branch a feature branch rather than the default branch?
- Are there credentials, tokens, or `.env` contents in the diff?
- Does the pull request description cover only what the diff contains?

## Related documents

- [Code review](docs/standards/code-review.md)
- [Writing Style](docs/standards/writing-style.md)
- [Security](SECURITY.md)
