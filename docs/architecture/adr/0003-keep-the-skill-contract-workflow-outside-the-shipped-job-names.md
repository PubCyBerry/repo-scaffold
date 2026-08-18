---
id: decision-0003-keep-the-skill-contract-workflow-outside-the-shipped-job-names
title: 0003. Keep the skill contract workflow outside the shipped job names
type: decision
status: accepted
summary: Two extra job names beyond the five a branch ruleset expects, and what that costs
scope:
  - .github/workflows/**
read_when:
  - Before applying a branch ruleset to this repository
  - When a required status check never reports
related:
  - index-adr
  - standard-github-enforcement
  - decision-0002-dogfood-the-scaffold-in-its-own-source-repository
sources:
  - .github/workflows/validate.yml
  - .github/rulesets
---

# 0003. Keep the skill contract workflow outside the shipped job names

## Context and problem statement

A branch ruleset matches a required status check by **job name**, not by file name. The two
ruleset examples this repository ships name five: `pr-policy`, `quality`, `tests`, `docs`, and
`security`. Applying the scaffold gave this repository workflows that report exactly those
five.

It also has a workflow the scaffold knows nothing about. `validate.yml` gates the skill
contract: front matter shape, the required artifacts, the eval task set with its negative
case, and the smoke tests on both Linux and Windows. Its jobs are called `validate` and
`smoke (windows)`. Neither name appears in either ruleset example, so a ruleset applied
verbatim would let a broken skill through while the smoke tests were still red.

## Considered options

| Option | Why not |
| --- | --- |
| Rename `validate` to one of the five | The five already exist and report on the same pull request. Two jobs cannot share a name |
| Fold the skill contract into `quality` | Buries a repository-specific gate inside a job the templates own, so every template edit risks the gate |
| Drop the shipped workflows and keep only `validate` | Every governance document links to those workflow files. Removing them makes four standards documents false |
| Keep both and record the extra names | Chosen. See below |

## Decision outcome

Keep all seven jobs. The five shipped ones stay named as the ruleset examples expect.
`validate` and `smoke (windows)` stay as they are.

Anyone applying
[the default ruleset example](../../../.github/rulesets/default-branch.example.json) here
has to add those two names to `required_status_checks` by hand. That is a human step, in the
same class as substituting real handles into `CODEOWNERS.example`.

The ruleset itself is not applied by this change, and neither are the labels. `pr-policy` is
not raised to a required check either: with no labels created, `policy/skip-issue` cannot be
applied, and every pull request without a linked issue would be blocked from day one.

## Consequences

What this makes easier:

- Every governance document keeps pointing at a workflow that exists
- The required check names a scaffolded repository gets are exercised here too

What this makes harder:

- The ruleset examples cannot be applied to this repository unedited. That is the cost, and it
  is recorded here rather than discovered when the branch locks
- Continuous integration now runs the shipped workflows and `validate` on every pull request,
  which is more compute than either alone

What is now fixed:

- The list of required checks for this repository is `pr-policy`, `quality`, `tests`, `docs`,
  `security`, `validate`, `smoke (windows)`
- `pr-policy` stays optional until the labels exist

## Related documents

- [Decision Records](index.md)
- [GitHub Enforcement](../../standards/github-enforcement.md)
- [GitHub governance setup](../../guides/github-governance-setup.md)
