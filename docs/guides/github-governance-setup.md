---
id: guide-github-governance-setup
title: GitHub Governance Setup
type: guide
status: active
summary: Activation order for labels, code owners, workflows, merge settings, and a ruleset
scope:
  - .github/**
  - scripts/**
read_when:
  - Turning on the issue and pull request governance in a new repository
  - Reapplying the governance settings after a repository move
sources:
  - scripts/apply-github-labels.sh
  - scripts/apply-github-repository-settings.sh
  - .github/rulesets
related:
  - standard-github-enforcement
  - standard-triage-labels
  - standard-pull-request-lifecycle
---

# GitHub Governance Setup

## Purpose

The governance files land in the repository inert. Issue forms, a pull request template, a
CODEOWNERS example, two ruleset examples, and two workflows do nothing until the labels exist,
the merge settings are applied, and a ruleset is adopted.

This is the order that works, and the reason each step comes where it does.

## Scope

A repository that has the governance files but has not yet been configured on the GitHub side.

The rules being activated are in [GitHub Enforcement](../standards/github-enforcement.md). This
guide only turns them on.

## Prerequisites

- Admin permission on the repository.
- The GitHub CLI, authenticated.

```bash
gh --version
gh auth status
```

Install it from [cli.github.com](https://cli.github.com) if it is missing. The scripts report the
install command rather than guessing a package manager.

- A decision about which ruleset applies. The default fits a repository with one maintainer.
  Pick the team ruleset only when a second account can approve a pull request. That is a fact
  about how many people can approve, and it cannot be deferred, because the wrong answer locks
  the repository.

## Procedure

### 1. Read the standards

Read [Issue Lifecycle](../standards/issue-lifecycle.md),
[Triage Labels](../standards/triage-labels.md),
[Pull Request Lifecycle](../standards/pull-request-lifecycle.md), and
[GitHub Enforcement](../standards/github-enforcement.md) before changing any setting. Each
setting below exists to enforce something written there.

### 2. Create the labels

Labels come first. Every later step names one, and a missing label fails in three different ways:
an issue form drops it without an error, the stale workflow matches nothing and reports success
every day, and the pull request policy check has no `policy/skip-issue` escape hatch, which
blocks every trivial pull request from the first day.

```bash
bash scripts/apply-github-labels.sh            # dry run. shows create, update, extra
bash scripts/apply-github-labels.sh --apply    # creates and updates
```

The source of truth is [labels.yml](../../.github/labels.yml). The script never deletes a label
it did not expect; it reports it and leaves the decision to a person.

### 3. Put code owners in place

```bash
cp .github/CODEOWNERS.example .github/CODEOWNERS
```

Replace every placeholder with a real user or team, and commit it. Until this file names valid
owners, do not require code owner review anywhere: an unresolvable owner requirement blocks every
pull request touching that path.

### 4. Merge the issue forms, template, and workflows

They are already in the repository. Confirm that
[pr-policy.yml](../../.github/workflows/pr-policy.yml) and
[stale-needs-info.yml](../../.github/workflows/stale-needs-info.yml) appear under the repository
Actions tab, and that a test issue opened from a form arrives with its kind and triage labels.

### 5. Apply the repository merge settings

```bash
bash scripts/apply-github-repository-settings.sh          # shows current vs intended
bash scripts/apply-github-repository-settings.sh --apply
```

This enables squash merge, disables merge commits and rebase merges, sets the squash title to the
pull request title and the body to the pull request description, enables auto-merge, and deletes
the head branch after a merge.

The squash title setting is why the pull request title is validated as a commit message. From
here on, the title is the default branch history.

### 6. Choose and adapt a ruleset

| File | Use when |
| --- | --- |
| [default-branch.example.json](../../.github/rulesets/default-branch.example.json) | One person can approve. This is the default |
| [default-branch.team.example.json](../../.github/rulesets/default-branch.team.example.json) | Two or more can approve |

Before applying either one:

1. Replace the required status check names with the job names this repository actually runs.
2. Run each of those jobs at least once so GitHub recognizes the name.
3. Confirm CODEOWNERS can approve the paths the ruleset covers.
4. Confirm the repository plan supports the merge queue. A private repository needs a Team or
   Enterprise plan; the default example leaves the queue off for that reason.

### 7. Apply the ruleset

```bash
gh api --method POST \
  -H "Accept: application/vnd.github+json" \
  "repos/OWNER/REPO/rulesets" \
  --input .github/rulesets/default-branch.example.json
```

Do this by hand. No script in this repository applies a ruleset, because getting it wrong locks
the default branch and the fix requires the same admin access that the mistake just made
awkward to use.

## Verification

Confirm each of these before treating the setup as done.

```bash
bash scripts/apply-github-labels.sh --check     # exits non-zero on drift
gh repo view --json squashMergeAllowed,mergeCommitAllowed,rebaseMergeAllowed
gh api "repos/OWNER/REPO/rulesets"
```

- Every label in [labels.yml](../../.github/labels.yml) exists on the remote with the same color
  and description.
- Squash is the only allowed merge method.
- An issue opened from each form arrives with its kind label and `status/needs-triage`.
- A pull request with an incomplete description fails the `pr-policy` check.
- A pull request with a capitalized title fails the same check.
- Every required check has reported at least once on both `pull_request` and `merge_group`.

## Troubleshooting

| Symptom | Cause | Action |
| --- | --- | --- |
| A pull request waits forever on a required check | The ruleset names a job that never reports | Match the required name to the job name |
| The merge queue never starts a check | The workflow has no `merge_group:` trigger | Add the trigger and rerun once |
| A new issue arrives with no labels | The labels do not exist yet | Run the label script, then reopen the issue |
| The stale workflow is green but does nothing | `status/needs-info` does not exist | Run the label script |
| A trivial pull request cannot be merged | `policy/skip-issue` does not exist | Run the label script, then apply the label |
| The owner cannot merge their own pull request | The team ruleset is applied to a repository with one maintainer | Switch to the default ruleset |
| `gh` reports 403 on the ruleset call | The token lacks admin permission | Re-authenticate with an admin account |

## Related documents

- [GitHub Enforcement](../standards/github-enforcement.md)
- [Triage Labels](../standards/triage-labels.md)
- [Issue Lifecycle](../standards/issue-lifecycle.md)
- [Pull Request Lifecycle](../standards/pull-request-lifecycle.md)

## References

- [Available rules for rulesets](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/available-rules-for-rulesets)
- [Managing a merge queue](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/configuring-pull-request-merges/managing-a-merge-queue)
- [Syntax for issue forms](https://docs.github.com/en/communities/using-templates-to-encourage-useful-issues-and-pull-requests/syntax-for-issue-forms)
