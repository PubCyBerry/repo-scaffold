---
type: Standard
title: Issues and pull requests
description: What every issue and pull (merge) request must contain, and which template to use.
tags: [issues, pull-requests]
---

# Issues and pull requests

The templates live in the forge directory: `.github/` for GitHub, Gitea, and Forgejo, and
`.gitlab/` for GitLab. This document is the policy they implement. Command-line tools do not
apply templates, so an agent that opens an issue or a pull request from the command line writes
the same sections itself.

## Issues

| Template | Use it for | Label |
| --- | --- | --- |
| Bug | The product does not behave as documented or expected | `bug` |
| Feature | A new capability or a change in behavior | `enhancement` |
| Troubleshooting | A setup, environment, CI, or tooling problem and its resolution | `troubleshooting` |

- One problem per issue.
- Paste errors and logs as text, not screenshots, so they can be searched.
- Remove secrets and personal data before posting.
- Report security vulnerabilities privately, never in a public issue.

## Pull requests

GitLab calls them merge requests. The rules are the same.

- One purpose per pull request. Keep refactoring apart from behavior changes.
- The description answers four questions: why, what changed, how it was verified, and what could break.
- Link the issue with a closing keyword, such as `Closes #123`. GitHub, GitLab, and Gitea close
  the issue when the pull request merges.
- A decision that is hard to reverse comes with a record in `docs/decisions/`.
  See [Decision records](decisions.md).
- Documentation changes ship in the same pull request as the code they describe.
