---
id: standard-issue-lifecycle
title: Issue Lifecycle
type: standard
status: active
summary: Issue states, triage checklist, acceptance meaning, stale handling
scope:
  - "**"
read_when:
  - Filing an issue
  - Triaging a new report
  - Deciding whether a change needs an issue before a pull request
sources:
  - .github/ISSUE_TEMPLATE
  - .github/workflows/stale-needs-info.yml
related:
  - standard-triage-labels
  - standard-pull-request-lifecycle
  - standard-github-enforcement
---

# Issue Lifecycle

## Purpose

An issue is the durable record of what problem should be solved, why it matters, what is in
scope, and how completion will be recognized.

Implementation details change while the work is done. The issue stays the stable problem
contract, so a reader six months later can tell what was agreed without reading the diff.

## Scope

Every issue in this repository, and the decision of whether a change needs one at all.

Label names and their meanings are in [Triage Labels](triage-labels.md). What happens after an
issue is accepted is in [Pull Request Lifecycle](pull-request-lifecycle.md).

## Rules

### The state machine

```text
New
 |
 v
status/needs-triage
 |
 +--> duplicate ----------------------------> Closed: duplicate
 |
 +--> not accepted / out of scope ----------> Closed: not planned
 |
 +--> status/needs-info
 |       |
 |       +-- reporter responds -------------> status/needs-triage
 |       |
 |       +-- 30d inactive -> lifecycle/stale
 |                    |
 |                    +-- activity ----------> remove lifecycle/stale
 |                    |
 |                    +-- 14d inactive ------> Closed: not planned
 |
 v
status/accepted
 |
 v
status/in-progress
 |
 +--> status/blocked
 |       |
 |       +-- unblocked ----------------------> status/in-progress
 |
 v
Linked pull request
 |
 v
Pull request merged
 |
 v
Closed: completed
```

Carry only one primary `status/*` label at a time.

### When an issue is required

Open an issue before implementation for work that needs agreement or durable tracking:

- bugs;
- features and enhancements;
- behavior changes;
- architecture changes;
- public API, configuration, schema, or compatibility changes;
- non-trivial refactors;
- new repository policies;
- multi-pull-request initiatives.

The test is whether the work needs agreement or durable tracking, not how large the diff is.

### When an issue may be skipped

Skip the issue only for changes that gain nothing from separate discussion:

- spelling or typo corrections;
- unambiguous documentation corrections;
- mechanical formatting fixes;
- generated-file synchronization;
- routine automated dependency updates.

A pull request that skips the issue must carry `policy/skip-issue`. Only someone with triage or
write permission grants that exception.

### Issue kinds

Use the repository issue forms. Each one applies its kind label and `status/needs-triage`.

| Form | Kind label |
| --- | --- |
| Bug report | `kind/bug` |
| Feature request | `kind/feature` |
| Engineering task | `kind/task` |

Triage may add further kind labels when the report turns out to be something else.

### Triage

Triage every new issue before it is treated as committed work.

1. Read the report and the existing discussion.
2. Search for a duplicate.
3. Improve the title when it is vague.
4. Confirm the issue belongs in this repository.
5. For a bug, decide whether it reproduces or can otherwise be validated.
6. Confirm there is enough information to decide.
7. Apply the `kind/*` label.
8. Apply the `area/*` label when the component is known.
9. Apply priority once the evidence supports a classification.
10. Identify blockers, dependencies, or sub-issues.
11. Choose the next state: `status/accepted`, `status/needs-info`, `status/blocked`, or close as
    duplicate or not planned.
12. Leave a short next-action comment when the next step is not obvious.

### What acceptance means

`status/accepted` says the problem is understood well enough to proceed, the work is in scope,
and the desired outcome is clear enough to build against. It promises no delivery date.

### Assignees

The assignee is the person expected to take the next material step. Do not assign a maintainer
merely because they own the component. Leave the issue unassigned when nobody is driving it.

### Starting and blocking work

Move `status/accepted` to `status/in-progress` when implementation begins, and assign the
implementer. When an external dependency stops progress, move to `status/blocked`, record the
blocker in the issue, and use the GitHub issue relationship when one is available.

### Large work

Use a parent issue with sub-issues when one problem needs several independently reviewable
changes.

```text
#100 Repository governance
├── #101 Issue lifecycle
├── #102 Pull request policy
├── #103 Review policy
└── #104 Merge governance
```

Use blocked-by and blocking relationships for real ordering dependencies. Do not create a
sub-issue for a checklist item that needs no separate owner or discussion.

### Linking a pull request

A non-trivial pull request links its primary issue with a closing keyword in the description.

```text
Closes #123
Fixes #123
Resolves #123
```

The issue keeps the problem record. The pull request owns implementation and evidence.

### Completing an issue

Let the merge close the issue.

```text
Issue -> pull request with a closing keyword -> merge -> GitHub closes as completed
```

Do not close an implementation issue by hand right before merging its pull request.

### Duplicate and rejected work

Use the GitHub close reasons rather than labels.

| Reason | Use when |
| --- | --- |
| duplicate | Another issue is the canonical record. Link it |
| not planned | The project decided against the work. Record why |
| completed | The requested outcome shipped |

### Stale handling

Automatic stale handling is deliberately narrow. Only `status/needs-info` is eligible, because
that is the state where the reporter, not the project, is the blocker.

```text
30 days without activity  -> add lifecycle/stale and post a warning
14 more days without activity -> close as not planned
```

Activity removes `lifecycle/stale` and restarts the clock. An issue is never auto-closed while
it carries `priority/p0`, `priority/p1`, `status/blocked`, `status/accepted`, or
`status/in-progress`, and milestone-bound issues are exempt as well.

When the requested information arrives, a triager re-evaluates and moves the issue out of
`status/needs-info`, normally back to `status/needs-triage`.

## Checklist

- Does the change need agreement or durable tracking, and therefore an issue?
- Was the issue filed through an issue form so it carries a kind and a triage state?
- Does the issue carry exactly one primary `status/*` label?
- Was triage completed before the issue was treated as committed work?
- Does the linked pull request use a closing keyword, or carry `policy/skip-issue`?
- When closing without delivery, is the reason recorded for a future reader?

## Related documents

- [Triage Labels](triage-labels.md)
- [Pull Request Lifecycle](pull-request-lifecycle.md)
- [GitHub Enforcement](github-enforcement.md)
- [Commit Convention](commit-convention.md)

## References

- [Kubernetes issue triage](https://www.kubernetes.dev/docs/guide/issue-triage/)
- [CPython triage checklist](https://devguide.python.org/triage/triaging/)
- [CPython issue tracker relationships](https://devguide.python.org/triage/issue-tracker/)
- [GitHub issue forms syntax](https://docs.github.com/en/communities/using-templates-to-encourage-useful-issues-and-pull-requests/syntax-for-issue-forms)
