---
id: standard-shell
title: Shell
type: standard
status: active
summary: Strict mode, shellcheck and shfmt gates, formatting source of truth
scope:
  - "**/*.sh"
  - "**/*.bash"
read_when:
  - Writing or editing a shell script
  - A shellcheck or shfmt check fails
  - Deciding how a script should report failure
sources:
  - tests/check-shell.sh
  - .shellcheckrc
related:
  - standard-code-quality
  - standard-github-actions
---

# Shell

## Purpose

Shell scripts fail quietly by default. These rules make failure loud and formatting mechanical.

## Scope

Every `.sh` and `.bash` file in this repository, including scripts embedded in CI steps.

## Rules

### Strict mode

Every script starts with strict mode.

```bash
#!/usr/bin/env bash
set -euo pipefail
```

One exception: a script whose job is to run every check and aggregate the results uses
`set -uo pipefail` and inspects exit codes explicitly. `-e` would abort on the first failing
check and hide the rest. [check-docs.sh](../../tests/check-docs.sh) and its siblings work
this way. Any script taking this exception says so in its header comment.

### Static analysis and formatting

| Tool | Purpose | Command |
| --- | --- | --- |
| `shellcheck` | Static analysis | `shellcheck script.sh` |
| `shfmt` | Formatting | `shfmt -d script.sh` |

Both run over every tracked script through
[tests/check-shell.sh](../../tests/check-shell.sh), which the `shell-lint` hook invokes
before each commit and CI runs on every push.

`shfmt` reads its formatting options from `.editorconfig`. Passing formatting flags on the
command line makes it ignore `.editorconfig` entirely, so no formatting flags are passed
anywhere: not in the hook, not in CI, not by hand. `.editorconfig` is the single source of
truth.

`shellcheck` reads [.shellcheckrc](../../.shellcheckrc) at the repository root the same way,
and for the same reason: a flag passed in one place and not another makes the hook and CI
disagree about what counts as a finding. Severity, the shell dialect, and any repository-wide
disable belong in that file, where they are reviewed like any other change.

One optional check is deliberately left off. `enable=quote-safe-variables` flags every
unquoted expansion, which is correct advice and unusable as a starting point: a repository
with existing scripts lights up with hundreds of SC2248 findings on the first run. That state
does not get the findings fixed, it gets the check switched off. Turn it on once the existing
scripts are clean.

Warnings are fixed, not suppressed, per [Code quality](code-quality.md). When a `shellcheck`
finding genuinely does not apply, add a targeted directive on the line above with the reason.

```bash
# shellcheck disable=SC2016  # single quotes are intentional, awk reads the literal
```

### Conventions

- Quote every expansion: `"$var"`, `"${array[@]}"`
- Use `$(...)`, never backticks
- Check that a command exists before using it, and say how to install it when it is missing
- Never print a secret value. Report the key name, the file, and the line number instead

## Checklist

- Does the script open with a shebang and strict mode, or document its exception?
- Is every expansion quoted?
- Does [tests/check-shell.sh](../../tests/check-shell.sh) pass?
- Does every `shellcheck` disable directive carry a reason?
- Were any formatting flags passed to `shfmt` instead of using `.editorconfig`?

## Related documents

- [Code quality](code-quality.md)
- [GitHub Actions](github-actions.md)
