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
- HTML report (single self-contained file, vanilla JS/CSS, strict Content-Security-Policy): header,
  score ring with grade and coverage, clickable KPI tiles, SVG status donut / area bars / failed-by-severity,
  areas table, checks grouped by area with search, filters, sorting, expand/collapse, deep links
  (`#ARG.ENT.001`), lazy check details with findings table (cap, filter, sort, client-side CSV export),
  remediation with copyable PowerShell sample, references, parameters, footer with permissions and
  checks not evaluated; light/dark theme with toggle; print stylesheet; concealed-names and Partial banners.
- Report design: minimal, document-like layout. Overview with score, one passed/failed bar and three
  counts; areas table; checks grouped by area (failed first); single-column check detail. Green and red
  only for Passed/Failed, every other status grey and written out; no shadows or decorative icons.
- `Export-ArgusReport` (re-render from results JSON, optional `-LogoPath`) and `Invoke-Argus -OutputFormat Html`.
- Realistic fictitious fixture (`tests/Fixtures/New-SampleResult.ps1`) and `samples/sample-report.html`.
