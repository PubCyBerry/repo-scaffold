---
id: standard-github-enforcement
title: GitHub Enforcement
type: standard
status: active
summary: Which policy is enforced by GitHub, by CI, and by people
scope:
  - .github/**
  - scripts/**
read_when:
  - Changing a ruleset, a required check, or a repository merge setting
  - Deciding whether a policy should become automation
  - Working out why a merge is blocked
sources:
  - .github/rulesets
  - .github/workflows/pr-policy.yml
  - .github/workflows/stale-needs-info.yml
  - scripts/apply-github-repository-settings.sh
related:
  - standard-issue-lifecycle
  - standard-pull-request-lifecycle
  - standard-review-feedback
  - standard-github-actions
---

# GitHub Enforcement

## Purpose

Automate the objective invariants. Leave the semantic decisions to people.

The goal is not to encode the whole workflow in bots. It is to make bypassing an objective merge
requirement hard, while keeping every judgment call visibly human.

## Scope

The GitHub-side controls of this repository: issue forms, rulesets, required checks, repository
merge settings, and the two governance workflows.

The policies these controls enforce live in [Issue Lifecycle](issue-lifecycle.md),
[Pull Request Lifecycle](pull-request-lifecycle.md), and [Review Feedback](review-feedback.md).

## Rules

### The enforcement map

| Policy | Enforced by | Strength |
| --- | --- | --- |
| Required issue fields | Issue form `validations.required` | Native |
| Initial kind and status labels | Issue form default labels | Native |
| `needs-info` stale timer | `actions/stale`, scoped by label | Automated |
| Non-trivial change needs an issue | `pr-policy` check | CI |
| Description structure | Template plus `pr-policy` check | CI |
| Pull request title as a commit message | `pr-policy` check | CI |
| Review ownership | CODEOWNERS plus ruleset | Native |
| Minimum approvals | Ruleset | Native |
| Blocking review prevents merge | `Request changes` plus ruleset | Native |
| Review threads resolved | Ruleset | Native |
| Force-push to the default branch | Ruleset non-fast-forward rule | Native |
| No history rewrite after review | Contributor policy | Normative |
| Squash-only merge | Repository setting plus ruleset | Native |
| Title and body as the squash commit | Repository setting | Native |
| Merge queue | Ruleset | Native |
| CI against the queued result | `merge_group` trigger | Native and CI |
| Severity markers on comments | Review standard | Normative |

### What a bot can and cannot decide

A bot can answer whether an issue is linked, whether the checks passed, whether a code owner
approved, whether a conversation is unresolved, and whether the merge method is squash.

A bot cannot answer whether the architecture is appropriate, whether a comment is truly blocking,
or whether an issue is worth accepting. Those stay human, and the automation is deliberately
built so it never has to guess.

### Issue forms

The three forms under [ISSUE_TEMPLATE](../../.github/ISSUE_TEMPLATE/config.yml) make required
fields actually required and give every new issue a predictable starting state.

```text
bug.yml     -> kind/bug     + status/needs-triage
feature.yml -> kind/feature + status/needs-triage
task.yml    -> kind/task    + status/needs-triage
```

Blank issues are disabled, because a blank issue starts with no kind and no triage state and
therefore never enters the lifecycle.

Those labels have to exist first. GitHub drops an unknown label from a form silently, with no
error anywhere, so the lifecycle would simply never start. The label set is
[labels.yml](../../.github/labels.yml).

### Stale automation

There is no global rule that inactivity means obsolescence. Only `status/needs-info` is eligible,
because that is the one state where the requester, not the project, is the blocker.

```text
30 days   -> lifecycle/stale
14 more   -> close as not planned
```

`priority/p0`, `priority/p1`, `status/blocked`, `status/accepted`, `status/in-progress`, and any
milestone-bound issue are exempt. The workflow is
[stale-needs-info.yml](../../.github/workflows/stale-needs-info.yml).

### The issue-link gate

CPython's Bedevere bot is the precedent: it fails a status check when a pull request carries no
issue number, and offers a skip label for trivial changes. The same policy here is a
repository-local check.

```text
body contains Closes #123, Fixes #123, or Resolves #123
OR
pull request carries policy/skip-issue
```

### The description gate

GitHub offers pull request templates but cannot require that a section is filled in. The
`pr-policy` check therefore validates the repository's own description contract: the nine
sections exist, and each one still has content once the template comments are stripped. `N/A` is
a valid answer.

This is repository-specific enforcement rather than a universal convention, so the check stays
simple and deterministic and lives in a script with unit tests rather than inline in a workflow.

### The title gate

The repository squashes on merge and takes the squash commit title from the pull request title.
That string becomes the default branch history, and the local commit-msg hook never sees it: the
hook validates branch commits, which the squash discards.

Without a title check, "Conventional Commits are enforced" would be true of every commit except
the only ones that survive. `pr-policy` therefore validates the title as a Conventional Commits
header, with the same rules the local hook applies to branch commits.

### CODEOWNERS and the review gate

Use GitHub-native CODEOWNERS rather than rebuilding a review-routing bot. The baseline is one
approval, code owner review required for owned paths, stale approvals dismissed on new
reviewable commits, and conversation resolution required.

For a one-person repository, that baseline makes every self-authored pull request unmergeable.
The default ruleset ships without it, and the team ruleset is adopted when a second reviewer
exists.

### Force-push boundary

Repository rules govern the default branch. They cannot reliably govern a pull request branch,
which may live in a fork.

```text
default branch      -> force-push prohibited by the ruleset
pull request branch -> preserved by reviewer policy
```

The reviewer-facing half of that rule is in [Review Feedback](review-feedback.md).

### Squash-only merge, enforced twice

The repository settings disable merge commits and rebase merges and set the squash title and
body defaults. The ruleset independently restricts the allowed merge methods to `squash`. Two
independent controls mean one accidental settings change does not reopen the other paths.

[apply-github-repository-settings.sh](../../scripts/apply-github-repository-settings.sh) applies
the settings half. It shows the current and intended values and changes nothing without
`--apply`.

### Merge queue and `merge_group`

The default branch merges through the GitHub merge queue, which revalidates each entry against
the latest default branch and the entries ahead of it. This is the same idea as bors in Rust or
Tide in Kubernetes, built into GitHub.

Every required check must therefore report on `merge_group`. A check that only listens for
`pull_request` leaves the queue waiting for a status that never arrives.

`pr-policy` emits the same job name on both events. On `merge_group` it succeeds without
re-reading the pull request prose, because that contract was already validated before the entry
joined the queue.

### Required check names are job names

A ruleset matches required checks by job name, not by file name. Renaming a job silently
disconnects it from the ruleset, and every pull request then waits forever for a check that no
longer reports under that name.

| Workflow | Job name |
| --- | --- |
| [pr-policy.yml](../../.github/workflows/pr-policy.yml) | `pr-policy` |
| [quality.yml](../../.github/workflows/quality.yml) | `quality` |
| [test.yml](../../.github/workflows/test.yml) | `tests` |
| [docs-health.yml](../../.github/workflows/docs-health.yml) | `docs` |
| [security.yml](../../.github/workflows/security.yml) | `security` |

### Two ruleset examples

Both files under [rulesets](../../.github/rulesets/default-branch.example.json) are
API-shaped starting points, not configuration this repository applies on its own. The default
one assumes a single maintainer, which is the common case for a repository on its first day.

| | Default | Team |
| --- | --- | --- |
| Required approvals | 0 | 1 |
| Code owner review | Not required | Required |
| Bypass actors | Repository admin | None |
| Merge queue | Off | On |
| Everything else | Same | Same |

The default example is the one without a review requirement because the team baseline locks a
single owner out of their own repository: with no second account, one required approval can
never be satisfied, and a code owner cannot approve their own pull request. Deletion protection,
force-push protection, linear history, squash-only merge, and the required checks all still
apply in the default example, so the only thing given up is the second pair of eyes that does
not exist yet.

### Adopting a ruleset

1. Replace the required check names with the job names this repository actually runs.
2. Run each of those checks at least once so GitHub recognizes the name.
3. Put a real CODEOWNERS file in place before requiring code owner review.
4. Confirm the repository plan and ownership support the merge queue.
5. Confirm an administrator bypass path exists if governance requires one.
6. Apply it and watch one non-critical pull request go through.

Do not promote a check to required until it has reported successfully on both `pull_request` and
`merge_group`. A required check that has never reported blocks every pull request, including the
one that would fix it.

### What stays human

Accepting or rejecting an issue, assigning priority, judging whether a bug reproduces, judging
whether a design is sound, deciding the severity of feedback, granting an issue-link exception,
and deciding whether an unusual history rewrite is justified.

## Checklist

- Does every required check name match a job name that actually reports?
- Does every required workflow trigger on `merge_group` as well as `pull_request`?
- Does every label used by a form or a workflow exist in [labels.yml](../../.github/labels.yml)?
- Is the ruleset chosen for the number of reviewers this repository actually has?
- Was a CODEOWNERS file put in place before code owner review became required?
- Did any remote-changing script run in its default read-only mode first?

## Related documents

- [Issue Lifecycle](issue-lifecycle.md)
- [Pull Request Lifecycle](pull-request-lifecycle.md)
- [Review Feedback](review-feedback.md)
- [GitHub Actions](github-actions.md)
- [GitHub Governance Setup](../guides/github-governance-setup.md)

## References

- [Available rules for rulesets](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/available-rules-for-rulesets)
- [Managing a merge queue](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/configuring-pull-request-merges/managing-a-merge-queue)
- [Events that trigger workflows](https://docs.github.com/en/actions/using-workflows/events-that-trigger-workflows)
- [About code owners](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/about-code-owners)
- [Repository REST API](https://docs.github.com/en/rest/repos/repos)
- [Rules REST API](https://docs.github.com/en/rest/repos/rules)
- [CPython Bedevere](https://github.com/python/bedevere)
- [Kubernetes OWNERS](https://www.kubernetes.dev/docs/guide/owners/)
