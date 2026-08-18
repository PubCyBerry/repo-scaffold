---
id: standard-github-actions
title: GitHub Actions
type: standard
status: active
summary: SHA-pinned actions, required job names, actionlint and zizmor gates, Renovate ownership
scope:
  - .github/workflows/**
  - renovate.json
read_when:
  - Adding or editing a workflow
  - Adding or bumping an action version
  - Renaming a job that a branch ruleset requires
  - Changing how dependency updates are proposed
  - An actionlint or zizmor finding needs resolving
sources:
  - tests/check-workflows.sh
  - tests/check-yaml.sh
  - renovate.json
related:
  - standard-shell
  - standard-commit-convention
---

# GitHub Actions

## Purpose

A workflow runs with repository credentials on a machine nobody inspects afterwards. Pinning
and auditing are what keep a compromised upstream action from turning into a compromised
repository.

## Scope

Every workflow file under .github/workflows, plus the Renovate configuration that updates them.

## Rules

### Pin actions to a commit SHA

A tag can be moved. A commit SHA cannot.

```yaml
- name: Checkout
  uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1  # v7.0.1
  with:
    persist-credentials: false
```

- Use the full 40-character SHA, with the version as a trailing comment on the same line
- Look the SHA up at the moment you write it. Never copy one from memory
- Set `persist-credentials: false` on checkout unless a later step pushes with that token

Renovate reads the version from a trailing comment only. A comment on the line above leaves
the action pinned to that SHA forever, and nothing reports that it stopped being updated.

Leaving credentials in the runner's local git config means every later step, including any
action you did not audit, can use them.

### Least privilege

- Declare `permissions` at the top of the workflow and grant only what is used. Start from
  `contents: read`
- Never interpolate untrusted input into a `run:` block. Pass it through `env:` and reference
  the variable
- Do not expose a secret to a step that does not need it

### Job names are the contract

A branch ruleset matches required status checks by job name, not by file name. Renaming a job
retires the check that reported under the old name, and every pull request then waits for a
check that never arrives.

| Job | Workflow file | What it runs |
| --- | --- | --- |
| `quality` | quality.yml | `just check`, then `just type` |
| `tests` | test.yml | `just test` |
| `docs` | docs-health.yml | `just docs`, then `just markdown` |
| `security` | security.yml | `just security`, gitleaks, osv-scanner |

A tool version declared in a workflow `env` block is a copy. The original lives in
`tools.txt` or in `pyproject.toml`, and [tests/check-tool-versions.sh](../../tests/check-tool-versions.sh)
fails when the two disagree. A version with no original, such as a release binary this
repository never installs locally, is listed in that script with the reason.

The job name and the file name do not have to match, and two of them do not. The ruleset never
reads a file name.

Every one of them also declares a `merge_group:` trigger. A required check that does not
report inside the merge queue leaves the queue stalled with nothing to say why.

Work that depends on the calendar or on somebody else's server stays out of the pull request
gate. External links and document review intervals run on a schedule, in a job of their own,
because a failure there says nothing about the change under review.

Workflows call the same recipes a person calls. CI does not reimplement a tool invocation in
YAML; if a check cannot be run by hand with one command, the command is the thing to add.

### Audit before committing

| Tool | Purpose | Runs through |
| --- | --- | --- |
| `actionlint` | Workflow syntax, expressions, and embedded shell | check-workflows.sh |
| `zizmor` | Credential persistence, injection, unpinned actions | check-workflows.sh |
| `yamllint` | YAML syntax and formatting | check-yaml.sh |
| `check-jsonschema` | Workflow key structure against the vendored schema | check-yaml.sh |
| `check-jsonschema` | `renovate.json` against the vendored Renovate schema | check-yaml.sh |

[tests/check-workflows.sh](../../tests/check-workflows.sh) is what the `workflow-lint` hook
invokes before each commit, and [tests/check-yaml.sh](../../tests/check-yaml.sh) is what the
`yaml-lint` hook invokes. CI runs both again on every push, because a hook can be skipped.

The formatting rules live in [.yamllint.yaml](../../.yamllint.yaml), not in either script.

A `zizmor` finding is resolved, not silenced. When a finding genuinely does not apply, record
the reason next to the suppression.

### Dependency updates belong to Renovate

[renovate.json](../../renovate.json) is the only place dependency update policy is written.

- Renovate owns `uv.lock`, `package-lock.json`, action SHAs, and the `tools.txt` manifest
- `tools.txt` has no ecosystem manager of its own. A custom regex manager in
  [renovate.json](../../renovate.json) reads the `package==version` column, so Renovate is the
  one tool that can raise those version bumps. Nobody edits that file by hand
- The CI-only binaries pinned in workflow `env:` blocks carry a `# renovate:` annotation. Drop
  the annotation and that tool stops being updated, quietly
- Dependabot stays on for Alerts, which detect vulnerabilities. Version Updates and Security
  Updates stay off, and the repository has no `.github/dependabot.yml`
- `vulnerabilityAlerts` lets Renovate open the fix pull request as well, so a vulnerability
  and an ordinary bump arrive through the same review path
- [tests/check-yaml.sh](../../tests/check-yaml.sh) validates the file against the Renovate
  schema that `check-jsonschema` vendors, so no hook reaches the network. A wrong value type
  is caught there. An unknown key and a misspelled preset name are not, because the schema
  accepts extra properties, and those surface on the Renovate dependency dashboard instead.
  A configuration nobody validates fails by producing zero update pull requests, which looks
  the same as having nothing to update

Two update bots on one repository produce two pull requests for the same bump and no way to
tell which policy won. One owner, one configuration file.

Updates are grouped by ecosystem, scheduled weekly, and held for seven days after release.
The hold keeps a freshly published version from landing the day it appears; the grouping keeps
one pull request per ecosystem instead of one per package. Major updates are never grouped,
because a group hides which member broke the build.

## Checklist

- Is every `uses:` pinned to a full commit SHA with a version comment on the same line?
- Was each SHA looked up rather than recalled?
- Does checkout set `persist-credentials: false`?
- Is `permissions` declared and limited to what the workflow uses?
- Is any untrusted input interpolated directly into a `run:` block?
- Do the job names still match what the branch ruleset requires, including on `merge_group:`?
- Do [tests/check-workflows.sh](../../tests/check-workflows.sh) and
  [tests/check-yaml.sh](../../tests/check-yaml.sh) pass?
- Was a version bumped by hand in a file [renovate.json](../../renovate.json) owns?

## Related documents

- [Shell](shell.md)
- [Commit convention](commit-convention.md)
