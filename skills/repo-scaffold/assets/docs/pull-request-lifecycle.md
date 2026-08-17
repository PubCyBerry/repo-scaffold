---
id: standard-pull-request-lifecycle
title: Pull Request Lifecycle
type: standard
status: active
summary: Description contract, readiness gate, merge method, merge queue behavior
scope:
  - "**"
read_when:
  - Opening a pull request
  - Filling in the pull request description
  - Deciding whether a pull request is ready to merge
sources:
  - .github/pull_request_template.md
  - .github/workflows/pr-policy.yml
  - scripts/check_pr_metadata.py
related:
  - standard-issue-lifecycle
  - standard-review-feedback
  - standard-github-enforcement
  - standard-commit-convention
---

# Pull Request Lifecycle

## Purpose

A pull request is the reviewable implementation record for one logical change. The linked issue
owns the problem and the acceptance criteria; the pull request owns the implementation, the
tests, the migration work, the documentation, the evidence, and the review discussion.

## Scope

Every pull request in this repository, from the first commit to the merge queue.

How to review one is in [Code Review](code-review.md). How feedback is phrased and what it does
to branch history is in [Review Feedback](review-feedback.md).

## Rules

### The lifecycle

```text
Issue accepted
      |
      v
Create branch  ->  Implementation  ->  Draft pull request (optional, for early feedback)
      |
      v
just verify
      |
      v
Ready for review  ->  Required CI  ->  Human review
      |                                   |
      |                       Approve  <--+-->  Request changes
      |                          |                   |
      |                          |            Author update, focused commits, just verify
      |                          |                   |
      |                          |            Ready again ---> back to review
      v                          v
Merge-ready  ->  Merge queue  ->  CI on merge_group  ->  Squash and merge
      |
      v
Delete branch  ->  Linked issue closes
```

### When to open one

Open a normal pull request when the implementation is reviewable, the tests are present, the
documentation is updated, and `just verify` passes locally.

Open a draft earlier only when early feedback has concrete value: the architecture direction
needs a second opinion, CI-only behavior must be observed, the change needs coordination, or a
large change benefits from early scope validation. A draft cannot enter the merge queue. Do not
open an empty placeholder pull request to announce that work started.

### Scope of one pull request

One pull request carries one logical change. Do not combine unrelated refactors, features, bug
fixes, formatting churn, dependency bumps, and documentation cleanup. If two changes could be
reviewed, reverted, or shipped independently, split them.

### The description contract

Every pull request uses the repository template and fills all nine sections.

| # | Section | Contains |
| --- | --- | --- |
| 1 | Summary | What the change does, concretely |
| 2 | Motivation | The problem or outcome behind it |
| 3 | Linked issue | A closing keyword, or the reason it is exempt |
| 4 | Changes | The implementation changes that matter |
| 5 | Scope / Non-goals | What this change deliberately does not do |
| 6 | Validation | Real evidence: commands, tests, manual checks |
| 7 | Risk / Compatibility | Regression, security, migration, API, schema, performance |
| 8 | Documentation | What documentation changed, or why none was needed |
| 9 | Reviewer focus | The highest-risk part, or the unresolved trade-off |

A section that does not apply says `N/A` and, when it helps, why. An empty section is a failure,
not an omission: [check_pr_metadata.py](../../scripts/check_pr_metadata.py) strips the template
comments and rejects a section with nothing left.

### The title is the commit message

The repository merges by squash, and the squash commit title defaults to the pull request title.
The title is therefore the message that lands on the default branch, and the local commit-msg
hook never sees it.

The title follows [Commit Convention](commit-convention.md) in full: a Conventional Commits
header, at most 100 characters, with a subject that starts lowercase.

```text
feat(auth): add refresh token rotation
fix: reject empty workspace paths
```

The pull request policy check validates the title, which is the only place that rule can be
enforced for the default branch history.

### Linked issue

Non-trivial work links its issue with a closing keyword in the description.

```text
Closes #123
```

A trivial pull request may omit the issue only when a maintainer or triager applies
`policy/skip-issue`. Both paths are checked; neither is optional.

### Before marking ready for review

The author self-reviews the diff, removes accidental changes, updates the tests and the
documents, runs `just verify`, makes the description current, and names a specific reviewer
focus when a non-obvious risk or design choice exists.

CI is part of review. It is not a substitute for the author having verified the change.

### The merge-ready gate

A pull request enters the merge queue only when all of these hold.

- It is not a draft.
- A linked issue exists, or `policy/skip-issue` was applied.
- The pull request policy check passes.
- Required CI checks pass.
- The required approvals exist, including code owner approval for owned paths.
- No `Request changes` review is still active.
- Required review conversations are resolved.
- There is no `policy/do-not-merge` hold.
- There is no unresolved merge conflict.

### Merge method

Squash merge only. Merge commits and rebase merges stay disabled, at the repository setting and
again in the branch ruleset, so a single setting change cannot open the other paths.

```text
commit title = pull request title
commit body  = pull request description
```

### Merge queue

A merge-ready pull request enters the GitHub merge queue rather than merging directly. The queue
revalidates it against the latest default branch and against the pull requests ahead of it.

Every required workflow therefore triggers on both events.

```yaml
on:
  pull_request:
  merge_group:
```

A required check that never reports on `merge_group` stalls the queue forever. The queue merge
method is `squash`, matching the repository setting.

### After merge

Delete the branch when it is safe, let the closing keyword close the issue, and take follow-up
work to a new issue or pull request rather than reopening the merged one.

### Closing without merging

Closing a pull request is a normal outcome, not a failure. An open pull request is a proposal.
Close it when the design is rejected, another change supersedes it, it duplicates work that
already landed, the author steps away, or the approach turns out to be unsuitable. Leave a short
reason and link whatever replaced it.

## Checklist

- Does the pull request carry one logical change?
- Are all nine description sections filled with something real?
- Is the title a Conventional Commits header with a lowercase subject?
- Does the description link an issue with a closing keyword, or carry `policy/skip-issue`?
- Did `just verify` pass before the pull request was marked ready?
- Does every required workflow trigger on `merge_group` as well as `pull_request`?
- Is the merge method squash, at both the repository setting and the ruleset?

## Related documents

- [Issue Lifecycle](issue-lifecycle.md)
- [Code Review](code-review.md)
- [Review Feedback](review-feedback.md)
- [GitHub Enforcement](github-enforcement.md)
- [Commit Convention](commit-convention.md)

## References

- [CPython pull request lifecycle](https://devguide.python.org/getting-started/pull-request-lifecycle/)
- [Kubernetes pull request process](https://www.kubernetes.dev/docs/guide/pull-requests/)
- [Home Assistant review process](https://developers.home-assistant.io/docs/review-process/)
- [Rust contribution process](https://rustc-dev-guide.rust-lang.org/contributing.html)
- [Managing a merge queue](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/configuring-pull-request-merges/managing-a-merge-queue)
- [Configuring commit squashing](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/configuring-pull-request-merges/configuring-commit-squashing-for-pull-requests)
