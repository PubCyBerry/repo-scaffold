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

One exception: a script whose job is to run every check and aggregate the results uses `set -uo pipefail` and inspects exit codes explicitly. `-e` would abort on the first failing check and hide the rest. [check-docs.sh](tests/check-docs.sh) and its siblings work this way. Any script taking this exception says so in its header comment.

### Static analysis and formatting

| Tool | Purpose | Command |
| --- | --- | --- |
| `shellcheck` | Static analysis | `shellcheck script.sh` |
| `shfmt` | Formatting | `shfmt -d script.sh` |

Both run over every tracked script through [tests/check-shell.sh](tests/check-shell.sh), which the `shell-lint` hook invokes before each commit and CI runs on every push.

`shfmt` reads its formatting options from `.editorconfig`. Passing formatting flags on the command line makes it ignore `.editorconfig` entirely, so no formatting flags are passed anywhere: not in the hook, not in CI, not by hand. `.editorconfig` is the single source of truth.

Warnings are fixed, not suppressed, per [Code quality](docs/standards/code-quality.md). When a `shellcheck` finding genuinely does not apply, add a targeted directive on the line above with the reason.

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
- Does [tests/check-shell.sh](tests/check-shell.sh) pass?
- Does every `shellcheck` disable directive carry a reason?
- Were any formatting flags passed to `shfmt` instead of using `.editorconfig`?

## Related documents

- [Code quality](docs/standards/code-quality.md)
- [GitHub Actions](docs/standards/github-actions.md)
