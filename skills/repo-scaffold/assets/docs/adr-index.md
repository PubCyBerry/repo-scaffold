---
id: index-adr
title: Decision Records
type: index
status: active
summary: One record per architecture decision, oldest first
scope:
  - docs/architecture/adr/**
read_when:
  - Before reversing or repeating a past decision
  - When a review asks why a design is the way it is
related:
  - index-architecture
---

# Decision Records

## Purpose

Keep the reasoning behind each architecture decision, so that a later reader can tell a
deliberate choice from an accident.

A record is written once and then left alone. When a decision stops holding, write a new
record that supersedes it rather than editing the old one. The value of the directory is the
trail, not the latest entry.

## Scope

Everything under [docs/architecture/adr/](index.md).

Record a decision when it is hard to reverse, when it constrains work that comes after it, or
when a reasonable person would ask why. Skip it otherwise.

## Reading order

1. Read [0001. Record architecture decisions](0001-record-architecture-decisions.md) first.
   It sets the format every other record follows.
2. Read the rest in number order when catching up, or open one by name when a specific
   question comes up.

## Documents

| Document | Status | Contents |
| --- | --- | --- |
| [0001. Record architecture decisions](0001-record-architecture-decisions.md) | accepted | Why this directory exists and how a record is written |

Add one row here when a record is added.

## Writing a new record

1. Take the next free number. Numbers are never reused, even after a record is rejected.
2. Name the file `NNNN-<kebab-case-title>.md` with four digits.
3. Set `type` to `decision` and `id` to `decision-NNNN-<kebab-case-title>`.
4. Open with `status: proposed`. Move it to `accepted` or `rejected` once the discussion ends.
5. When a new record replaces an old one, list the old `id` in the new record's `supersedes`
   property and set the old record's `status` to `superseded`. Leave its body untouched.

| `status` | Meaning |
| --- | --- |
| `proposed` | Written down, not agreed yet. Do not build on it |
| `accepted` | In force. A change that contradicts it needs a new record |
| `rejected` | Considered and turned down. Kept so the option is not raised again blindly |
| `superseded` | Replaced. The record naming it in `supersedes` holds now |

## Related documents

- [Architecture](../index.md)
- [Documentation](../../standards/documentation.md)
