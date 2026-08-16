---
id: standard-testing
title: Testing
type: standard
status: active
summary: Behavior over implementation, edge and error coverage, mocking boundaries, mutation and property testing
scope:
  - "**"
read_when:
  - Writing a test for new code
  - A refactor broke tests but not behavior
  - Deciding what to mock
  - Judging whether existing coverage is real
related:
  - standard-code-quality
  - standard-code-review
---

# Testing

## Purpose

A test suite is only worth its runtime if a passing suite means the code works. These rules
exist to keep that true.

## Scope

All test code in this repository.

## Rules

### Test behavior, not implementation

A test verifies what the code does, not how it does it. If a refactor breaks the tests but
not the code, the tests were wrong.

Assert on return values, emitted events, and observable state. Do not assert on call counts
of internal helpers or on the order of private operations.

### Test edges and errors, not just the happy path

Bugs live at the edges: empty inputs, boundaries, malformed data, missing files, network failures, timeouts.

Every error path the code handles has a test that triggers it. An `except` branch with no
test is an untested branch.

### Mock boundaries, not logic

Only mock what is:

- Slow: network, filesystem
- Non-deterministic: time, randomness
- An external service you do not control

Everything else runs for real. Mocking your own logic tests the mock.

### Verify that tests catch failures

A test that has never failed has not been shown to work.

1. Break the code
2. Confirm the test fails
3. Restore the code

Do this systematically with mutation testing: `cargo-mutants` for Rust, `mutmut` for Python.

Use property-based testing for parsers, serialization, and algorithms: `proptest` for Rust,
`hypothesis` for Python.

### Running tests

Before committing, run the tests relevant to the change, not the full suite. The full suite
is CI's job.

## Checklist

- Would this test survive a refactor that keeps behavior identical?
- Is there a test for every error branch the code handles?
- Is anything mocked that is neither slow, non-deterministic, nor external?
- Has each new test been observed failing against broken code?
- Do parsers, serializers, and algorithms have property-based tests?

## Related documents

- [Code quality](code-quality.md)
- [Code review](code-review.md)
