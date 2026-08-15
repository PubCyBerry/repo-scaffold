---
id: standard-github-actions
title: GitHub Actions
type: standard
status: active
summary: SHA-pinned actions, credential handling, actionlint and zizmor gates, Dependabot configuration
scope:
  - .github/workflows/**
  - .github/dependabot.yml
read_when:
  - Adding or editing a workflow
  - Adding or bumping an action version
  - Configuring Dependabot
  - An actionlint or zizmor finding needs resolving
related:
  - standard-shell
  - standard-commit-convention
---

# GitHub Actions

## Purpose

A workflow runs with repository credentials on a machine nobody inspects afterwards. Pinning and auditing are what keep a compromised upstream action from turning into a compromised repository.

## Scope

Every workflow file under .github/workflows, plus the Dependabot configuration.

## Rules

### Pin actions to a commit SHA

A tag can be moved. A commit SHA cannot.

```yaml
- name: Checkout
  uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1  # v7.0.1
  with:
    persist-credentials: false
```

- Use the full 40-character SHA, with the version as a trailing comment
- Look the SHA up at the moment you write it. Never copy one from memory
- Set `persist-credentials: false` on checkout unless a later step pushes with that token

Leaving credentials in the runner's local git config means every later step, including any action you did not audit, can use them.

### Least privilege

- Declare `permissions` at the top of the workflow and grant only what is used. Start from `contents: read`
- Never interpolate untrusted input into a `run:` block. Pass it through `env:` and reference the variable
- Do not expose a secret to a step that does not need it

### Audit before committing

| Tool | Purpose |
| --- | --- |
| `actionlint` | Workflow syntax, expressions, and embedded shell |
| `zizmor` | Security audit: credential persistence, injection, unpinned actions |

Both run over the workflow directory through [tests/check-workflows.sh](tests/check-workflows.sh), which the `workflow-lint` hook invokes before each commit and CI runs on every push.

A `zizmor` finding is resolved, not silenced. When a finding genuinely does not apply, record the reason next to the suppression.

### Dependabot

Configure Dependabot with a 7-day cooldown and grouped updates. The cooldown keeps a freshly published release from landing the day it appears; grouping keeps one pull request per ecosystem instead of one per package.

For Python projects, use the `uv` ecosystem rather than `pip` so Dependabot updates `uv.lock`.

## Checklist

- Is every `uses:` pinned to a full commit SHA with a version comment?
- Was each SHA looked up rather than recalled?
- Does checkout set `persist-credentials: false`?
- Is `permissions` declared and limited to what the workflow uses?
- Is any untrusted input interpolated directly into a `run:` block?
- Does [tests/check-workflows.sh](tests/check-workflows.sh) pass?
- Does Dependabot use a 7-day cooldown and grouped updates?

## Related documents

- [Shell](docs/standards/shell.md)
- [Commit convention](docs/standards/commit-convention.md)
