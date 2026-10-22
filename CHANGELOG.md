# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed

- App-only sign-in with a certificate is now validated on Windows for Microsoft Graph, Exchange Online and
  SharePoint (PnP). The README documents the full setup: app registration, application permissions
  (Microsoft Graph, `Exchange.ManageAsApp` from Office 365 Exchange Online, SharePoint
  `Sites.FullControl.All`), the Global Reader role for Exchange, certificate creation and upload, and the
  common setup errors. Managed identity remains implemented but not validated.

## [1.0.0] - 2026-10-21

First stable release, validated with interactive runs on production tenants of different sizes. It supersedes
1.0.0-preview1, published earlier the same day with the same features.

### Added

- **73 read-only governance checks** in seven areas: Entra ID (15), app registrations (7), licensing (8),
  Microsoft 365 Groups & Teams (8), SharePoint & OneDrive (13), Exchange Online (10), Copilot & agents (12).
  Every check carries its description, rationale, remediation steps with a sample script, portal link,
  Microsoft Learn references, required permissions and configurable parameters.
- **Governance Score**: severity-weighted score with grades A to F, per area and overall; "to review" results
  earn half credit, checks that cannot run are left out and low coverage is labelled *Partial*.
- **Self-contained HTML report** (one file, no external dependencies, strict Content-Security-Policy):
  overview with score, score by area, results and priorities; checks grouped by area with search, filters
  and deep links; findings tables with filtering, sorting and CSV export; copyable remediation samples;
  light and dark theme; print stylesheet for PDF. Tenant data is always rendered as text.
- **Outputs**: HTML and versioned JSON (`SchemaVersion` 1.0) by default, plus one CSV per failed check
  with `-OutputFormat Csv`; `Export-ArgusReport` re-renders the HTML from a JSON file.
- **Cmdlets**: `Connect-Argus`, `Disconnect-Argus`, `Test-ArgusPrerequisite`, `Get-ArgusRequiredPermission`,
  `Get-ArgusCheck`, `New-ArgusConfig`, `Invoke-Argus`, `Export-ArgusReport`, with full comment-based help.
- **Sign-in**: interactive delegated sign-in with tenant-wide admin consent; certificate and managed identity
  for app-only runs. Exchange Online (ExchangeOnlineManagement), SharePoint (PnP.PowerShell) and Commerce
  (MSCommerce, Windows) are optional: when a module, connection, role or licence is missing, the checks that
  need it are **Skipped** with the reason and the run continues.
- **Data layer**: Microsoft Graph through `Microsoft.Graph.Authentication` only, GET requests only, paging,
  JSON batching, throttling retries honouring `Retry-After`, and tenant data fetched once per run.
  Graph v1.0 is used everywhere except three checks marked as using beta.
- **Usage reports**: concealed report names are detected (checks return *To review* and the report shows a
  banner); empty site and OneDrive URLs in the reports are resolved from the site ID, PnP or the user.
- **Configuration**: JSON file with global exclusions (users, groups, sites, apps), per-check parameters,
  severity and enablement, scoring weights and report branding (company name, logo).
- **Extensibility**: custom checks loaded from `-CustomCheckPath` with the same metadata contract.
- **Quality**: PSScriptAnalyzer and 1,100 Pester tests with Graph fully mocked, on Windows and Linux; a static
  test guarantees that the module contains no write cmdlet and no non-GET Graph call.
- **Documentation**: README with a step-by-step first run guide, one page per check in `docs/checks`,
  a demo report of a fictitious tenant.

### Known limitations

- App-only sign-in (certificate, managed identity) is implemented but not yet validated on a production tenant.
- ARG.COP.009 reads a Microsoft Graph beta property (`allowedToCreateAgentIdentityBlueprints`) that is not yet
  documented on Microsoft Learn; it is Skipped when the tenant does not return it.
- A read-only PnP app registration (narrower than the PnP defaults) has not been validated yet.
