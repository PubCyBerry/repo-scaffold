---
id: decision-0006-name-one-type-checker-one-validator-and-one-environment-manager
title: 0006. Name one type checker, one validator, and one environment manager
type: decision
status: accepted
summary: Why the Python standard names mypy, Pydantic, and uv instead of leaving the choice open
scope:
  - docs/standards/python.md
  - pyproject.toml
read_when:
  - Before proposing a second Python type checker, validator, or package manager
  - When a scaffolded repository asks why Pydantic is required at its boundaries
related:
  - index-adr
  - standard-python
  - standard-code-quality
sources:
  - docs/standards/python.md
  - pyproject.toml
---

# 0006. Name one type checker, one validator, and one environment manager

## Context and problem statement

[Python](../../standards/python.md) described ruff settings, mypy in strict mode, and a lock
file, and stopped there. Three questions it did not answer came back in review anyway.

1. Are type annotations required, or are they a style preference that mypy happens to check?
2. What validates data that arrives from outside the process, where an annotation is a claim
   and not a check?
3. Which tool owns the environment, given that `uv` appeared in the scripts but was never
   stated as a rule?

An unanswered question in a standard is answered per pull request instead, differently each
time. This repository ships that standard into other repositories, so each gap is copied
into every repository the skill scaffolds.

## Considered options

| Option | Why not |
| --- | --- |
| Leave the three questions open | The gap is the defect. Every repository resolves it again, and the resolutions disagree |
| Name the rules but pick no tools | "Validate external input" with no named validator produces a hand-written `isinstance` chain, which is the thing the rule exists to prevent |
| Name a tool per rule and allow substitutes | Two package managers resolve two dependency graphs, and nothing reports which one the pipeline used |
| Name exactly one tool per rule | Chosen |

## Decision outcome

The standard names one tool for each of the three, and no alternates.

- **mypy** is the type checker. `ANN` joins `extend-select` so a missing annotation fails at
  pre-commit on the files being committed, and mypy fails at pre-push over the repository.
  Two tools for one rule is deliberate: they report at different moments, and the earlier
  report is the cheaper one.
- **Pydantic** validates data crossing into the process. The rule is scoped to that boundary.
  Structures that never leave the process stay a `dataclass` , which mypy already checks, so
  the dependency is not imposed on a repository that parses nothing.
- **`uv`** owns the interpreter, the environment, the dependency set, and the lock file.
  `pip` , `python -m venv` , `poetry` , `pipenv` , and `conda` are out.

`ANN401` is relaxed for `tests/**` and nowhere else. The reason is one fixture parameter whose
class cannot be imported under a name that both pytest and mypy resolve, and it is written out
in the standard rather than left as a bare entry in `per-file-ignores` .

The Python checkers this repository ships keep declaring `dependencies = []` . They have to
run inside a target repository that has no lock file and no installed packages, so they cannot
import Pydantic. That exemption is stated in the standard so it is read as a constraint on
those four files and not as a precedent.

## Consequences

What this makes easier:

- A review argues about where a boundary is, not about which validator to use at it
- A scaffolded repository starts with the annotation rule enforced rather than implied
- One dependency graph per repository, and one command that reproduces it

What this makes harder:

- A repository that parses external data takes on Pydantic as a runtime dependency. Reversing
  that needs a record superseding this one
- Turning `ANN` on over an existing codebase produces findings in bulk. The staged adoption in
  [Python](../../standards/python.md) applies to it the same way it applies to `strict = true`
- A team that already standardised on another package manager has to migrate before this
  scaffold fits

## Related documents

- [Decision Records](index.md)
- [Python](../../standards/python.md)
- [Code Quality](../../standards/code-quality.md)
