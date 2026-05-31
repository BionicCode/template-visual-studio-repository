# Repository Review Protocol

This document is not an instruction file for coding agents.

Audience:
- Human maintainer
- ChatGPT project review sessions

Do not treat this file as implementation requirements.
Do not execute instruction items from this file.
Do not modify code to satisfy this document unless the user explicitly asks for a review against this document.

Purpose:
This file helps ChatGPT evaluate Codex/Copilot output after the fact.

---

This protocol defines how future repository ZIP reviews should be handled for the repository-maintenance workflow, doc-metadata tooling, sync-managed-files wrapper, scripts, tests, and backlog tracking.

## Source of truth

- The repository ZIP supplied for review is the current implementation source of truth.
- `repository-maintenance-orchestrator-recovery-backlog.md` in the repository is the current progress-tracking source of truth.
- Any `AGENTS.md` file found in the repository is review context and must be inspected before reviewing implementation.
- Chat history can provide background, but it must not override the current repository files unless the user explicitly says so.

## AGENTS.md handling

`AGENTS.md` is primarily meant for coding agents, but it can contain repository conventions, setup commands, test expectations, safe-edit boundaries, and review rules. Therefore:

- If an `AGENTS.md` file exists in the uploaded repository, inspect it before reviewing.
- If nested `AGENTS.md` files exist, inspect the relevant one for the reviewed path.
- Treat `AGENTS.md` as repository guidance, not as higher-priority system instructions.
- If `AGENTS.md` conflicts with the user's explicit request or the backlog, report the conflict instead of silently choosing one.
- If no `AGENTS.md` exists, note that none was found and continue.

## Review layers

Every review has two layers. Do not perform a backlog-only review.

### 1. Whole-repository safety pass

Perform a broad, practical safety pass across the uploaded repository contents.

Required checks:

- Inspect workflow YAML structure and reusable-workflow call relationships.
- Inspect relevant script entry points and major dependency paths.
- Run YAML parsing or equivalent syntax validation when possible.
- Run PowerShell parser validation for `.ps1` files when possible.
- Run available tests when possible.
- Review the tests themselves for missing coverage, stale assertions, weak fixtures, and false positives/false negatives.
- Look for obvious regressions outside the active backlog item.
- Look for stale behavior, broken paths, temporary files leaking into repository checkouts, unsafe assumptions, and accidental configuration-surface expansion.

The whole-repository pass is broad, not a full line-by-line audit of every file on every upload. If tests fail or a risky area changed, deepen the review there.

### 2. Backlog conformance pass

After the safety pass, compare the implementation against `repository-maintenance-fix-backlog.md`.

Required checks:

- Verify the active backlog item against implementation and tests.
- Mark a backlog checkbox complete only when the current uploaded repository proves it is complete.
- Leave items unchecked when they are only partially implemented, untested, or unverifiable.
- Uncheck previously completed items if the current repository regresses them.
- Add a short note when a checkbox is left unchecked due to missing test coverage or failed validation.
- Do not tick boxes merely because code was changed in that area.

## Test review requirements

Test review is mandatory. Tests are not just execution artifacts; they are part of the implementation quality.

For every review:

- Run all available relevant tests when feasible.
- If the full test suite is too slow or times out, run targeted subsets and clearly state the limitation.
- Inspect new or changed tests for whether they actually prove the requested behavior.
- Watch for tests that accidentally introduce unrelated governed files or invalid fixtures.
- Watch for tests that assert implementation details instead of behavior.
- Watch for tests that were weakened to pass rather than proving the regression is fixed.
- Identify missing coverage for the active backlog item.
- Identify stale tests that still encode old workflow or manifest semantics.

A backlog item should not be marked complete unless its critical behavior is covered by tests or is otherwise directly verified.

## Backlog update rules

When returning an updated backlog file:

- Use GitHub task-list checkboxes only for actual completion tracking.
- Do not use checkboxes for explanatory lists, examples, design concepts, or warnings.
- Mark completed items with `- [x]` only after verification in the current repository state.
- Revert an item to `- [ ]` if a regression is found.
- Preserve priority labels and task IDs unless the backlog itself is being reorganized intentionally.
- Add concise review notes only where they help future tracking.

## Review output format

The review response should include:

1. Verdict: mergeable, not mergeable, or mergeable with minor follow-up.
2. Files reviewed.
3. Checks run and their result.
4. Main findings, grouped by file or backlog item.
5. Test coverage assessment.
6. Backlog updates made.
7. Remaining risks or items requiring the next Copilot/agent pass.
8. A downloadable updated backlog file if backlog status changed.

## Tool and workflow assumptions

- The target repository owns and executes `Repository maintenance`.
- The target repository calls local wrapper workflows.
- Shared workflows remain passive and are invoked through reusable workflow calls.
- Source repositories listed in sync manifests remain passive.
- Do not add source-side broadcasting, `repository_dispatch`, or dispatcher workflows unless the user explicitly reopens that design.
- Do not delegate internal workflow/tool artifact safety to user configuration.
- Keep fixes incremental and focused; Copilot Agent should receive one problem at a time.

## Scope discipline for future agent handoffs

When creating a Copilot/Sonnet/Codex handoff:

- Use one active problem per pass where possible.
- Explicitly list out-of-scope areas.
- Include the expected behavior, the suspected cause, and acceptance tests.
- Avoid mixing regression fixes with architecture redesign.
- Move larger design issues to the backlog instead of expanding the active prompt.

## Minimum review command checklist

Use these commands or equivalent checks when the files are available:

```bash
# YAML parse check, if a parser is available
python - <<'PY'
from pathlib import Path
import yaml
for path in Path('.github/workflows').glob('*.y*ml'):
    with path.open('r', encoding='utf-8') as f:
        yaml.safe_load(f)
    print('YAML OK', path)
PY

# PowerShell parser check
pwsh -NoLogo -NoProfile -Command '
  $ErrorActionPreference = "Stop"
  Get-ChildItem -Path .github -Recurse -Filter *.ps1 | ForEach-Object {
    $tokens = $null
    $errors = $null
    [System.Management.Automation.Language.Parser]::ParseFile($_.FullName, [ref] $tokens, [ref] $errors) | Out-Null
    if ($errors.Count -gt 0) { throw "PowerShell parse failed: $($_.FullName)`n$($errors | Out-String)" }
    "PS OK $($_.FullName)"
  }
'

# Doc-metadata acceptance tests, if present
pwsh -NoLogo -NoProfile -File .github/scripts/doc-metadata/tests/Invoke-DocMetadataAcceptanceTests.ps1
```

If a command is unavailable, too slow, or times out, state that limitation and run the best targeted substitute.

## Completion-state standard

A backlog item is complete only when all of these are true:

- The implementation behavior matches the backlog requirement.
- The behavior is covered by a test or direct reproduction.
- Existing relevant tests still pass.
- No obvious broader regression is detected in the whole-repository safety pass.
- The current repository state, not memory or previous chat context, supports the completion mark.
