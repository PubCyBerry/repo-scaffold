---
type: Standard
title: Documentation
description: How docs/ is kept as an Open Knowledge Format bundle, and how its indexes stay current.
tags: [docs, okf]
---

# Documentation

`docs/` is a bundle in [Open Knowledge Format (OKF) v0.2](https://github.com/GoogleCloudPlatform/knowledge-catalog/blob/main/okf/SPEC.md):
a tree of markdown files with YAML front matter. Each file is one concept.
The bundle root is `docs/`.

## Front matter

Every markdown file except `index.md` and `log.md` starts with front matter.
OKF requires only `type`. This repository also requires `title` and `description`,
because the indexes are built from them.

| Key | Required | Value |
| --- | --- | --- |
| `type` | yes | The kind of document, such as `Standard`, `Decision`, `Guide`, or `Reference`. Pick a name that explains itself |
| `title` | yes | Display name, on one line |
| `description` | yes | One sentence that lets a reader decide whether to open the file, on one line |
| `status` | no | `draft`, `stable` (the default), or `deprecated`. Decision records use MADR values instead; see [Decision records](decisions.md) |
| `tags` | no | Short strings for topics that cut across directories |

Other OKF keys (`resource`, `sources`, `generated`, `verified`, `stale_after`) are optional.
When you use them, follow the spec. Unknown keys are allowed.

```markdown
---
type: Guide
title: Local setup
description: Install the toolchain and run the service on a workstation.
---
```

## Directories

| Directory | Holds |
| --- | --- |
| `standards/` | Rules that every contributor and agent follows |
| `decisions/` | Decision records in MADR format |

Add a directory when a group of documents needs one.

## Indexes are generated

`scripts/doc-index.sh` writes an `index.md` in every directory under `docs/` and the
document index block in `AGENTS.md`. Do not edit either by hand.

- After adding, moving, or retitling a document, run `bash scripts/doc-index.sh`.
- `bash scripts/doc-index.sh --check` fails when front matter is missing or an index is stale.
  The pre-commit hook and CI run it.
- The pre-commit hook is enabled per clone with `git config core.hooksPath .githooks`.

## Links

Link between documents with relative paths, such as `../decisions/0001-use-postgresql.md`.
OKF also allows paths that start with `/` from the bundle root, but forges resolve those
from the repository root, so they break when rendered.

## What does not belong here

Troubleshooting records are issues in the remote repository, not documents.
See [Troubleshooting](troubleshooting.md).
