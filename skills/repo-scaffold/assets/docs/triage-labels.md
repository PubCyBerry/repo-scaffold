---
id: standard-triage-labels
title: Triage Labels
type: standard
status: active
summary: Label axes, the meaning of each label, and the file that creates them
scope:
  - "**"
read_when:
  - Triaging an issue
  - Adding or renaming a label
  - Wiring automation that reads a label
sources:
  - .github/labels.yml
  - scripts/apply-github-labels.sh
related:
  - standard-issue-lifecycle
  - standard-pull-request-lifecycle
  - standard-github-enforcement
---

# Triage Labels

## Purpose

Labels are the machine-readable half of the issue and pull request lifecycle. Automation reads
them, so the names are an interface, not decoration.

A label answers exactly one question. Prefer a few orthogonal axes over a pile of overlapping
tags, and prefer a GitHub native state over a label that duplicates it.

## Scope

Every label on an issue or a pull request in this repository.

The label set is defined once in [labels.yml](../../.github/labels.yml) and created by
[apply-github-labels.sh](../../scripts/apply-github-labels.sh). A label that is not in that file
does not exist, and automation that names a missing label fails silently: GitHub drops an unknown
label from an issue form without an error.

## Rules

### Axes

```text
kind/<type>
status/<state>
priority/<level>
area/<component>
policy/<exception-or-control>
lifecycle/<automation-state>
```

### Kind

An issue normally carries exactly one primary `kind/*` label.

| Label | Meaning |
| --- | --- |
| `kind/bug` | Existing behavior is incorrect or broken |
| `kind/feature` | New externally meaningful capability or enhancement |
| `kind/task` | Engineering work that is neither a bug nor a user-facing feature |
| `kind/docs` | Documentation-only work |
| `kind/refactor` | Internal restructuring with no intended behavior change |
| `kind/security` | Security work that is safe to discuss in public |

A vulnerability that is not yet public follows [SECURITY.md](../../SECURITY.md) instead of an
issue.

### Status

Treat `status/*` as a state machine, not as free-form tags. Normally only one is present.

| Label | Meaning | Next actor |
| --- | --- | --- |
| `status/needs-triage` | New or reopened. The project has not decided yet | Triager |
| `status/needs-info` | Blocked on information the reporter has | Reporter |
| `status/accepted` | In scope and defined well enough to implement | Contributor |
| `status/in-progress` | Someone is actively implementing it | Assignee |
| `status/blocked` | Accepted, but an explicit dependency stops progress | Blocker owner |

Do not add `status/done`. The GitHub closed state already carries that.

### Priority

Priority is urgency and scheduling impact, not technical difficulty.

| Label | Meaning | Stale handling |
| --- | --- | --- |
| `priority/p0` | Critical incident or release blocker | Never auto-stale |
| `priority/p1` | Address before normal backlog work | Never auto-stale |
| `priority/p2` | Normal planned priority | Normal policy |
| `priority/p3` | Low priority or opportunistic backlog | Normal policy |

Leave priority unset until the evidence makes the classification meaningful.

### Area

`area/<component>` routes work to the people who own a component. Area labels are
repository-specific, so the shipped label file leaves them out. Add one only for a component
expected to have a persistent stream of work or distinct ownership, never for a one-off
directory.

```text
area/ci
area/docs
area/runtime
area/security
area/tooling
```

### Policy and control

`policy/skip-issue` lets a pull request omit a linked issue when the change is genuinely
trivial: a typo, a mechanical formatting fix, generated-file synchronization, or a routine
automated dependency update. It is a reviewable exception, applied only by someone with triage
or write permission.

Without this label in the repository, the pull request policy check has no escape hatch and
every trivial pull request is blocked with no way out. It is the one label whose absence fails
loudly.

`policy/do-not-merge` is an explicit project hold that keeps a pull request out of the merge
queue even when every check is green. Use draft state for ordinary work in progress; use this
label only for a hold whose reason is not visible from the pull request itself.

### Lifecycle automation

`lifecycle/stale` is added automatically to a `status/needs-info` issue after 30 days without
activity, and removed automatically when activity resumes. It never means an accepted issue has
become obsolete.

### Contribution labels

Use the GitHub conventional names once an issue is groomed enough for an outside contributor.

| Label | Meaning |
| --- | --- |
| `help wanted` | Accepted, with enough context for someone outside the team |
| `good first issue` | A narrower subset, suitable for a first contribution |

A good first issue has clear scope, clear acceptance criteria, low architectural ambiguity,
pointers into the code or documents, and no hidden prerequisite decision.

### Close reasons are not labels

Do not create `status/duplicate`, `status/wontfix`, or `status/done`. Use the GitHub close
reasons instead, so the same lifecycle state is not encoded twice.

```text
Closed: duplicate
Closed: not planned
Closed: completed
```

### Automated transitions

```text
issue form submission        -> kind/* and status/needs-triage
status/needs-info + 30 days  -> lifecycle/stale
lifecycle/stale + 14 days    -> Closed: not planned
activity on a stale issue    -> remove lifecycle/stale
```

Every other transition stays a triage decision, because it depends on human judgment.

### Hygiene

- Avoid synonyms.
- Avoid labels that duplicate an issue form or a GitHub native state.
- Names are the interface. Colors carry no meaning.
- Remove an obsolete label instead of keeping an alias forever.
- Document a label here before any workflow or check reads it.

## Checklist

- Does the new label belong to one of the axes, and answer exactly one question?
- Was it added to [labels.yml](../../.github/labels.yml) before anything read it?
- Was `just labels-check` run so the remote and the file agree?
- Does the issue carry one `kind/*` and one primary `status/*`?
- Is a close reason being expressed as a GitHub close reason rather than a label?

## Related documents

- [Issue Lifecycle](issue-lifecycle.md)
- [Pull Request Lifecycle](pull-request-lifecycle.md)
- [GitHub Enforcement](github-enforcement.md)
- [GitHub Governance Setup](../guides/github-governance-setup.md)

## References

- [Kubernetes issue triage](https://www.kubernetes.dev/docs/guide/issue-triage/)
- [Kubernetes contributor cheatsheet](https://www.kubernetes.dev/docs/contributor-cheatsheet/)
- [CPython labels](https://devguide.python.org/triage/labels/)
- [Managing labels on GitHub](https://docs.github.com/en/issues/using-labels-and-milestones-to-track-work/managing-labels)
