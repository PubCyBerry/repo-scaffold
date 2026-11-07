---
type: Standard
title: Decision records
description: When to record a decision, and how to write it in docs/decisions/ with the MADR 4.0 template.
tags: [decisions, adr, madr]
---

# Decision records

Decisions are recorded as Architectural Decision Records in [MADR 4.0](https://adr.github.io/madr/)
format, one file per decision, under `docs/decisions/`.

## When to write one

Write a record when a decision:

- is expensive to reverse, such as a dependency, a data format, a public interface, or a layout, or
- will make someone ask "why is it like this?" later.

Choices that are cheap to reverse do not need one. When in doubt, write a short one.

## Files

- Name the file `NNNN-title-with-dashes.md`. Take the next free number, starting at `0001`.
- The title states the solved problem and the chosen solution, for example "Use PostgreSQL for job state".
- Never reuse a number. Never delete a record.

## Status

`status` takes MADR values. OKF readers map them to OKF lifecycle values as follows.

| MADR `status` | Meaning | OKF lifecycle |
| --- | --- | --- |
| `proposed` | Under discussion | `draft` |
| `accepted` | In effect | `stable` |
| `rejected` | Considered and declined | `stable` |
| `deprecated` | No longer in effect, not replaced | `deprecated` |
| `superseded by ADR-NNNN` | Replaced by another record | `deprecated` |

Do not rewrite an accepted record. To change a decision, write a new record, set the old
record's `status` to `superseded by ADR-NNNN`, and link the two records to each other.

## Template

Copy the block below into the new file. Sections marked optional may be deleted.
The template is MADR 4.0.0 with the front matter keys from [Documentation](documentation.md) added.

````markdown
---
# type, title, and description are required by docs/standards/documentation.md.
# The other keys are optional MADR metadata.
type: Decision
title: {short title, representative of solved problem and found solution}
description: {one sentence stating what was decided}
status: "{proposed | rejected | accepted | deprecated | … | superseded by ADR-0123}"
date: {YYYY-MM-DD when the decision was last updated}
decision-makers: {list everyone involved in the decision}
consulted: {list everyone whose opinions are sought (typically subject-matter experts); and with whom there is a two-way communication}
informed: {list everyone who is kept up-to-date on progress; and with whom there is a one-way communication}
---

# {short title, representative of solved problem and found solution}

## Context and Problem Statement

{Describe the context and problem statement, e.g., in free form using two to three sentences or in the form of an illustrative story. You may want to articulate the problem in form of a question and add links to collaboration boards or issue management systems.}

<!-- This is an optional element. Feel free to remove. -->
## Decision Drivers

* {decision driver 1, e.g., a force, facing concern, …}
* {decision driver 2, e.g., a force, facing concern, …}
* … <!-- numbers of drivers can vary -->

## Considered Options

* {title of option 1}
* {title of option 2}
* {title of option 3}
* … <!-- numbers of options can vary -->

## Decision Outcome

Chosen option: "{title of option 1}", because {justification. e.g., only option, which meets k.o. criterion decision driver | which resolves force {force} | … | comes out best (see below)}.

<!-- This is an optional element. Feel free to remove. -->
### Consequences

* Good, because {positive consequence, e.g., improvement of one or more desired qualities, …}
* Bad, because {negative consequence, e.g., compromising one or more desired qualities, …}
* … <!-- numbers of consequences can vary -->

<!-- This is an optional element. Feel free to remove. -->
### Confirmation

{Describe how the implementation of/compliance with the ADR can/will be confirmed. Are the design that was decided for and its implementation in line with the decision made? E.g., a design/code review or a test with a library such as ArchUnit can help validate this. Note that although we classify this element as optional, it is included in many ADRs.}

<!-- This is an optional element. Feel free to remove. -->
## Pros and Cons of the Options

### {title of option 1}

<!-- This is an optional element. Feel free to remove. -->
{example | description | pointer to more information | …}

* Good, because {argument a}
* Good, because {argument b}
<!-- use "neutral" if the given argument weights neither for good nor bad -->
* Neutral, because {argument c}
* Bad, because {argument d}
* … <!-- numbers of pros and cons can vary -->

### {title of other option}

{example | description | pointer to more information | …}

* Good, because {argument a}
* Good, because {argument b}
* Neutral, because {argument c}
* Bad, because {argument d}
* …

<!-- This is an optional element. Feel free to remove. -->
## More Information

{You might want to provide additional evidence/confidence for the decision outcome here and/or document the team agreement on the decision and/or define when/how this decision the decision should be realized and if/when it should be re-visited. Links to other decisions and resources might appear here as well.}
````
