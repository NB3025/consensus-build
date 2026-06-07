# TDD AND TIDY FIRST

Follow the TDD cycle on every change: Red → Green → Refactor. No exceptions.

## TDD CYCLE

1. Write one failing test that defines the next increment of behavior.
2. Implement the minimum code to make it pass — no more.
3. Run ALL tests to confirm Green.
4. Refactor if duplication or unclear naming exists. Run tests after each refactoring step.
5. Repeat from 1.

Do NOT write production code without a failing test. Do NOT skip the failing-test verification step.

When fixing a defect:
1. Write an API-level failing test that reproduces the bug.
2. Write the smallest possible unit test that isolates the root cause.
3. Fix the code so both tests pass.

Test names describe behavior, not implementation:
- Good: "shouldSumTwoPositiveNumbers", "shouldRejectNegativeBalance"
- Bad: "testAdd", "test1", "handleEdgeCase"

## TIDY FIRST

Separate changes into exactly two types:
1. **STRUCTURAL** — Renaming, extracting methods, moving code. No behavior change.
2. **BEHAVIORAL** — Adding or modifying functionality.

Never mix them in the same commit. When both are needed, structural first.
Run tests before and after structural changes to verify no behavior change.

## COMMIT DISCIPLINE

Commit when ALL of these are true:
1. All tests pass
2. All linter warnings resolved
3. The change is a single logical unit

Commit message must state: structural or behavioral.
Small, frequent commits. One logical change per commit.

## CODE STANDARDS

- Eliminate duplication.
- Name things to express intent — if a name needs a comment, rename it.
- Make dependencies explicit.
- One responsibility per method.
- Minimize state and side effects.
- Simplest solution that works.

## WHEN BLOCKED

If a test keeps failing after two attempts with the same approach, stop and try a different approach. Do not retry the same fix repeatedly.

If you cannot write a meaningful test for a requirement, ask the user to clarify the expected behavior before writing code.

REMEMBER: No production code without a failing test. No mixed commits. When in doubt, write the test first.
