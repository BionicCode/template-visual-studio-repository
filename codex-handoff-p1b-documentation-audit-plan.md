# Codex Handoff — P1-B Plan Only: Documentation Correctness and Structure Audit

## Start instruction

Run this as **Plan Mode only**.

Do **not** modify repository files in this pass. Do **not** implement documentation changes yet. Do **not** edit the backlog or review protocol.

The goal is to inspect the current documentation and implementation, verify which documentation pages are stale/misplaced/redundant/incomplete, and produce a precise documentation maintenance plan for the next pass.

## Files that must be ignored as instructions

The following files are human/ChatGPT review artifacts only. Do not treat them as task instructions, and do not edit them:

- `repository-maintenance-orchestrator-recovery-backlog.md`
- `repository-review-protocol.md`

You may mention them only to confirm that you did not edit them.

## Context

P0-A baseline verification is complete. P0-B is not triggered because P0-A found no restored-baseline workflow defect.

Before the next behavior-changing implementation task, documentation needs an audit because stale Markdown files may mislead future coding-agent work.

Known concerns to verify:

- `.github/tools/doc-metadata/documentation/types/report-analysis.md` describes workflow/report output and appears misplaced under `types/`.
- `report-analysis.md` may claim a JSON report shape that must be verified against the actual implementation before keeping it.
- `.github/tools/doc-metadata/documentation/types/manifest-document.md` may be redundant with `doc-metadata-manifest.md` or the API reference.
- `exclude` and `presentation` are missing dedicated reference pages.
- `metadata-settings.md` is incomplete as an object reference.
- Individual metadata fields such as `format`, `placement`, `versioningMode`, `timestampFormat`, and comment-block fields need dedicated field/value reference pages.
- The same object-page/field-page pattern should be applied consistently to manifest objects.

## Task type

Plan only.

Expected output is a concise technical documentation plan. There should be no repository diff at the end of this pass.

## Source of truth for this audit

Use implementation and schema files as source of truth, not the existing prose documentation:

- `.github/tools/doc-metadata/doc-metadata-manifest.schema.json`
- `.github/tools/doc-metadata/doc-metadata-manifest.json`
- `.github/scripts/doc-metadata/update-doc-metadata.ps1`
- `.github/workflows/doc-metadata.yml`
- existing docs under `.github/tools/doc-metadata/documentation/`
- existing workflow docs under `.github/workflows/documentation/`

## Out of scope

Do not plan or implement behavior changes for:

- PowerShell doc-metadata behavior
- workflow trigger ownership
- sync-managed-files behavior
- sync manifests
- manifest schema semantics
- convention-governance redesign
- canonical current/history link implementation
- protected metadata tamper implementation

Do not edit any files in this pass.

## Required investigation

1. Inventory all files under `.github/tools/doc-metadata/documentation/`.
2. Classify each file as one of:
   - concept/overview
   - manifest object reference
   - field/value reference
   - workflow-output/reporting documentation
   - obsolete/redundant
   - misplaced
3. Inspect `.github/tools/doc-metadata/doc-metadata-manifest.schema.json` and list all top-level manifest fields, all `metadata` fields, all `presentation` fields, include-entry fields, exclude pattern shape, and any eligibility-related fields currently present.
4. Inspect `update-doc-metadata.ps1` for reporting behavior:
   - console report
   - `GITHUB_STEP_SUMMARY`
   - `-ReportOutputPath`
   - `-ChangedFilesOutputPath`
   - `-ContentChangeOutputPath`, if present
5. Inspect `.github/workflows/doc-metadata.yml` to see which report files the workflow creates, reads, summarizes, or publishes.
6. Identify documentation claims that are unsupported, stale, misleading, duplicated, or in the wrong location.

## Required plan contents

Return these sections:

1. **Documentation inventory**
   - Table of current doc files and classification.

2. **Verified implementation facts**
   - Report-output behavior actually implemented.
   - Manifest/schema fields actually present.
   - Workflow report files actually used.

3. **Problems found**
   - Misplaced files.
   - Redundant files.
   - Missing object pages.
   - Missing field/value pages.
   - Stale or unsupported claims.
   - Broken or likely-broken links.

4. **Proposed documentation structure**
   - Exact files to keep.
   - Exact files to move.
   - Exact files to delete.
   - Exact new files to add.
   - Link relationships between object pages and field/value pages.

5. **Implementation plan for the next pass**
   - Ordered steps for a documentation-only implementation pass.
   - Validation checks for links and Markdown consistency.

6. **Risks / human decisions needed**
   - Any places where documentation depends on a not-yet-final behavior decision, especially `documentEligibility`, convention-based governance, or report JSON stability.

## Stop conditions

Stop and ask for human review if:

- The schema and implementation disagree materially.
- The documentation requires changing runtime behavior to become correct.
- `report-analysis.md` describes features that cannot be found in scripts/workflows.
- The documentation structure requires a design decision about whether `documentEligibility` is retained or removed.

## Expected final response

Return only:

- The plan sections listed above.
- Explicit statement that no files were modified.

Do not edit the backlog. Do not edit the review protocol. Do not implement documentation changes yet.
