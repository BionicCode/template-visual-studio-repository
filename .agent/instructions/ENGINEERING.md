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

# Engineering instructions

Read this file at the start of every repository task. It owns the shared engineering baseline. The root router determines task mode, additional instructions, and repository-local precedence.

## Core Engineering Standards
- Favor correctness, readability, testability, and explicit boundaries over minimizing file count or type count.
- Make the smallest change that fully solves the problem, unless the current design is structurally unsafe.
- Prefer fixing root causes over patching symptoms.
- Prefer cohesive designs with clear responsibilities; avoid mixing unrelated concerns in the same type or method when a cleaner separation is practical.
- Apply core maintainability principles such as single responsibility, low coupling, high cohesion, and explicit contracts when shaping or refactoring code.
- Preserve clear separation between domain logic, infrastructure concerns, and external dependencies.
- Do not introduce avoidable coupling between stable application contracts and external SDK, framework, transport, or persistence types unless the task explicitly requires it.
- Prefer clear, intention-revealing symbol names over abbreviations or overly terse names.
- Avoid cryptic abbreviations such as `cnt`, `tmp`, `obj`, or single-letter names like `f` when a more descriptive name materially improves readability.
- Use meaningful names for lambda parameters, locals, fields, and helper methods, especially when short names would force the reader to infer the enumerated item or value type from surrounding code.
- Do not hide problems by weakening rules, disabling analyzers, changing style configuration, or lowering warning severities unless the user explicitly asks for that.
- Follow existing repository conventions unless they conflict with the user prompt or this file.
- Treat documentation as part of engineering quality, not optional polish.

## Scope Discovery and Routing
- If the user names entry points, files, types, methods, projects, tests, or directories, treat those as the starting scope.
- If the user does not name scope, discover the smallest relevant scope before making changes.
- Prefer repository-local evidence over assumptions from naming alone.
- Prefer the smallest relevant solution, project, directory, file set, and test scope over whole-repository work.

## Planning and Execution
- For architectural, cross-cutting, ambiguous, or multi-file work, start with a short plan before making changes.
- Before editing, inspect the relevant files, call paths, and neighboring abstractions so the change fits the surrounding design.
- Identify assumptions, risks, and boundaries when repository context is missing or ambiguous.
- Use a user-supplied plan unless it is clearly unsafe, inconsistent with repository constraints, or incomplete for the requested scope.

## File System and Project Structure
- Respect the existing repository layout before introducing new folders.
- Keep production code in the repository's established source locations.
- If the repository already has a documentation or test layout, follow that layout before applying the defaults below.
- Default Markdown documentation location: top-level `docs/` directory in the repository root.
- Default automated test location: top-level `test/` directory in the repository root.
- If no test location exists and tests are needed, create the repository's default test location unless a more specific repository instruction says otherwise.
- For .NET repositories, default a generated unit test project name to `<SolutionName>.Tests` unless the repository already uses a different convention.
- If the repository contains multiple solution files, use the solution that owns the code being changed. If that ownership is still ambiguous, state the assumption you used.
- Keep test fixtures, sample inputs, and test-only helpers with or below the owning test project unless the repository already uses a shared test-assets location.

## Analyzer and Style Compliance
- Treat repository style configuration, analyzer settings, and project analysis settings as part of the repository contract.
- Prefer fixing the code over suppressing diagnostics.
- Use the repository's normal validation path for style and analyzers when one exists.
- If a reported violation appears to be a false positive, document the reasoning and use the narrowest justified suppression only when allowed by repository policy or explicit user instruction.
- Do not claim repository compliance based only on a build if the repository enforces style or analyzer rules through separate tooling.

## Change and Review Style
- Be concise but not shallow.
- Focus on actionable findings and robust fixes.
- Call out invariant violations, broken assumptions, migration risks, and notable trade-offs explicitly.
- Prefer clear explanations over rhetorical language.
