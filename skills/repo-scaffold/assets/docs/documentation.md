---
id: standard-documentation
title: Documentation
type: standard
status: active
summary: File naming, path notation, front matter, document structure, lifecycle
scope:
  - docs/**
read_when:
  - Creating a new document
  - Editing an existing document
  - Deciding which directory a document belongs in
sources:
  - tests/check-docs.sh
  - tests/check-docs-metadata.sh
  - schemas/docs-frontmatter.schema.json
review_interval_days: 90
related:
  - index-docs
  - standard-writing-style
---

# Documentation

## Purpose

Keep every document in this repository in one shape: file names, path notation, metadata, body
structure, and the rules that say when a document has gone out of date.

An agent decides whether to open a document from its front matter. If the body has to be read
before that decision can be made, the metadata is incomplete.

## Scope

Every Markdown document under [docs/](../index.md).

The repository root files [README.md](../../README.md), [AGENTS.md](../../AGENTS.md),
[CLAUDE.md](../../CLAUDE.md), and [SECURITY.md](../../SECURITY.md) carry no front matter.
Hosting services recognize README and SECURITY by their conventional names, and CLAUDE.md is
a single import line, so metadata would outweigh the body. Notation rules still apply to all
four.

Language and notation are defined in [Writing Style](writing-style.md). Everything under
[docs/](../index.md) is written in English.

## File names

Use lowercase kebab-case.

| Rule | Example |
| --- | --- |
| Lowercase only | `error-handling.md` |
| Hyphen between words | `commit-convention.md` |
| No underscores, spaces, or uppercase | `Error_Handling.md` is rejected |
| Directory index is always `index.md` | [docs/standards/index.md](index.md) |

Keep a dot only when it carries meaning, such as a product version: `install-4.2.md`.

## Path notation

Point at a file or directory inside the repository with a Markdown link. Do not use a bare
backtick path.

**The link target is relative to the document that contains it, not to the repository root.** This is
the notation Markdown itself defines, so the link resolves the same way in a web view, in an editor,
and in a linter.

```markdown
Wrong: The startup procedure is in `README.md`, chapter 4.
Wrong: [Testing](docs/standards/testing.md)      relative to the repository root
Right: [Testing](testing.md)                     same directory
Right: [Document index](../index.md)             one level up
Right: [Contributing](../../README.md)           repository root
```

- Use the document title or a human-readable name as the link text. The path itself is not required.
- Link a directory through its `index.md`.
- When a glob makes a single link impossible, split the item and link each target.
- Write a heading anchor as `<path>#<heading-slug>`, for example
  [Hard limits](code-quality.md#hard-limits). Both the file and the heading are verified.

The cost is that moving a document breaks the links it holds and the links pointing at it. That cost
is paid back by the checks it buys: link targets and heading anchors are verified across files,
including anchors in another directory, which a root-relative path cannot express to any Markdown
tool. Fix the links in the same commit as the move, then run `just markdown`.

Three exceptions use backticks instead.

- Paths outside the repository: inside a deployment package, on a server, inside a container
- Paths inside a different repository
- A pattern that describes a format rather than a real file, such as `{area}_{action}_pop.html`

## Front matter

Every document opens with a YAML front matter block.

### Required properties

| Property | Meaning | Format |
| --- | --- | --- |
| `id` | Stable identifier | `<type>-<slug>`. Survives a move |
| `title` | Human-readable title | Identical to the body H1 |
| `type` | Document kind | The enum below |
| `status` | Current validity | Values depend on `type` |
| `summary` | One-line description | **Noun phrase.** No trailing period, no full sentence |
| `scope` | Code or area it applies to | Root-relative paths. Globs allowed |
| `read_when` | When it must be read | Situations. Do not restate the title |

`scope` and the optional `sources` are not the same property and neither replaces the other.
`scope` says where the document applies. `sources` says what the document describes. A shell
standard applies to every script in the repository and describes the two files that enforce
it, so the two lists have nothing in common.

```yaml
# Noun phrase
summary: Exception hierarchy, standard error response, log level rules

# Sentence. Rejected
summary: Defines the exception hierarchy, standard error response, and log levels.
```

`id` is independent of the file path. Move a document to another directory and the `id`
stays, so `related` references do not break.

### type enum

Fixed. No value outside these six.

| `type` | Location | Nature |
| --- | --- | --- |
| `index` | `index.md` in each directory | Document list for that scope |
| `standard` | Under `standards` | Rules that must be followed |
| `guide` | Under `guides` | How a task is carried out |
| `reference` | Under `references`, and `architecture` itself | External and supporting facts |
| `generated` | Under `generated` | Produced from code or a schema |
| `decision` | Under `architecture/adr` | One architecture decision, written once |

Directory name and `type` map one to one. The rule is the same under a nested domain directory.

A `decision` is the one type that is never rewritten. When the decision it holds stops
applying, a new record supersedes it. The format is in [Decision Records](../architecture/adr/index.md).

### status

Allowed values depend on `type`.

| `type` | Allowed `status` | Meaning |
| --- | --- | --- |
| `index` | `active` | An index is always valid. No other value |
| `standard` | `draft` | Not agreed yet. Not enforced |
| | `active` | In force. A violation is a review finding |
| | `deprecated` | Retired. The document that names it in `supersedes` replaces it |
| `guide` | `draft` | Procedure not verified yet |
| | `active` | Follow it as written |
| | `outdated` | Procedure no longer matches the implementation. Do not follow until fixed |
| `reference` | `active` | Safe to look up |
| | `outdated` | The source changed. Values need checking |
| | `archived` | No longer maintained. Kept for history |
| `generated` | `current` | In sync with its source |
| | `stale` | The source changed. Regenerate |
| `decision` | `proposed` | Written down, not agreed yet. Do not build on it |
| | `accepted` | In force. A change that contradicts it needs a new record |
| | `rejected` | Considered and turned down. Kept so it is not raised again blindly |
| | `superseded` | Replaced. The record naming it in `supersedes` holds now |

### Optional properties

Use only when they carry a value. Omit the key entirely when there is nothing to put in it.

| Property | When | Example |
| --- | --- | --- |
| `owners` | Ownership is split | `- backend` |
| `last_reviewed` | A person read the document and confirmed it | `2026-01-01` |
| `review_interval_days` | The type default is wrong for this document | `90` |
| `sources` | The document describes specific paths | `- tests/check-docs.sh` |
| `related` | Read together with this | `- standard-testing` |
| `supersedes` | This document replaces the one named | `- reference-old-install` |
| `generated_from` | Required for `type: generated` | `- src/database/schema.py` |
| `edit_policy` | Editing restriction | `generated` (never edited by hand) |

`related` and `supersedes` hold `id` values, not file paths.
`sources` and `generated_from` hold repository paths, one file or directory per item. No globs;
name a directory to cover a subtree.
Dates are absolute. Write `2026-01-01`, never "last week" or "recently".

The machine form of all of this is the
[front matter schema](../../schemas/docs-frontmatter.schema.json). It rejects any key not
listed on this page, so a misspelled optional key fails instead of being ignored.

## Document lifecycle

A document that no longer matches the system is worse than a missing one, because it is
trusted. Two independent signals say a document needs a second look. They are different
questions and they carry different weight.

| Signal | Question | Input | Verdict |
| --- | --- | --- | --- |
| Time | Has nobody looked at this in a while? | `last_reviewed`, `review_interval_days` | `stale-by-time`, a warning |
| Source drift | Did the thing it describes change since then? | `sources`, git history | `possibly-stale-source-drift`, a failure |

Source drift is the one that matters. Time passing is not evidence of anything, so it never
blocks a commit or a push. A declared source changing after the last review is evidence that
the document and the code have parted, so it fails the pre-push hook until a person settles it.

Drift is read from git history, not from file modification times. Cloning, checking out a
branch, and running a formatter all change modification times without changing content.

`sources` also has to point at something. A path that does not exist is reported as
`invalid-source-reference` and fails, because the alternative is a lifecycle check that
quietly measures nothing.

### Review intervals

`review_interval_days` overrides the default for the document's `type`. `0` means the document
does not go stale with time.

| `type` | Default | Why |
| --- | --- | --- |
| `index` | 365 | Changes when a document is added, and that edit is the review |
| `standard` | 180 | Rules drift against practice faster than they are rewritten |
| `guide` | 180 | Procedures break when the tooling under them moves |
| `reference` | 365 | Looked-up facts change on their own schedule |
| `generated` | 90 | Regeneration is cheap, so a short interval costs little |
| `decision` | 0 | A record of a past decision cannot go out of date |

### last_reviewed is set by hand

No tool writes `last_reviewed`, and none ever should. The value means "a person read this and
confirmed it". A tool that bumped the field would turn it into "a tool ran", which answers
nothing and hides every document that needs attention.

Set it on the day the reading happens, in the same commit as any correction it produced.

## Document structure

Header, Body, Footer. Only the Body varies by `type`.

```markdown
---
(front matter)
---

# Document title

## Purpose

What this document decides. One or two paragraphs.

## Scope

Where it applies. The `scope` field written out as prose.

(type-specific body)

## Related documents

- [Error handling and logging](error-handling.md)

## References

- [External specification](https://example.com/spec)
```

- `## Related documents` lists documents inside this repository only
- `## References` lists external material only
- Omit either section when it is empty. Never leave an empty heading

A `decision` document is the one exception to the header. It opens with
`## Context and problem statement` in place of `## Purpose` and `## Scope`, because the title
and the context already say what it decides and the decision itself says where it applies.

### Body per type

`index`

```markdown
## Reading order

## Documents

| Document | Contents |
```

`standard`

```markdown
## Principle

Why the rule exists. The sentence to fall back on when a judgment call is close.

## Rules

Rules as a table or list.

## Checklist

What to confirm before a review or a commit.
```

`guide`

```markdown
## Prerequisites

## Procedure

1. Step

## Verification

How to tell the procedure succeeded.

## Troubleshooting

| Symptom | Action |
```

`reference`

```markdown
## Summary

One table to scan.

## Details

Item by item.
```

`generated`

```markdown
## How it is generated

The command, plus the base commit or tag.

## Contents

The generated table or list.
```

`decision`

```markdown
## Context and problem statement

What made a decision necessary. The forces, not the answer.

## Considered options

One row or one heading per option, each with why it was not taken.

## Decision outcome

The choice, then what it means in practice.

## Consequences

What becomes easier, what becomes harder, what is now fixed.
```

## Placement

Answer two questions in order before creating a document.

1. Is it tied to one product or framework? If so it goes under that domain directory.
2. Which category is it?

| Directory | Test |
| --- | --- |
| `standards` | Would breaking it be a review finding? |
| `guides` | Does following the steps produce the result? |
| `references` | Is it a fact to look up rather than a procedure? |
| `generated` | Is it regenerated rather than edited? |
| `architecture` | Does it describe the shape of the system rather than how to work in it? |
| `architecture/adr` | Is it one decision, dated, that a later reader would ask about? |

A run procedure that applies to exactly one component belongs in that component's README, not here.

## Index management

Indexes come in two layers.

| Index | Contents | Updated by |
| --- | --- | --- |
| The document index in [AGENTS.md](../../AGENTS.md) | File names grouped by directory. No descriptions | **Generated.** Never edited by hand |
| [docs/index.md](../index.md) and each directory `index.md` | One line per document, plus reading order | Written by hand |

- After adding a document, add one row to that directory's index
- Do not restate index contents in another document

The AGENTS.md index is produced by [gen-doc-index.sh](../../scripts/gen-doc-index.sh) and run
by a pre-commit hook just before the commit. The hook is configured in
[.pre-commit-config.yaml](../../.pre-commit-config.yaml). Everything between
`<!-- DOC-INDEX:START -->` and `<!-- DOC-INDEX:END -->` is replaced wholesale, so
hand-written content placed there disappears on the next commit.

The format groups files by directory and joins the groups with a single `|`.

```text
<directory>:{<file1>,<file2>,...}|<directory>:{...}
```

Hooks are installed once per clone. The procedure is in the pre-commit hooks section of [README.md](../../README.md).

When the index changes, the hook rewrites AGENTS.md, stages it, and **fails that commit**.
That is the signal that the commit contents changed; commit again as is. It is the standard
pre-commit framework behavior.

## Staying stateless

Keep information that goes stale quickly out of [AGENTS.md](../../AGENTS.md) and out of
`standards` documents: progress, to-do lists, current branch names, personal assignments.
That belongs in an issue or a separate work note.

## Reporting conflicts

When two documents disagree, or a document disagrees with the code, do not pick a side.
Report the paths, the wording, and the observed behavior.

## What is checked mechanically

Every rule below has exactly one owner. A rule defined in two checkers drifts the moment one of
them is edited, and nothing reports the disagreement.

| Rule | Owner |
| --- | --- |
| Heading structure, list and fence formatting, the 100-character line limit | rumdl, `.rumdl.toml` |
| Link target existence and heading anchors, inside a file and across files | rumdl, `MD057` and `MD051` |
| Characters, wording, terminology | Vale, described in [Writing Style](writing-style.md) |
| Required keys, `type` values, `status` per `type`, `summary` form | The schema, through [tests/check-docs-metadata.sh](../../tests/check-docs-metadata.sh) |
| Identifiers, references, supersession, declared sources, reachability | The same script, graph phase |
| Time and source drift | The same script, lifecycle phases |
| External URL health | lychee, through [tests/check-links-external.sh](../../tests/check-links-external.sh) |
| `title` against the H1, directory against `type`, backticked repository paths | [tests/check-docs.sh](../../tests/check-docs.sh) |

The last row is what is left once every general-purpose tool has taken what it can. Each of those
three rules joins two worlds that no single tool sees at once: front matter and body, front matter
and file path, prose and file system. A schema cannot read the body or know its own path, and a
Markdown linter reads link targets but not the text inside a code span.

rumdl runs over the whole repository rather than over the changed files. Its cross-file anchor
check builds an index from whatever it was handed and skips silently when a target file is not
in that index, so handing it one file at a time turns anchor checking off without saying so.

Absolute link targets are rejected by `MD057` with `absolute-links` set to `warn`. The default is
`ignore`, under which `[a](/docs/foo.md)` passes silently. A rumdl warning still exits non-zero.

The schema check needs the front matter as YAML, and `check-jsonschema` has no front matter
reader. The script extracts each block into a temporary directory outside the repository,
validates the copies, and translates the temporary paths back before reporting.

## Checklist

- Is the file name lowercase kebab-case?
- Are all seven required front matter properties present?
- Does `type` match the directory, and is `status` allowed for that `type`?
- Are the optional keys spelled exactly as this page spells them?
- If `sources` is set, does every path exist, and does `scope` still say something different?
- Is any in-repository path written with backticks instead of a link?
- Is every link target relative to the document that holds it?
- Does the H1 match `title`, and are `## Purpose` and `## Scope` present?
- Was the new document added to its directory index?
- Does `just docs` pass, and does `just markdown` report nothing?

## Related documents

- [Document index](../index.md)
- [Writing Style](writing-style.md)
- [Standards](index.md)
- [Decision Records](../architecture/adr/index.md)
