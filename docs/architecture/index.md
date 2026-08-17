---
id: index-architecture
title: Architecture
type: index
status: active
summary: System shape and the decisions that produced it
scope:
  - docs/architecture/**
read_when:
  - Before moving a boundary between components
  - When a past decision needs its reasoning
related:
  - index-docs
---

# Architecture

## Purpose

Hold two kinds of document side by side: what the system looks like now, and why it looks
that way.

Separating them keeps both readable. The overview goes stale whenever the code moves. A
decision record never does, because it describes a choice made at a point in time.

## Scope

Everything under [docs/architecture/](index.md).

Rules that apply while writing code live in [standards/](../standards/index.md) instead.

## Reading order

1. Read the [Architecture Overview](overview.md) for the shape of the system as it stands.
2. Open a [decision record](adr/index.md) when the overview leaves a "why" unanswered.

## Documents

| Document | Contents |
| --- | --- |
| [Architecture Overview](overview.md) | Components, boundaries, data flow, external dependencies |
| [Decision Records](adr/index.md) | One record per decision, oldest first |

Add one row here when a document is added.

## Related documents

- [Document index](../index.md)
- [Standards](../standards/index.md)
