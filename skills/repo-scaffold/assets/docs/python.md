---
id: standard-python
title: Python
type: standard
status: active
summary: Type hints, mypy, Pydantic validation, uv environments, ruff settings, test layout
scope:
  - "**/*.py"
  - "**/*.pyi"
  - pyproject.toml
  - uv.lock
read_when:
  - Writing or reviewing Python
  - A ruff or mypy check fails
  - Deciding how to validate data that comes from outside the process
  - Adding, removing, or locking a dependency
  - Turning these gates on in a repository that already has Python
  - Deciding which directory a new test file goes in
sources:
  - tests/check-python.sh
  - tests/run-tests.sh
related:
  - standard-code-quality
  - standard-testing
  - standard-shell
---

# Python

## Purpose

Turn the limits in [Code quality](code-quality.md) into settings a tool can enforce, so a review
argues about design rather than about line counts.

Nothing here is a new rule. Every ruff setting traces back to a line in
[Code quality](code-quality.md) . When a limit needs to change, that document changes first and this
one follows.

[Code quality](code-quality.md) also states that a language with a type system uses it and that
data from outside the process is validated before use, and leaves the tool choice to the
language. This document makes that choice: mypy checks the types, Pydantic validates the data,
and `uv` owns the environment they both run in.

## Scope

Every `.py` and `.pyi` file in this repository, plus the tool settings in `pyproject.toml`.

`pyproject.toml` is written only when the repository is detected as a Python repository. The scripts
that read it are written every time, so a repository with no Python reports a clean skip instead of
a missing file.

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
| Typed public interfaces | `ANN` |

Four notes on the mapping.

- `PLR0915` counts statements, not lines. Its default cap of 50 statements is the closest
  deterministic reading of the 100-line limit, so no explicit value is set.
- `E501` is not selected. The formatter already wraps at 100, and the only lines it cannot wrap are
  long URLs and long strings, where a lint error produces a `noqa` rather than a fix.
- `TRY003` is turned off. It asks for short exception messages, while
  [Code quality](code-quality.md) asks every error to name the operation, the input, and the fix.
  The standard wins.
- `ANN401` is lifted for `tests/**` . The reason is a single fixture parameter and is written
  out under [Type hints](#type-hints) . No other `ANN` rule is relaxed anywhere.

The settings list is `extend-select` , not `select` . Replacing `select` would drop the ruff
defaults, and undefined names would stop being reported.

Docstring rules are lifted for `tests/**` . [Code quality](code-quality.md) requires docstrings on
public APIs, and a test is not one.

### Type hints

Every function signature carries parameter and return types. Two tools enforce it, because
they fail at different moments: `ANN` reports a missing annotation at pre-commit on the files
being committed, and mypy rejects an unannotated definition at pre-push over the whole
repository.

`Any` is not a type hint, and `ANN401` rejects it in a signature. When a parameter has no
usable static type, the options in order are a `Protocol` , a `TypeVar` , `object` followed
by an explicit narrowing, and only then `Any` with a comment giving the reason.

This repository writes `Any` in one place: the `docs_repo` parameter of the unit tests. The
fixture class lives in the `conftest.py` those tests share, which pytest imports as `conftest`
and mypy resolves as `tests.unit.conftest` , so neither import spelling works for both tools.
That is why `ANN401` is lifted for `tests/**` , and it is the whole reason.

A signature that needs a comment to explain its own types wants a named type instead. Prefer
a type alias, a `Protocol` , or a small model over a nested `dict[str, list[tuple[int, str]]]`
repeated in three places.

### Type checking

mypy is the type checker. One checker and not two: a second one disagreeing with the first
turns every finding into an argument about which tool is right.

`strict = true` . A new repository starts there because every relaxation after the fact is a
decision someone has to defend.

An inline `type: ignore` names the error code and carries a comment with the reason, the same
as any other ignore. A bare `# type: ignore` is a review finding, because it also hides the
next error that appears on that line.

### Runtime validation

An annotation is a claim about a value, not a check on it. Data entering the process from
outside arrives in whatever shape its producer sent: a configuration file, a request body, a
JSON argument on the command line, an environment variable, a reply from another service.

Pydantic validates it at the edge. A hand-written chain of `isinstance` tests and `dict.get`
calls is a review finding. It drifts away from the annotation sitting next to it, it stops at
the first failure instead of reporting all of them, and it rarely says which field was wrong.

```python
from pydantic import BaseModel, ConfigDict, Field


class RetryPolicy(BaseModel):
    """Retry settings read from the deployment configuration file."""

    model_config = ConfigDict(extra="forbid", frozen=True)

    attempts: int = Field(ge=1, le=10)
    backoff_seconds: float = Field(gt=0)
```

Three settings, three reasons.

- `extra="forbid"` turns a misspelled key into an error instead of a line that is read by
  nobody and reported by nothing
- `frozen=True` keeps a validated object validated. An object that can be mutated after
  validation carries a guarantee that has expired
- `Field` constraints put the bound next to the field it bounds. A bound checked somewhere
  else is a bound somebody forgets to check

Use `TypeAdapter` for a shape that is not a model, such as `list[RetryPolicy]` or
`dict[str, int]` . Do not reach for Pydantic for structures that never leave the process: a
`dataclass` or a `NamedTuple` is the right tool there, and mypy already checks it.

A `ValidationError` is reported, never swallowed. [Code quality](code-quality.md) asks an
error message to name the operation and the input, and `err.errors()` already carries the
field path and the offending value.

The Python checkers this repository ships are the one exception, written down here so nobody
copies it by accident. They declare `dependencies = []` so they run in a target repository
that has no lock file and no installed packages, so they parse front matter by hand and fail
with a file name and a line number instead. Application code has a lock file and uses
Pydantic.

### Environment management

`uv` owns the interpreter, the virtual environment, the dependency set, and the lock file. It
is the only tool that does. Two package managers in one repository resolve two dependency
graphs, and nothing tells you which of the two the pipeline used.

| Task | Command |
| --- | --- |
| Create or update the environment from the lock file | `uv sync` |
| Add a dependency | `uv add <package>` |
| Add a development-only dependency | `uv add --dev <package>` |
| Remove a dependency | `uv remove <package>` |
| Re-resolve the lock file | `uv lock` |
| Run a command inside the environment | `uv run <command>` |
| Run a single-file script with inline metadata | `uv run --script <path>` |
| Install a standalone tool | `uv tool install <spec>` |

Do not use `pip install` , `python -m venv` , `poetry` , `pipenv` , or `conda` here. Do not
activate the environment by hand and then call `python` : an activated shell is state that
nobody else has, and a command that works only after activation fails in a hook and in
continuous integration. Prefix the command with `uv run` instead, which is what the hooks and
the workflows already do.

`pyproject.toml` and `uv.lock` are committed together, in the same commit. A lock file
without the manifest that produced it cannot be regenerated, and a manifest without its lock
file resolves differently on every machine.

[scripts/bootstrap.sh](../../scripts/bootstrap.sh) runs `uv sync` when `pyproject.toml` is
present, and installs the pinned tools from [tools.txt](../../tools.txt) through
`uv tool install` . A fresh clone runs `just bootstrap` once and holds the versions the
pipeline holds.

### Locked tool versions

Tool versions live in the `dev` dependency group of `pyproject.toml` and are pinned by `uv.lock`.

When `pyproject.toml` , `uv.lock` , and `uv` are all present,
[tests/check-python.sh](../../tests/check-python.sh) and
[tests/run-tests.sh](../../tests/run-tests.sh) invoke tools through `uv run --frozen` . A hook, a CI
job, and a developer then run the same version. When any of the three is missing, the scripts fall
back to whatever is on `PATH` and say so in their output.

Versions are raised by the dependency update bot, not by hand.

### Pin the interpreter, or the lock file picks one for you

The shipped `pyproject.toml` declares no `requires-python`, because it declares no `project`
table either. `uv` still has to write a `requires-python` into `uv.lock`, so it uses the
interpreter it found on the machine that generated the file. Whoever runs `just bootstrap`
first therefore decides the floor for everyone else, silently, and the first sign of it is a
resolution failure on somebody else's machine.

Set the floor explicitly instead. One line, at the top level of `pyproject.toml`:

```toml
requires-python = ">=3.13"
```

Pick the oldest interpreter the repository actually supports, not the newest one installed.
Then regenerate the lock file so it records the decision rather than the accident.

```bash
uv sync
```

The same value belongs in whatever the continuous integration workflow installs, so the floor
is checked rather than assumed.

### Checks

| Command | Tool | Hook |
| --- | --- | --- |
| `just lint` | `ruff check` | `python-lint`, pre-commit |
| `just type` | `mypy` | `mypy`, pre-push |
| `just test` | `pytest`, all suites | none |
| `just test-unit` | `pytest tests/unit` | `unit-test`, pre-push |
| `just fmt` | `ruff format` | `python-format` checks it, pre-commit |
| `just fix` | `ruff check --fix` | none |

Checks never rewrite a file. A hook that reformats during a commit makes the committed content
differ from the checked content. [scripts/fmt.sh](../../scripts/fmt.sh) and
[scripts/fix.sh](../../scripts/fix.sh) are the only scripts that write, and they are run by hand.

Type checking and unit tests run at pre-push rather than pre-commit because both answer a
repository-wide question. Checking a subset gives a wrong answer, not a faster one.

### Test layout

One directory per suite.

```text
tests/
├── unit/           fast and isolated. The pre-push hook runs this suite only
├── integration/    crosses a real boundary
└── e2e/            observed from outside
```

A missing directory and an empty directory are both a skip, so a repository that has not written
tests yet still passes. What belongs in a test is in [Testing](testing.md) .

### Adoption in an existing repository

Turning `strict = true` on over existing code produces hundreds of findings at once, and output
nobody reads is the same as no output. Three steps instead.

1. Establish a passing baseline. Run mypy without `strict` and fix what it reports. Commit that.
2. Block new regressions. Turn `strict = true` on at the top level, then add one
   `[[tool.mypy.overrides]]` block per module that still fails, relaxing only the flags it needs.
   New code is strict from the first line.
3. Tighten. Remove one override per change until none are left. The override list is the remaining
   work, and it only shrinks.

Ruff follows the same shape: adopt `extend-select` in full, and hold the modules that cannot pass
yet in `per-file-ignores` rather than deleting the rule for everyone.

Runtime validation is adopted one boundary at a time, not one module at a time. Take the entry
point that fails most often, replace its hand-written parsing with a model, and delete the
checks the model now covers. A boundary that keeps both is worse than one that keeps neither.

## Checklist

- Does every setting in `pyproject.toml` trace back to a line in [Code quality](code-quality.md)?
- Does every function signature carry parameter and return types?
- Does every `noqa` and every `type: ignore` carry a reason and an error code?
- Does every `Any` in a signature carry a reason, or does a `Protocol` fit instead?
- Is data from outside the process parsed into a Pydantic model rather than checked by hand?
- Was the environment changed through `uv` rather than `pip` or a hand-made virtual environment?
- Are `pyproject.toml` and `uv.lock` committed together?
- Does the new test file sit in the unit, integration, or e2e suite directory?
- Does [tests/check-python.sh](../../tests/check-python.sh) pass?

## Related documents

- [Code quality](code-quality.md)
- [Testing](testing.md)
- [Shell](shell.md)
- [Standards](index.md)
