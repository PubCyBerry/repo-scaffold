---
id: standard-documentation
title: Documentation
type: standard
status: active
summary: File naming, path notation, front matter, document structure
scope:
  - docs/**
read_when:
  - Creating a new document
  - Editing an existing document
  - Deciding which directory a document belongs in
related:
  - index-docs
  - standard-writing-style
---

# Documentation

## Purpose

Keep every document in this repository in one shape: file names, path notation, metadata, and body structure.

An agent decides whether to open a document from its front matter. If the body has to be read before that decision can be made, the metadata is incomplete.

## Scope

Every Markdown document under [docs/](docs/index.md).

The repository root files [README.md](README.md), [AGENTS.md](AGENTS.md), [CLAUDE.md](CLAUDE.md), and [SECURITY.md](SECURITY.md) carry no front matter. Hosting services recognize README and SECURITY by their conventional names, and CLAUDE.md is a single import line, so metadata would outweigh the body. Notation rules still apply to all four.

Language and notation are defined in [Writing Style](docs/standards/writing-style.md). Everything under [docs/](docs/index.md) is written in English.

## File names

Use lowercase kebab-case.

| Rule | Example |
| --- | --- |
| Lowercase only | `error-handling.md` |
| Hyphen between words | `commit-convention.md` |
| No underscores, spaces, or uppercase | `Error_Handling.md` is rejected |
| Directory index is always `index.md` | [docs/standards/index.md](docs/standards/index.md) |

Keep a dot only when it carries meaning, such as a product version: `install-4.2.md`.

## Path notation

Point at a file or directory inside the repository with a Markdown link. Do not use a bare backtick path.

**The link target is relative to the repository root, not to the document.** Moving a document to another directory then does not break its links.

```markdown
Wrong: The startup procedure is in `README.md`, chapter 4.
Wrong: [Testing](../standards/testing.md)              relative to the document
Right: [Testing](docs/standards/testing.md)            relative to the repository root
```

- Use the document title or a human-readable name as the link text. The path itself is not required.
- Link a directory through its `index.md`.
- When a glob makes a single link impossible, split the item and link each target.

A root-relative path is resolved against the current directory by Markdown renderers, so these links are not clickable in a web view. Documents here are read by agents and local editors, so path stability wins.

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

```yaml
# Noun phrase
summary: Exception hierarchy, standard error response, log level rules

# Sentence. Rejected
summary: Defines the exception hierarchy, standard error response, and log levels.
```

`id` is independent of the file path. Move a document to another directory and the `id` stays, so `related` references do not break.

### type enum

Fixed. No value outside these five.

| `type` | Location | Nature |
| --- | --- | --- |
| `index` | `index.md` in each directory | Document list for that scope |
| `standard` | Under `standards` | Rules that must be followed |
| `guide` | Under `guides` | How a task is carried out |
| `reference` | Under `references` | External and supporting facts |
| `generated` | Under `generated` | Produced from code or a schema |

Directory name and `type` map one to one. The rule is the same under a nested domain directory.

### status

Allowed values depend on `type`.

| `type` | Allowed `status` | Meaning |
| --- | --- | --- |
| `index` | `active` | An index is always valid. No other value |
| `standard` | `draft` | Not agreed yet. Not enforced |
| | `active` | In force. A violation is a review finding |
| | `deprecated` | Retired. Read the document named in `supersedes` |
| `guide` | `draft` | Procedure not verified yet |
| | `active` | Follow it as written |
| | `outdated` | Procedure no longer matches the implementation. Do not follow until fixed |
| `reference` | `active` | Safe to look up |
| | `outdated` | The source changed. Values need checking |
| | `archived` | No longer maintained. Kept for history |
| `generated` | `current` | In sync with its source |
| | `stale` | The source changed. Regenerate |

### Optional properties

Use only when they carry a value. Omit the key entirely when there is nothing to put in it.

| Property | When | Example |
| --- | --- | --- |
| `owners` | Ownership is split | `- backend` |
| `last_reviewed` | Content was reviewed | `2026-01-01` |
| `related` | Read together with this | `- standard-testing` |
| `supersedes` | Replaced by this document | `- reference-old-install` |
| `generated_from` | Required for `type: generated` | `- src/database/schema.py` |
| `edit_policy` | Editing restriction | `generated` (never edited by hand) |

`related` and `supersedes` hold `id` values, not file paths.
Dates are absolute. Write `2026-01-01`, never "last week" or "recently".

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

- [Error handling and logging](docs/standards/error-handling.md)

## References

- [External specification](https://example.com/spec)
```

- `## Related documents` lists documents inside this repository only
- `## References` lists external material only
- Omit either section when it is empty. Never leave an empty heading

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

A run procedure that applies to exactly one component belongs in that component's README, not here.

## Index management

Indexes come in two layers.

| Index | Contents | Updated by |
| --- | --- | --- |
| The document index in [AGENTS.md](AGENTS.md) | File names grouped by directory. No descriptions | **Generated.** Never edited by hand |
| [docs/index.md](docs/index.md) and each directory `index.md` | One line per document, plus reading order | Written by hand |

- After adding a document, add one row to that directory's index
- Do not restate index contents in another document

The AGENTS.md index is produced by [gen-doc-index.sh](scripts/gen-doc-index.sh) and run by a pre-commit hook just before the commit. The hook is configured in [.pre-commit-config.yaml](.pre-commit-config.yaml). Everything between `<!-- DOC-INDEX:START -->` and `<!-- DOC-INDEX:END -->` is replaced wholesale, so hand-written content placed there disappears on the next commit.

The format groups files by directory and joins the groups with a single `|`.

```
<directory>:{<file1>,<file2>,...}|<directory>:{...}
```

Hooks are installed once per clone. The procedure is in the pre-commit hooks section of [README.md](README.md).

When the index changes, the hook rewrites AGENTS.md, stages it, and **fails that commit**. That is the signal that the commit contents changed; commit again as is. It is the standard pre-commit framework behavior.

## Staying stateless

Keep information that goes stale quickly out of [AGENTS.md](AGENTS.md) and out of `standards` documents: progress, to-do lists, current branch names, personal assignments. That belongs in an issue or a separate work note.

## Reporting conflicts

When two documents disagree, or a document disagrees with the code, do not pick a side. Report the paths, the wording, and the observed behavior.

## Checklist

- Is the file name lowercase kebab-case?
- Are all seven required front matter properties present?
- Does `type` match the directory, and is `status` allowed for that `type`?
- Is any in-repository path written with backticks instead of a link?
- Is every link target relative to the repository root?
- Does the H1 match `title`, and are `## Purpose` and `## Scope` present?
- Was the new document added to its directory index?
- Does [tests/check-docs.sh](tests/check-docs.sh) pass?

## Related documents

- [Document index](docs/index.md)
- [Writing Style](docs/standards/writing-style.md)
- [Standards](docs/standards/index.md)
