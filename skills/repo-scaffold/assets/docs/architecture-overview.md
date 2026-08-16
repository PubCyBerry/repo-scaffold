---
id: reference-architecture-overview
title: Architecture Overview
type: reference
status: active
summary: Components, boundaries, data flow, external dependencies
scope:
  - docs/architecture/**
read_when:
  - Before adding a component or moving a boundary
  - When tracing how a request crosses the system
related:
  - index-architecture
---

# Architecture Overview

## Purpose

Describe the shape of {{REPO_NAME}} as it stands: what the parts are, where the boundaries
run, and which parts this repository does not own.

Reasoning does not belong here. This document answers "what", and a
[decision record](adr/index.md) answers "why". Splitting them means the overview can be
rewritten whenever the code moves without disturbing the record of past choices.

## Scope

The repository as a whole, at the level of components and the lines between them. A procedure
for running one component belongs in that component's README.

## Summary

Fill this table in on the first pass. One row per component.

| Component | Responsibility | Owns | Talks to |
| --- | --- | --- | --- |
| Fill in | Fill in | Fill in | Fill in |

## Details

### Components

One heading per component. State what it is responsible for and, more usefully, what it is
not responsible for.

### Boundaries

A boundary is a place where one side can be replaced without the other side changing. Name
the contract that holds at each one: a function signature, a wire format, a database schema,
a queue message.

### Data flow

Trace one representative request or job from entry to result. Name the components it passes
through in order. Prefer a single worked example over an abstract diagram.

### External dependencies

Everything this repository calls but does not own: managed services, other teams' APIs,
vendor libraries with a hard version floor. For each one, record what happens when it is
unavailable.

## Keeping this document honest

Add the paths this document describes to the `sources` property in the front matter above,
then set `last_reviewed` on the day a person reads it and confirms it. From then on
[tests/check-docs-metadata.sh](../../tests/check-docs-metadata.sh) reports the document as
drifted whenever one of those paths changes after that date. The rule is in
[Documentation](../standards/documentation.md).

## Related documents

- [Architecture](index.md)
- [Decision Records](adr/index.md)
- [Documentation](../standards/documentation.md)
