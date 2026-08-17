---
id: decision-0002-dogfood-the-scaffold-in-its-own-source-repository
title: 0002. Dogfood the scaffold in its own source repository
type: decision
status: accepted
summary: Shipped scaffold applied to this repository, and the checks that skip its templates
scope:
  - .
read_when:
  - Before changing a template under the assets directory
  - When a check passes here but fails in a scaffolded repository, or the reverse
related:
  - index-adr
  - decision-0003-keep-the-skill-contract-workflow-outside-the-shipped-job-names
sources:
  - .rumdl.toml
  - tests/check-prose.sh
  - .pre-commit-config.yaml
  - pyproject.toml
---

# 0002. Dogfood the scaffold in its own source repository

## Context and problem statement

This repository is the source of a skill that scaffolds other repositories. Until now it used
almost none of what it shipped. It had `.editorconfig` and `.gitattributes` and nothing else:
no [AGENTS.md](../../../AGENTS.md), no `docs/`, no `Justfile`, no check scripts. The templates
were verified only
by a smoke test that rendered them into a throwaway directory.

That leaves a whole class of defect invisible. A template can render, pass its own checks in a
freshly initialised directory, and still be wrong for a repository that already has files,
history, and a second copy of the same content. Nobody was exercising that path.

## Considered options

| Option | Why not |
| --- | --- |
| Keep verifying templates through the smoke test only | Only ever exercises an empty repository created seconds earlier |
| Copy selected files by hand | Drifts silently, and the drift is invisible because nothing compares the two |
| Run the scaffold against this repository | Chosen. See below |

## Decision outcome

Run `assets/scaffold.sh` against this repository and keep the result. The root now carries the
same command layer, check scripts, document hierarchy, tool configuration, and GitHub
governance files that a scaffolded repository receives.

Three exceptions are unavoidable, because this repository holds the templates themselves.

| File | Exception | Reason |
| --- | --- | --- |
| `.rumdl.toml` | The whole `assets` subtree is excluded | Template documents carry unrendered placeholders in their front matter and links written for the depth they land at, not the depth they are stored at |
| [tests/check-prose.sh](../../../tests/check-prose.sh) | Same paths excluded from the file list | Vale parses front matter as YAML and stops the whole run on the first template it reads |
| [.pre-commit-config.yaml](../../../.pre-commit-config.yaml) | One extra `skill-contract` hook | The skill contract is this repository's own gate and is not part of what is shipped |

The Vale exception is not a matter of taste. Without it the tool exits before checking
anything, so the alternative is not a stricter check but no check at all.

One more difference is a finding rather than a decision: `pyproject.toml` gains a second
`per-file-ignores` entry for `skills/*/assets/tests/**`. The shipped entry covers `tests/**`,
which does not match the same files one directory deeper. The two copies are byte-identical,
so they get the same exemption.

## Consequences

What this makes easier:

- A template that breaks an existing repository breaks this one first
- `just verify` is the same command here as in any repository the skill touches
- The document hierarchy is written by the same generator that users receive

What this makes harder:

- Every template change now has to satisfy two audiences: the rendered copy and the stored
  one. Adding a placeholder to front matter, for instance, is fine only because the two
  exceptions above exist
- The repository carries a second copy of every check script. They are not synchronised
  automatically, and nothing yet reports when they diverge

What is now fixed:

- The exception lists are enumerated in this record. Anything excluded from a check without a
  row here is a defect, not a decision
- `uv sync` is confirmed to work against the shipped `pyproject.toml`, which has no `project`
  table. `uv lock` on its own does not, so
  [scripts/bootstrap.sh](../../../scripts/bootstrap.sh) is right to call `uv sync`

## Related documents

- [Decision Records](index.md)
- [Architecture](../index.md)
- [Documentation](../../standards/documentation.md)
