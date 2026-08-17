---
id: standard-commit-convention
title: Commit Convention
type: standard
status: active
summary: Conventional Commits format, pre-commit gate, branch policy, pull request description
scope:
  - "**"
read_when:
  - Writing a commit message
  - Preparing to commit or push a change
  - Opening a pull request or writing its description
  - Setting up hooks or a worktree for parallel work
sources:
  - commitlint.config.mjs
  - tests/check-commit-msg.sh
  - .pre-commit-config.yaml
related:
  - standard-code-review
  - standard-writing-style
  - standard-documentation
---

# Commit Convention

## Purpose

Keep history readable, keep broken work out of shared branches, and keep the log in a shape a
tool can read.

## Scope

Every commit, branch, and pull request in this repository.

## Rules

### Before committing

1. Re-read the diff for unnecessary complexity, redundant code, and unclear naming
2. Run the tests relevant to the change, not the full suite
3. Run the linters and the type checker, and fix everything before committing

`just verify` runs all of it. Hooks call the same scripts; see [README.md](../../README.md) for
what runs at which stage.

### Commit message format

Every commit message follows [Conventional Commits](https://www.conventionalcommits.org).

```text
<type>(<scope>)!: <subject>

<body>

<footer>
```

Only the type, the colon, and the subject are required.

| Part | Rule |
| --- | --- |
| Type | Lowercase. One of the eleven below |
| Scope | Optional. The area touched, in parentheses: `feat(docs): ...` |
| `!` | Optional. Marks a breaking change. Pair it with a `BREAKING CHANGE:` footer |
| Subject | **Starts lowercase.** Imperative mood. No trailing period |
| Header | The whole first line, at most 100 characters |
| Body | Optional. Separated by a blank line. Each line at most 100 characters |
| Footer | Optional. `BREAKING CHANGE: <reason>` or an issue reference |

The eleven types:

| Type | Use |
| --- | --- |
| `feat` | A capability that did not exist before |
| `fix` | A defect repair |
| `docs` | Documentation only |
| `refactor` | Behaviour unchanged, structure changed |
| `perf` | A change made for speed or memory |
| `test` | Tests only |
| `build` | Build files, dependencies, packaging |
| `ci` | Continuous integration configuration |
| `chore` | Housekeeping that fits none of the above |
| `style` | Formatting with no change in behaviour |
| `revert` | Undoes an earlier commit |

Write a body only when the reason is not obvious from the diff. The body explains why, never
what. One logical change per commit.

```text
feat(docs): add a document index generator

The index went stale every time someone forgot to update it by hand, and a stale
index is worse than none because an agent reads it as fact.
```

### Why the subject starts lowercase

The `subject-case` rule rejects a subject whose first token is uppercase ASCII, so
`add a generator` passes and `Add a generator` does not. A subject that opens with a product
name or an acronym is rejected for the same reason. Reword it so the first word is lowercase.
The name can sit anywhere else in the line.

The rule is kept as the tool ships it. A log where every entry starts the same way is faster to
scan, and the alternative is one more line of local configuration that nobody revisits. The
price is the occasional reworded subject.

### Length

The header is at most 100 characters and each body line is at most 100 characters. That is the
same limit as the editor and formatter settings in `.editorconfig`, so there is one number to
remember rather than three.

### What a tool checks and what a person checks

Two checkers read a commit message. Neither replaces the other.

| Rule | Checked by |
| --- | --- |
| Type, scope, case, header length, body line length | commitlint, via [commitlint.config.mjs](../../commitlint.config.mjs) |
| Banned characters in the subject | [tests/check-commit-msg.sh](../../tests/check-commit-msg.sh) |
| Banned characters in the body | A person, at review |
| Imperative mood, one logical change, a body that explains why | A person, at review |

Both run at the `commit-msg` stage, one message at a time, and again in CI across the whole
branch. The CI pass is not a duplicate of the hook. `prek run --all-files` runs `pre-commit`
stage hooks and never reaches this one, `--no-verify` turns the local hook off outright, and a
clone without `node_modules` reports SKIP for the format check. The `quality` workflow calls
`just commit-range "<base>..HEAD"` on every pull request, which walks the commits the branch
adds and applies both checks to each one. That job checks out the full history, because a
shallow clone cannot resolve the range and would report an empty one.

[Writing Style](writing-style.md) applies to every written artifact and names commit messages in
its own scope, but Vale reads Markdown and never sees a commit message. The Notation table there
would otherwise be a rule with no coverage on the one artifact it names. So the same five
entries that [Project.Punctuation](../../styles/Project/Punctuation.yml) holds are applied to the
subject line by [tests/check-commit-msg.sh](../../tests/check-commit-msg.sh): interpunct, em
dash, en dash, a double hyphen with spaces around it, and the ditto mark. The list is not
extended there. A command-line option prefix such as `--no-cache` is not a double hyphen with
spaces around it, and stays legal.

The subject is checked and the body is not. A subject is one short line with no code fence, so a
banned character in it has no legitimate reading. A body is where command output and log
excerpts get pasted, and a commit message has no code fence to mark them, so a mechanical check
there would report violations that are correct to leave alone. A hook that reports false
positives teaches people to pass `--no-verify`, which turns off every hook at once.

Machine-written subjects are skipped. `fixup!`, `squash!`, `amend!`, `Merge ...`, and
`Revert "..."` either reproduce an older subject verbatim or are produced by git itself, so
rejecting them would break `git commit --fixup` and `git rebase --autosquash`.

### Branch and history policy

- Never push directly to the default branch. Use a feature branch and a pull request
- Never amend or rebase a commit that is already pushed to a shared branch
- Never commit secrets, API keys, or credentials. Use `.env` (ignored by `.gitignore`) and
  environment variables. Rules are in [SECURITY.md](../../SECURITY.md)

### Hooks

Install the hook runner once per clone. Without it, none of the checks run.

```bash
just bootstrap
prek run --all-files
```

The `commit-msg` hook calls [tests/check-commit-msg.sh](../../tests/check-commit-msg.sh), which
invokes `node_modules/.bin/commitlint` directly rather than through `npx`. Inside a hook, `npx`
reaches the network on every commit, which is both a stall and one more point at which a
dependency can be replaced underneath the check.

The Node dependency is declared in `package.json` and pinned by `package-lock.json`.
`just bootstrap` installs it with `npm ci`. Where the registry cannot be reached, the commitlint
step reports SKIP and the commit proceeds, while the character check still runs because it needs
no tools. A hook that always runs is not the same as a hook that always works, and this is where
the difference shows.

Keep hook repositories current on a cooldown so a freshly published release is not adopted
the day it lands.

```bash
prek update --cooldown-days 7
```

### Worktrees

Parallel agents each work in their own git worktree. Never share a working directory between
two agents running at the same time.

```bash
git worktree add ../repo-<branch> <branch>
```

Two agents in one directory overwrite each other's edits and stage each other's files.

`node_modules` is ignored by git, so a linked worktree never has one. A commitlint resolved
only against the current working directory would report SKIP in every worktree, which is the
one setup this section prescribes. [tests/check-commit-msg.sh](../../tests/check-commit-msg.sh)
falls back to the main working tree's `node_modules/.bin/commitlint` and passes that tree's
configuration file with `--config`. The flag is required: `@commitlint/resolve-extends`
resolves `extends` from the directory holding the configuration file, so without it the run
dies with `Cannot find module "@commitlint/config-conventional"`.

That same resolution rule caps what the fallback can do. The worktree's own configuration
cannot be used, because it sits in a directory with no `node_modules`, and the main tree's
configuration carries the main tree's rules rather than the branch's. So the fallback runs
only when the two configuration files are byte-identical, and the run says which file it
used. When they differ, when either tree has no configuration file, or when the rules live in
`package.json` where `--config` cannot reach them, the check reports its reason and declines:
SKIP locally, FAIL under CI. Passing a branch that changed the rules by applying the old rules
would be worse than not checking it. Run `npm ci` in the worktree to get the full check back.

### Pull requests

Describe what the code does now. Not discarded approaches, not prior iterations, not
alternatives that were considered. Only what is in the diff.

**The pull request title follows the same rules as a commit subject.** When a pull request is
squashed, the commit that lands on the default branch is built from the title, and the
`commit-msg` hook never sees that string because it only ever read the branch commits. A title
that does not parse leaves a commit that does not parse in permanent history.

Language is plain and factual, per [Writing Style](writing-style.md).

## Checklist

- Did the relevant tests, linters, and type checker pass before the commit?
- Does the subject open with a type from the table and a lowercase first word?
- Is the header at most 100 characters, with no trailing period?
- Does the commit contain exactly one logical change?
- Is the branch a feature branch rather than the default branch?
- Are there credentials, tokens, or `.env` contents in the diff?
- Does the pull request title parse as a commit subject?
- Does the pull request description cover only what the diff contains?

## Related documents

- [Code review](code-review.md)
- [Writing Style](writing-style.md)
- [Security](../../SECURITY.md)
