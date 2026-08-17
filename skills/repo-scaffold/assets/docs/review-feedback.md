---
id: standard-review-feedback
title: Review Feedback
type: standard
status: active
summary: Severity markers, GitHub review decisions, branch history after review begins
scope:
  - "**"
read_when:
  - Writing a review comment
  - Choosing between Comment, Request changes, and Approve
  - Updating a branch that is already under review
related:
  - standard-code-review
  - standard-pull-request-lifecycle
  - standard-github-enforcement
---

# Review Feedback

## Purpose

Two reviewers can agree on a problem and still disagree on whether it blocks a merge. That
disagreement is the expensive one, and it is entirely avoidable: say the severity out loud.

This document fixes how a review comment declares severity, what that severity means for the
GitHub review decision, and what the author may do to the branch once review has begun.

## Scope

Every review comment and every review decision in this repository, by a person or an agent.

How to conduct the review, and in what order, is in [Code Review](code-review.md).

## Rules

### Severity markers

Every review comment that asks for or proposes a change opens with one marker.

| Marker | Meaning | Merge effect |
| --- | --- | --- |
| `[blocking]` | Must be resolved before merge | Blocks |
| `[suggestion]` | A better approach exists, current one is acceptable | Does not block |
| `[question]` | The reviewer cannot judge yet without an answer | Does not block by itself |
| `[nit]` | Optional polish with no effect on merge readiness | Does not block |

Use `[blocking]` for correctness defects, security defects, data-loss or compatibility risk,
missing required tests, a violation of an accepted architecture or repository invariant, or a
change that fails its own stated acceptance criteria.

```text
[blocking] This error path leaves the lock held, so a timeout blocks every later request.
Release it in a finally block and add a regression test.
```

```text
[suggestion] Extracting this normalization into the existing helper would make the two backends
consistent. A follow-up is fine if you want to keep this change small.
```

```text
[question] Is this intentionally allowed to retry non-idempotent requests? I could not find that
in the linked issue.
```

```text
[nit] `result_count` reads better than `n` here.
```

A `[question]` becomes blocking only when the reviewer says so explicitly. A `[nit]` never
becomes a merge condition when the tooling and the style standard already accept the code.

### Mapping to GitHub review decisions

The marker is a human convention. The GitHub decision is the part the merge gate understands, so
the two must not drift apart.

| GitHub decision | Use when |
| --- | --- |
| Comment | Only questions, suggestions, or nits remain |
| Request changes | At least one unresolved `[blocking]` comment exists |
| Approve | No merge blocker remains and the change is acceptable to merge |

Approving does not mean the reviewer expects every suggestion to be implemented. Requesting
changes without a `[blocking]` comment leaves the author guessing what has to change.

### Writing a comment worth reading

A comment carries the marker, the concrete problem, why it matters, and a direction when one is
known.

```text
[blocking] This validates the path before symlink resolution, so the resolved target can escape
the workspace. Validate the resolved path against the workspace root instead.
```

Not:

```text
[blocking] This is unsafe.
```

State the invariant that must hold rather than demanding one specific implementation when
several correct ones exist.

### Answering feedback

For every blocking thread the author does one of three things: make the change, explain why a
different solution satisfies the concern, or say plainly that they disagree and why. Silently
resolving a blocking conversation is none of the three.

After feedback changes behavior, rerun the affected tests and `just verify`.

### Branch history after review begins

Once substantive review has started, preserve what the reviewer already read.

| Phase | Allowed |
| --- | --- |
| Before the first substantive review | Rebase and `--force-with-lease` are fine |
| After substantive review begins | Focused follow-up commits only |

After review begins, do not force-push, squash branch commits, amend reviewed commits, or rebase
merely to tidy the history. Each of those detaches the review comments from the code they were
written against, and the reviewer loses the ability to read only the delta since last time.

Branch history is not worth protecting for its own sake here: the merge squashes it. Review
context is.

### The exception

Rewrite history after review only when it is materially necessary: an otherwise impractical
conflict, removal of an accidentally committed secret, or an explicit reviewer request. Say in
the pull request that the rewrite happened and why.

### What is not automated

No check rejects a comment for lacking a marker. Review conversation contains prose, replies,
and bot messages where a marker would be artificial, and a check that produces false positives
teaches everyone to ignore it.

What the repository enforces instead is the consequence GitHub already understands: an active
`Request changes` review blocks the merge, and unresolved required conversations block the merge.
The rest of the enforcement map is in [GitHub Enforcement](github-enforcement.md).

## Checklist

- Does every change-requesting comment open with a severity marker?
- Does the GitHub decision match the strongest marker used?
- Does each blocking comment say what is wrong, why, and which invariant must hold?
- Did the author answer every blocking thread rather than resolving it silently?
- Since review began, has the branch only gained focused follow-up commits?
- If history was rewritten, is the reason recorded in the pull request?

## Related documents

- [Code Review](code-review.md)
- [Pull Request Lifecycle](pull-request-lifecycle.md)
- [GitHub Enforcement](github-enforcement.md)
- [Writing Style](writing-style.md)

## References

- [Google engineering practices, what to look for](https://google.github.io/eng-practices/review/reviewer/looking-for.html)
- [Google engineering practices, the standard of review](https://google.github.io/eng-practices/review/reviewer/standard.html)
- [CPython pull request lifecycle](https://devguide.python.org/getting-started/pull-request-lifecycle/)
- [Home Assistant review process](https://developers.home-assistant.io/docs/review-process/)
