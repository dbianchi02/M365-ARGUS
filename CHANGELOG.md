# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Repository scaffolding: module manifest (0.1.0-beta1) and loader, folder layout, build script
  (Lint / Test / Docs / Sample / Package), PSScriptAnalyzer settings, CI workflow on Ubuntu and Windows.
- Public cmdlet stubs with full comment-based help: `Connect-Argus`, `Disconnect-Argus`,
  `Test-ArgusPrerequisite`, `Get-ArgusRequiredPermission`, `Get-ArgusCheck`, `New-ArgusConfig`,
  `Invoke-Argus`, `Export-ArgusReport`.
- Pester tests for module import, exported cmdlets and help completeness.
- Check engine: `Register-ArgusCheck` metadata validation, check discovery from `Checks/**` and
  `-CustomCheckPath`, `New-ArgusResult` with the six statuses, sequential runner with filters (NotRun),
  prerequisite checks (Skipped), per-check isolation (Error), one-time data set prefetch, global
  exclusions and `{Placeholder}` resolution in titles and summaries.
- Configuration: `argus.default.json`, deep merge of user files, validation, per-check overrides.
- Scoring: `Get-ArgusScore` (weights, Investigate credit, coverage, Partial label, grades, per-area scores).
- Outputs: versioned results JSON (`SchemaVersion` 1.0), one CSV per failed check (formula-safe),
  console summary.
- `Get-ArgusCheck`, `New-ArgusConfig` and `Invoke-Argus -OutputFormat Json, Csv` are functional.
