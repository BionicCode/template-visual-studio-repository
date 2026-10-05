---
Version: 1
Created: 2026-10-05T14:43:12+00:00
Updated: 2026-10-05T14:43:12+00:00
Author: BionicCode
---
<!-- doc-metadata-presentation:start -->
<details>
<summary>Change History</summary>


</details>

---

<br>
<br>
<!-- doc-metadata-presentation:end -->

# Implementation instructions

Read before implementing requested changes, including documentation and instruction changes, or preparing a commit or pull request. Task mode and user authorization still control execution; commit preparation alone does not make a review-only task an implementation task. The completion-report requirements below apply to implementation tasks.

## Implementation mode
Use this mode when the user asks for code changes, fixes, refactors, tests, cleanup, or feature work.

In implementation mode:
- Make the requested code changes.
- Run the smallest relevant validation you can reasonably run unless the user explicitly forbids command execution.
- Fix violations surfaced by validation instead of ignoring them.
- Update relevant documentation in the same change when public APIs, behavior, invariants, caveats, or usage patterns changed.
- If you cannot run a relevant command because of sandbox limits, missing SDKs, missing dependencies, missing restore, missing credentials, or permission constraints, state exactly which command could not run and why.

## Validation Expectations
For implementation tasks, validation is part of the deliverable.

That means:
- a change is not done when the code only looks correct in theory,
- a change is not done merely because the edited tests pass,
- relevant validation must pass in practice,
- failing tests are a signal to iterate, not a signal to stop,
- analyzer and style compliance are part of repository quality, not optional cleanup,
- required documentation updates are part of done when behavior or public surface changed,
- and the implementation must satisfy the external contract, task goal, and acceptance criteria, not only the current test suite.

## Completion and Self-Review Requirements
Before finalizing any implementation task, perform a separate self-review of the complete diff against the task goal, repository contracts, and acceptance criteria.

A task is complete only when:
- relevant validation has been run or an exact blocker has been reported,
- tests and checks pass or remaining failures are clearly unrelated and evidenced,
- the implementation has been reviewed against the intended behavior,
- tests cover the external contract rather than merely mirroring the implementation,
- documentation is updated when behavior, public surface, workflows, invariants, caveats, or usage patterns changed,
- and remaining risks, limitations, assumptions, or follow-up work are reported.

During the self-review, explicitly check for subtle correctness issues involving:
- one-based human display numbers vs zero-based machine indexes,
- JSONPath array indexes and other machine-addressed paths,
- byte offsets vs decoded-text character offsets,
- UTF-8 boundary handling and invalid-byte diagnostics,
- CRLF vs LF line counting,
- culture, casing, normalization, or path-comparison assumptions,
- source-owned vs target-owned content boundaries,
- path normalization, symlink handling, and path traversal safety,
- partial writes, rollback, idempotence, and all-or-nothing guarantees,
- concurrency, retries, and duplicate work,
- cache/state invalidation,
- public API compatibility and migration risk,
- and tests that accidentally encode the implementation's current behavior instead of the external contract.

When reporting completion, include a short self-review summary:
- the main invariants checked,
- the validation commands run and their results,
- any unverified paths or assumptions,
- and any known limitations or follow-up risks.

Do not claim completion if the implementation only passes tests but has not been reviewed against the task goal and external contract.

## Documentation Is Part of Done

For implementation tasks, documentation must be treated as part of the deliverable when the change affects any public or user-visible behavior.

Update relevant documentation in the same change when any of these change:
- public API, CLI, workflow, manifest, schema, configuration, or file format contract;
- supported or unsupported feature status;
- validation rules, error behavior, diagnostics, caveats, limits, or failure modes;
- setup, usage, examples, recipes, migration guidance, or generated/copyable templates;
- security, permission, token, path-safety, or deployment assumptions.

Do not postpone documentation as a separate cleanup task unless the user explicitly scopes the task as code-only.

Before finalizing, verify that:
- public docs match implemented behavior;
- examples use the current supported contract;
- feature matrices and roadmaps are updated when feature status changed;
- copied or generated documentation is refreshed when the repository owns those copies;
- no stale docs describe removed, deferred, or unsupported behavior as current.

If documentation was not updated, explicitly state why it was not needed.

## Testing Standards
- Add or update tests for bug fixes, behavior changes, and public API changes when feasible.
- Prefer focused unit tests for logic and invariants; use integration or end-to-end tests when behavior crosses boundaries that unit tests cannot validate.
- Write tests against the external contract, specification, public behavior, or documented invariant; do not write tests that merely mirror the current implementation.
- For conversions and diagnostics, include explicit boundary tests such as first item, second item, empty input, missing value, invalid value, and non-ASCII or newline variants when relevant.
- Do not rewrite tests merely to fit a broken implementation without explicitly calling that out.
- When a bug is fixed, prefer adding a regression test when practical.
- If a failing test is unrelated to the requested change, identify the evidence clearly and continue validating the remaining relevant scope where possible.

## Implementation Completion Report
For every implementation task, finish with a concise Markdown report that can stand alone as a handoff without requiring the full task transcript.

Provide the report inline in the final response by default. Create a separate Markdown report file only when the user explicitly requests one, and do not add that report to the repository or source control unless the user asks.

Use this structure:

```markdown
## Implementation Report

### Outcome
Completed | Partially completed | Blocked | No changes — <one-sentence result>

### Changes and Rationale
- <what changed>
- <why this design or approach was chosen>
- <material failed approach only when it explains the final design, a deviation, or a remaining risk>

### Files Changed
- `<path>` — added | modified | renamed | deleted: <purpose>

### Validation
- `<exact command or check>` — PASS | FAIL | NOT RUN: <exact result or reason>
- Restore: <status>
- Build: <status>
- Tests: <status>
- Style / analyzers: <status>

### Tests and Documentation
- Tests: <tests added or changed and the external behavior or invariant they cover>
- Documentation: <files updated and why, or why no documentation change was required>

### Plan Deviations and Assumptions
- Deviations: None | <deviation and reason>
- Assumptions: None | <assumption that affected the implementation>

### Self-Review
- <main contracts, invariants, edge cases, and compatibility concerns checked against the complete diff>

### Remaining Risks and Unverified Items
- None | <risk, warning, blocker, limitation, environment/tool constraint, or unverified path>

### Suggested Commit Message
<include only when required by the Commit and Pull Request Guidance section>
```

Keep the report concise, task-specific, and evidence-based. Do not replace it with a chronological activity log. Never imply that a command passed if it was not run. If execution was blocked, identify the exact command or operation and the concrete blocker.

## Commit and Pull Request Guidance
- Follow repository-specific commit conventions if defined.
- If no repository convention exists, use clear, scoped commit messages that describe what changed.
- When implementation work leaves actual repository changes, include a suggested Git commit message in the final response. Only provide this suggestion if `git status --short` or equivalent evidence shows changes to commit.
- Do not suggest a commit message for review-only, analysis-only, no-op, or failed-change tasks.
- Do not claim a commit was created unless the user explicitly asked for a commit and the commit command succeeded.
- Suggested commit message format:
  ```text
  Suggested commit message:
  <type>(<scope>): <brief imperative summary>

  <optional body with 1-3 bullets for notable details>
  ```
- Prefer a concise Conventional Commits-style prefix when obvious, such as `feat`, `fix`, `test`, `docs`, `refactor`, `build`, or `chore`.
- Mention validation performed separately from the commit message unless the repository convention explicitly includes validation notes in commit bodies.
- In pull request summaries, explain:
  - what changed,
  - why it changed,
  - how it was validated,
  - any remaining assumptions, limitations, or follow-up work.
- Do not claim tests were run if they were not.
