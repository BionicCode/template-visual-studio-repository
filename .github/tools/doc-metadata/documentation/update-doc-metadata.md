---
Version: 1
Created: 2026-05-26T19:08:33+00:00
Updated: 2026-05-26T19:08:33+00:00
Author: BionicCode
---
<!-- doc-metadata-presentation:start -->
<details>
<summary>Change History</summary>

- Updated: <b>2027-05-26T19:08:33+00:00</b> | Author: <b>BionicCode</b> | Changes: <b>Unavailable</b>

</details>

---

<br>
<br>
<!-- doc-metadata-presentation:end -->
# Document Metadata Automation

## What this tool does

The document metadata tool keeps human-readable metadata headers current for governed UTF-8 document files. It writes managed fields such as `Version`, `Created`, `Updated`, and `Author`, adds a generated presentation area for Markdown files, and verifies that document revisions match body-content changes.

The repository manifest is the source of truth. GitHub workflow path filters only decide when CI starts; they do not decide which files are governed.

> [!IMPORTANT]
> First-time setup usually requires one Bootstrap or Repair run to initialize existing governed files. For migrated existing files, `Created` means metadata initialization time unless a future Git-history inference feature is added.

## Metadata Header

Markdown files use YAML front matter plus a managed presentation region:

```md
---
Version: 2
Created: 2026-05-25T14:05:02+00:00
Updated: 2026-05-26T01:40:38+00:00
Author: BionicCode
---

<!-- doc-metadata-presentation:start -->
<details>
<summary>Change History</summary>

- Updated: <b>2026-05-26T01:40:38+00:00</b> | Author: <b>BionicCode</b> | Changes: [<b>View Commit</b>](https://github.com/owner/repo/commit/0123456789abcdef0123456789abcdef01234567)

</details>

---

<br>
<br>
<!-- doc-metadata-presentation:end -->

# Document title
```

Plain text files use compact metadata by default:

```text
---
Version: 2
Created: 2026-05-25T14:05:02+00:00
Updated: 2026-05-26T01:40:38+00:00
Author: BionicCode
---
--------------------------------------------------------------------------------


Document body starts here.
```

Markdown `spacingBreaks` creates explicit `<br>` lines. Plain text `spacingBreaks` creates physical blank lines using the file newline style. The tool never inserts `<br>` into `.txt` files.

## Reading the Header

`Version` is document revision notation. It may be a positive integer or a dotted numeric value such as `2.1`, but it is not SemVer. Automatic increments update the first component only, so `2.1.2` becomes `3`.

`Created` is the metadata initialization timestamp and is immutable after initialization. Generated timestamps are UTC RFC 3339 values with an explicit `+00:00` offset.

`Updated` changes only when governed document body content changes. Generated values are normalized to UTC `+00:00`.

`Author` is the detected content-change author. Local runs prefer `git config user.name`; GitHub repair prefers the content-changing commit author and avoids `github-actions[bot]` unless the bot authored the content.

Change History is a generated recent-history view. Git remains the canonical full audit log.

## Common Workflows

Same-repository pull request: Analyze runs read-only. If repair is safe, Repair pushes one metadata commit to the PR branch, then runs Check again because `GITHUB_TOKEN` commits may not trigger all follow-up workflows.

Fork pull request: Analyze reports only. The workflow does not run write-capable repair for forks.

Direct push to default branch: Analyze classifies metadata state. Safe repair creates or updates a deterministic bot branch and repair PR instead of pushing to main.

`workflow_dispatch`: Runs the same Analyze/Repair/Final Status flow for the selected branch.

Local Bootstrap/Update: Developers can still run the script manually, but normal maintenance should be handled by hosted repair automation.

```powershell
pwsh ./.github/scripts/doc-metadata/update-doc-metadata.ps1 -Mode Bootstrap -Root .
pwsh ./.github/scripts/doc-metadata/update-doc-metadata.ps1 -Mode Update -Root .
pwsh ./.github/scripts/doc-metadata/update-doc-metadata.ps1 -Mode Check -Root .
```

## Repair Safety

The tool compares body content after removing the metadata block and the entire generated presentation/separator region. Generated history or spacing updates cannot trigger a self-perpetuating version bump.

Manual `Version` increases are allowed as a rebaseline when the body is unchanged and the rest of the managed metadata is valid. Version decreases are rejected by default.

Custom front matter fields are preserved and ignored:

```yaml
---
Version: 2
Created: 2026-05-25T14:05:02+00:00
Updated: 2026-05-26T01:40:38+00:00
Author: BionicCode
Tool: Visual Studio Code
ReviewState: Draft
---
```

Generated history entries are tamper-safe. If a generated history entry changes, the tool restores it from trusted previous generated history when safe. If restoration is not safe, the file is reported as unrecoverable.

> [!WARNING]
> Unsafe repair cases include version rollback, invalid version values, ambiguous malformed metadata, malformed presentation without trusted previous state, and fork PRs where write access is unavailable.

## URLs in Change History

New history entries use the most precise stable link available:

1. Verified file-specific diff URL.
2. Stable commit URL with link text `View Commit`.
3. `Changes: <b>Unavailable</b>` when no reliable commit URL exists.

Existing committed history URLs are not re-fetched every run. Integrity is checked by comparing the current generated history with the previous trusted generated history.

## Troubleshooting

`repairableFiles`: hosted repair can safely update these files.

`unrecoverableFiles`: manual intervention is required before repair.

`ineligibleFiles`: the manifest matched files that are not eligible document text files.

`ignoredBinaryOrNonText`: the file is not strict UTF-8 or contains binary data. Convert it to UTF-8 if it should be managed.

`historyTamperDetected`: generated history was edited.

`historyRestoredFromTrustedPrevious`: generated history was restored safely.

> [!TIP]
> Use `documentEligibility` to allow additional document extensions, deny generated paths, or fail when broad globs match ineligible files.
