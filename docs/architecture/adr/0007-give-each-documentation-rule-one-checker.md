---
id: decision-0007-give-each-documentation-rule-one-checker
title: 0007. Give each documentation rule one checker
type: decision
status: accepted
summary: Why the shell document checker shrank to the three rules no general-purpose tool can hold
scope:
  - tests/check-docs.sh
  - docs/standards/documentation.md
read_when:
  - Before adding a document rule to a second checker
  - When deciding whether a new check belongs in a tool or in a script
related:
  - index-adr
  - standard-documentation
sources:
  - tests/check-docs.sh
  - schemas/docs-frontmatter.schema.json
  - scripts/docs_graph.py
  - .rumdl.toml
---

# 0007. Give each documentation rule one checker

## Context and problem statement

[tests/check-docs.sh](../../../tests/check-docs.sh) grew before the tools around it did.
By the time rumdl, a front matter JSON Schema,
[scripts/docs_graph.py](../../../scripts/docs_graph.py), and lychee were all in place, four
of its five phases restated rules those tools already owned.

The overlap was not academic. The table of which `status` values a `type` allows existed twice:
once as a `case` statement in the script, once as `if`/`then` pairs in the schema. Nothing
compared them. Editing one and forgetting the other produced two checkers that disagreed, and
the disagreement surfaced as a passing build.

Two further symptoms came from the same cause. The pre-push hook called the script's `graph`
phase, which checks a strict subset of what `docs_graph.py` checks, so the weaker of two
available checkers was the one guarding pushes. And `just verify` ran both, checking identifiers
twice per run.

[Documentation](../../standards/documentation.md) justified part of this as deliberate: front
matter was "checked twice, on purpose, by tools that fail differently". That reasoning holds for
error message quality and holds for nothing else. Both checks ran in the same hook stage, against
the same files, at the same moment.

## Considered options

| Option | Why not |
| --- | --- |
| Leave it. Two checkers catch more than one | They catch the same thing. What one adds is a second place to forget |
| Delete only the phases that were provably dead | The `status` table stays duplicated, which is the defect that motivated the work |
| Move everything into [scripts/docs_graph.py](../../../scripts/docs_graph.py) and delete the shell script | Correct in shape, but every document rule then needs `uv`. The three surviving rules need no tool at all |
| Keep a shell script holding only what no general-purpose tool can hold | Chosen |

## Decision outcome

Each rule has exactly one owner. The boundary is not "which tool is more standard" but **does
the rule join two worlds that no single tool sees at once**.

Three rules do, and they stay in [tests/check-docs.sh](../../../tests/check-docs.sh):

- `title` against the body H1 joins front matter and body. A schema validates a mapping and
  never sees the prose below it.
- Directory against `type` joins front matter and file path. A schema does not know the path of
  the document it is validating.
- A backticked repository path joins prose and file system. rumdl resolves link targets and does
  not ask whether the text inside a code span names a real file.

Everything else moves to the tool that already owned it.
[schemas/docs-frontmatter.schema.json](../../../schemas/docs-frontmatter.schema.json)
takes required keys, the `type` enum, `status` per `type`, the `summary` form, and
`generated_from`. [scripts/docs_graph.py](../../../scripts/docs_graph.py) takes identifiers,
references, supersession, declared sources, and reachability. rumdl takes link target
existence and anchors, with `MD057`'s `absolute-links` set to `warn` so absolute targets
stay rejected. lychee keeps external URLs.

The script no longer takes `--no-net` or `--timeout`. It makes no network requests and reads no
front matter key beyond `title` and `type`.

Missing keys are reported by the two surviving front matter phases, but as "cannot evaluate"
with a pointer to the schema, not as a rule of their own. Being unable to run a check and
failing it are different outcomes and read differently in a log.

## Consequences

What this makes easier:

- Changing a front matter rule means editing one file. The schema is the contract, and the
  contract is machine-readable
- A push is guarded by the stronger graph checker rather than the weaker one
- `just verify` stops checking identifiers twice
- The script is small enough to read in one sitting

What this makes harder:

- rumdl is now load-bearing for link checking. A repository that skips `just bootstrap` gets no
  link verification locally until CI runs. That is the same bargain every other tool-backed
  check in this repository already makes
- The specific message "written relative to the repository root" is gone. rumdl reports the same
  link as not existing, which is correct and less helpful
- A rule that spans two worlds has no general-purpose home. Adding one means adding to this
  script, and the test for whether it belongs is the boundary stated above

This record replaces the "checked twice, on purpose" reasoning in
[Documentation](../../standards/documentation.md). That page now carries a single ownership
table instead.

## Related documents

- [Decision Records](index.md)
- [Documentation](../../standards/documentation.md)
- [0005. Run external link checking on a schedule only](0005-run-external-link-checking-on-a-schedule-only.md)
