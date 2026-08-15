---
id: index-docs
title: Document Index
type: index
status: active
summary: Entry point for the {{REPO_NAME}} documentation
scope:
  - docs/**
read_when:
  - Deciding which document to read
  - Deciding where a new document belongs
related:
  - standard-documentation
---

# Document Index

## Purpose

The entry point for every document in this repository. Pick a target here instead of opening documents to find out what they contain.

## Scope

Everything under [docs/](docs/index.md).

Every document under [docs/](docs/index.md) is written in English. The rule is in [Writing Style](docs/standards/writing-style.md).

## Reading order

1. Pick one directory from the categories below.
2. Pick one document from that directory's index.
3. Open more only when the work turns out to need them. Do not load everything up front.
4. After creating or reading through a document, add one row to that directory's index.

## Documents

| Directory | Nature | When to open |
| --- | --- | --- |
| [standards/](docs/standards/index.md) | Rules that must be followed | Before writing code or documents |
| [guides/](docs/guides/index.md) | How a task is carried out | When following a procedure |
| [references/](docs/references/index.md) | External and supporting facts | When looking a fact up |
| [generated/](docs/generated/index.md) | Produced from code or a schema | When checking the current implementation state |

Material tied to one product or framework goes into its own domain directory under `docs`. The same four categories apply inside it.

### Repository root files

These carry no front matter. Notation rules still apply.

| Subject | File |
| --- | --- |
| Repository overview, getting started | [README.md](README.md) |
| Agent working rules | [AGENTS.md](AGENTS.md) ([CLAUDE.md](CLAUDE.md) is a pointer) |
| Credentials, secrets, sensitive data | [SECURITY.md](SECURITY.md) |
| Environment variable keys | [.env.example](.env.example) |
| Document verification | [tests/check-docs.sh](tests/check-docs.sh) |

## Related documents

- [Documentation](docs/standards/documentation.md)
- [Writing Style](docs/standards/writing-style.md)
- [Security](SECURITY.md)
