# dotnet.instructions.md

## Command policy
Prefer repository-local or task-local scope over whole-repo commands when possible.

Typical .NET command sequence:

```bash
# If restore is required
 dotnet restore <solution-or-project>

# Build
 dotnet build <solution-or-project> --no-restore

# Smallest relevant test scope
 dotnet test <test-project-or-solution> --no-build

# Apply style/analyzer fixes from .editorconfig and analyzers
 dotnet format <solution-or-project> --no-restore

# Final verification: fail if any formatting/analyzer drift remains
 dotnet format <solution-or-project> --no-restore --verify-no-changes
```

Rules:
- Do not use `dotnet format --verify-no-changes` as the only formatting step for implementation tasks. That only checks; it does not fix.
- If `--no-restore` fails because restore has not yet happened, run restore once and continue.
- If tests fail, do not stop at the first red run. Investigate, fix, and rerun the smallest relevant build/test scope until the targeted tests pass or a concrete blocker prevents further progress.
- Treat red tests caused by your changes as part of the task, not as optional follow-up work.
- If a test is broken for reasons unrelated to your change, identify the evidence clearly and continue validating the remaining relevant scope where possible.
- If the repo uses a different validation entry point, such as scripts, CI wrappers, `Makefile` targets, or PowerShell helpers, prefer that path and mention it in the report.
- Never finish an implementation task while knowingly leaving newly introduced analyzer/style violations unresolved unless the user explicitly allows it.
- Never finish an implementation task while knowingly leaving newly failing relevant tests unresolved unless the user explicitly allows it or you have hit a concrete blocker that you report.

---

## .editorconfig and analyzer compliance
Treat `.editorconfig`, analyzer configuration, and project analysis settings as part of the repository contract.

For .NET repositories:
- Assume `.editorconfig` is authoritative for whitespace, code style, naming, and analyzer configuration.
- Respect warnings and errors from SDK analyzers and any repository-installed analyzers.
- Prefer fixing the code over suppressing the diagnostic.
- If a violation appears to be a false positive, document it and use the narrowest justified suppression only if the user allows repository rule exceptions.

Important:
- Command-line `dotnet build` does not automatically enforce all IDE code-style diagnostics unless the project enables build enforcement for code-style analysis.
- Therefore, for implementation tasks, do not rely on build alone to prove `.editorconfig` compliance. Run `dotnet format` as part of validation.
- If the repository expects IDE-style rules to fail on build, recommend project-level enforcement such as `EnforceCodeStyleInBuild=true` and appropriate rule severities when that is not already configured.

---
