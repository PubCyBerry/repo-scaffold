---
id: standard-python
title: Python
type: standard
status: active
summary: Ruff and mypy settings derived from code quality limits, test layout, locked tool versions
scope:
  - "**/*.py"
  - "**/*.pyi"
  - pyproject.toml
read_when:
  - Writing or reviewing Python
  - A ruff or mypy check fails
  - Turning these gates on in a repository that already has Python
  - Deciding which directory a new test file goes in
related:
  - standard-code-quality
  - standard-testing
  - standard-shell
---

# Python

## Purpose

Turn the limits in [Code quality](code-quality.md) into settings a tool can enforce, so a review argues about design rather than about line counts.

Nothing here is a new rule. Every ruff setting traces back to a line in [Code quality](code-quality.md). When a limit needs to change, that document changes first and this one follows.

## Scope

Every `.py` and `.pyi` file in this repository, plus the tool settings in `pyproject.toml`.

`pyproject.toml` is written only when the repository is detected as a Python repository. The scripts that read it are written every time, so a repository with no Python reports a clean skip instead of a missing file.

## Rules

### Derived limits

| Rule in [Code quality](code-quality.md) | ruff setting |
| --- | --- |
| Cyclomatic complexity at most 8 | `C901`, `mccabe.max-complexity = 8` |
| At most 5 positional parameters | `PLR0913`, `pylint.max-args = 5` |
| At most 100 lines per function | `PLR0915` |
| Line length 100 | `line-length = 100` |
| Absolute imports only | `TID252`, `flake8-tidy-imports.ban-relative-imports = "all"` |
| Google-style docstrings | `D`, `pydocstyle.convention = "google"` |
| No unjustified ignore | `PGH004`, `RUF100` |
| No commented-out code | `ERA001` |
| Never swallow an exception | `BLE001`, the `TRY` family |

Three notes on the mapping.

- `PLR0915` counts statements, not lines. Its default cap of 50 statements is the closest deterministic reading of the 100-line limit, so no explicit value is set.
- `E501` is not selected. The formatter already wraps at 100, and the only lines it cannot wrap are long URLs and long strings, where a lint error produces a `noqa` rather than a fix.
- `TRY003` is turned off. It asks for short exception messages, while [Code quality](code-quality.md) asks every error to name the operation, the input, and the fix. The standard wins.

The settings list is `extend-select`, not `select`. Replacing `select` would drop the ruff defaults, and undefined names would stop being reported.

Docstring rules are lifted for `tests/**`. [Code quality](code-quality.md) requires docstrings on public APIs, and a test is not one.

### Type checking

`strict = true`. A new repository starts there because every relaxation after the fact is a decision someone has to defend.

An inline `type: ignore` carries a comment with the reason, the same as any other ignore.

### Locked tool versions

Tool versions live in the `dev` dependency group of `pyproject.toml` and are pinned by `uv.lock`.

When `pyproject.toml`, `uv.lock`, and `uv` are all present, [tests/check-python.sh](../../tests/check-python.sh) and [tests/run-tests.sh](../../tests/run-tests.sh) invoke tools through `uv run --frozen`. A hook, a CI job, and a developer then run the same version. When any of the three is missing, the scripts fall back to whatever is on `PATH` and say so in their output.

Versions are raised by the dependency update bot, not by hand.

### Checks

| Command | Tool | Hook |
| --- | --- | --- |
| `just lint` | `ruff check` | `python-lint`, pre-commit |
| `just type` | `mypy` | `mypy`, pre-push |
| `just test` | `pytest`, all suites | none |
| `just test-unit` | `pytest tests/unit` | `unit-test`, pre-push |
| `just fmt` | `ruff format` | `python-format` checks it, pre-commit |
| `just fix` | `ruff check --fix` | none |

Checks never rewrite a file. A hook that reformats during a commit makes the committed content differ from the checked content. [scripts/fmt.sh](../../scripts/fmt.sh) and [scripts/fix.sh](../../scripts/fix.sh) are the only scripts that write, and they are run by hand.

Type checking and unit tests run at pre-push rather than pre-commit because both answer a repository-wide question. Checking a subset gives a wrong answer, not a faster one.

### Test layout

One directory per suite.

```text
tests/
├── unit/           fast and isolated. The pre-push hook runs this suite only
├── integration/    crosses a real boundary
└── e2e/            observed from outside
```

A missing directory and an empty directory are both a skip, so a repository that has not written tests yet still passes. What belongs in a test is in [Testing](testing.md).

### Adoption in an existing repository

Turning `strict = true` on over existing code produces hundreds of findings at once, and output nobody reads is the same as no output. Three steps instead.

1. Establish a passing baseline. Run mypy without `strict` and fix what it reports. Commit that.
2. Block new regressions. Turn `strict = true` on at the top level, then add one `[[tool.mypy.overrides]]` block per module that still fails, relaxing only the flags it needs. New code is strict from the first line.
3. Tighten. Remove one override per change until none are left. The override list is the remaining work, and it only shrinks.

Ruff follows the same shape: adopt `extend-select` in full, and hold the modules that cannot pass yet in `per-file-ignores` rather than deleting the rule for everyone.

## Checklist

- Does every setting in `pyproject.toml` trace back to a line in [Code quality](code-quality.md)?
- Does every `noqa` and every `type: ignore` carry a reason?
- Are `pyproject.toml` and `uv.lock` committed together?
- Does the new test file sit in the unit, integration, or e2e suite directory?
- Does [tests/check-python.sh](../../tests/check-python.sh) pass?

## Related documents

- [Code quality](code-quality.md)
- [Testing](testing.md)
- [Shell](shell.md)
- [Standards](index.md)
