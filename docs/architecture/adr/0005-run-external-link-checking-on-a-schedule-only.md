---
id: decision-0005-run-external-link-checking-on-a-schedule-only
title: 0005. Run external link checking on a schedule only
type: decision
status: accepted
summary: Why lychee stayed out of the pull request gate, against the plan that asked for it
scope:
  - .github/workflows/docs-health.yml
read_when:
  - Before adding a network-dependent check to a required job
  - When a plan and a workflow disagree about where a check runs
related:
  - index-adr
  - standard-github-actions
  - decision-0003-keep-the-skill-contract-workflow-outside-the-shipped-job-names
sources:
  - .github/workflows/docs-health.yml
  - tests/check-links-external.sh
---

# 0005. Run external link checking on a schedule only

## Context and problem statement

The plan this repository was built from carries a matrix of which check runs at which stage.
Its row for external links reads "changed links only" under pull request CI and "everything"
under scheduled CI.

The implementation does not do that. [docs-health.yml](../../../.github/workflows/docs-health.yml)
splits into two jobs: `docs` runs on every pull request and looks only at answers the
repository can produce on its own, and `docs-scheduled` runs on the weekly cron and on manual
dispatch. lychee lives in the second one and never runs on a pull request.

That gap sat unrecorded through two reviews. A reader comparing the plan against the workflow
finds a contradiction and no way to tell which side is the mistake, so the question gets
reopened every time someone new reads both.

## Considered options

| Option | Why not |
| --- | --- |
| Implement the plan: run lychee on changed links in pull request CI | See the three reasons below |
| Run lychee on every link in pull request CI | Same objections, and slower on every pull request |
| Leave plan and workflow disagreeing | The contradiction is the defect. Someone re-derives the answer each time |
| Keep the schedule-only behaviour and record the override | Chosen |

## Decision outcome

Schedule-only is correct. lychee stays in `docs-scheduled`.

Three reasons, in order of weight.

1. **An external URL fails for reasons the author did not cause.** When a linked host is down,
   rate-limits the runner, or blocks datacentre address ranges, the check goes red on a pull
   request that never touched that link. A gate that fails for reasons outside the diff trains
   people to ignore it, and an ignored gate is worse than an absent one.
2. **"Changed links only" needs a component that can be quietly wrong.** Computing it means
   extracting URLs from a diff, which has to handle moved lines, reflowed paragraphs, and
   links inside code fences. That extractor is new machinery with its own silent failure mode:
   when it under-extracts, the job reports success having checked nothing.
3. **`docs` is a required status check and `docs-scheduled` is not.** Putting a
   network-dependent check inside the required job hands a third party the ability to stall
   the merge queue.

The plan's matrix has been annotated with this override so the two records agree.

## Consequences

What this makes easier:

- A pull request cannot be blocked by someone else's outage
- The required `docs` job answers only from repository contents, so it is reproducible offline

What this makes harder:

- A broken external URL can merge and stays broken until the weekly run finds it. The exposure
  is bounded by the cron interval
- Nobody sees the result unless they read the scheduled run. That is the cost of moving a
  check off the pull request

What is now fixed:

- lychee runs on the weekly `docs-scheduled` job and on manual dispatch, never on
  `pull_request` or `merge_group`
- Adding any further network-dependent check to the required `docs` job needs a record that
  supersedes this one

## Related documents

- [Decision Records](index.md)
- [GitHub Actions](../../standards/github-actions.md)
- [Documentation](../../standards/documentation.md)
