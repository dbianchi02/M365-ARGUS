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
- `Connect-Argus` (interactive delegated with tenant-wide consent, certificate, managed identity; optional
  Exchange Online and PnP, which warn instead of failing) and `Disconnect-Argus`. Detects tenant name and
  domains, Entra ID P1/P2 and concealed report names.
- Graph data layer: read-only `Invoke-ArgusGraphRequest` (GET only, paging, 429/503/504 retry with
  Retry-After and backoff, advanced queries, Graph host only), JSON batching (20 per batch, per-item
  retry), v1.0 usage-report CSV download, and 18 cached data sets with verified permissions and roles.
- `Get-ArgusRequiredPermission` (per check, aggregated, `-AsAppPermission`) and `Test-ArgusPrerequisite`
  (modules, connection, missing consent, signed-in user roles, licences, per-check readiness).
- Static test guaranteeing no write cmdlets and no non-GET Graph calls in the module.
- Entra ID checks ARG.ENT.001-013: inactive members / licensed users / guests (signInActivity with
  fallback), pending guest invitations, disabled users with licences (shared/room/equipment mailboxes
  excluded via optional Exchange data, Investigate without it), Global Administrator count (active +
  PIM eligible, role-assignable groups expanded, exclusions not applied), roles held by guests,
  ownerless security groups, stale devices, guest invitation, app registration and tenant creation
  settings, directory sync freshness.
- `Requires.OptionalDataSets` for data that improves a check when its service is connected.
- Report: Excel-like findings tables (one line per cell with tooltip, resizable columns with
  double-click to fit and keyboard resize, horizontal scroll; wrapping only when printed).
- Applications checks ARG.APP.001-006: secrets and certificates expiring within 30 days (rows already
  replaced by a newer credential are shown but do not fail the check), expired secrets and certificates
  still present, app registrations without owners, client secrets living longer than 24 months.
- ARG.APP.007: authentication certificates with a lifetime longer than 180 days.
- Licensing checks ARG.LIC.001-004: unused seats per paid SKU (free/viral SKUs ignored, configurable
  list), licence assignment errors (Error and ActiveWithError, with the assigning group), licensed
  shared mailboxes with no size, archive or hold that requires the licence (Investigate; needs Exchange
  Online, mailbox size read with `Get-EXOMailboxStatistics`), and paid licences assigned directly instead
  of through groups (free, viral and trial SKUs ignored; flags direct assignments that duplicate a group
  assignment).
- ARG.ENT.002: at least two emergency access (break-glass) accounts that follow Microsoft's configuration
  requirements (cloud-only, *.onmicrosoft.com, direct active Global Administrator).
- ARG.ENT.005: LinkedIn account connections, always Investigate with manual verification steps
  (the setting is not exposed by Microsoft Graph).
- Groups & Teams checks ARG.GRP.001-008: public groups, groups without owners or with a single owner,
  expiration policy, group creation, naming policy, inactive Teams (usage report) and ownerless Teams
  with guests.
- SharePoint checks ARG.SPO.001-005: orphaned sites (group-connected via Graph, other sites via PnP),
  inactive sites, organisation sharing level, sites near quota and OneDrives of disabled or deleted users.
- Exchange checks ARG.EXO.001-003: shared mailboxes with sign-in enabled, distribution groups without
  owner and inactive user mailboxes.
- Data sets `Subscriptions` (trial detection) and `SharePointSites` (PnP); shared free/viral SKU list.
- Report-based checks return Investigate when names are concealed or the report has no rows
  (Reports Reader missing).
- New area **Copilot & Agents** (`ARG.COP.001`–`011`): self-service purchase/trials of Copilot products
  (MSCommerce), self-service trial sign-up, Anthropic as subprocessor and Anthropic models with Data
  Retention, agent creation and org-wide sharing (manual reviews, Info, no score impact), web search
  and enhanced personalization (Graph beta), unused Copilot licences (Copilot usage report), external
  agents available to all and overdue agent requests (Agent 365 Package Management API).
- Exchange checks `ARG.EXO.004`–`008`: mailboxes near quota, user mailboxes of disabled accounts,
  shared mailboxes without delegates, empty distribution groups, inactive shared mailboxes.
- SharePoint & OneDrive checks `ARG.SPO.006`–`012`: site creation, OneDrive retention for deleted users,
  guest access expiration, Anyone link expiration, default sharing link, sites allowing Anyone links,
  OneDrives near quota.
- `Connect-Argus -Service All` connects every available service (missing modules or prerequisites are
  skipped with a warning).
- Optional service `Commerce` (`Connect-Argus -Service Commerce`, MSCommerce module, Windows and
  interactive only). MSCommerce runs in a separate pwsh process because its MSAL version cannot be
  loaded next to Graph, Exchange and PnP; only the product policies come back. Licence detection for Microsoft 365 Copilot (M365_COPILOT_APPS) and Agent 365
  (AGENT_365); data sets SharePointTenant, SharedMailboxPermissions, DistributionGroupMembers,
  CopilotUsage, CopilotWebSearchPolicy, CopilotPersonalization, CopilotPackages, CommercePolicies.
- `Invoke-ArgusGraphRequest -Raw` for entities that have their own `value` property; Graph errors with
  status 422 are recognised.
- Governance checks (final numbering): `ARG.ENT.002` licensed users without manager or department,
  `ARG.ENT.006` guests without a sponsor, `ARG.LIC.003` paid licences assigned to guests,
  `ARG.LIC.004` users with overlapping licences (service-plan based), `ARG.SPO.007` sites without a
  sensitivity label, `ARG.EXO.007` mailboxes with forwarding configured (inventory),
  `ARG.EXO.008` user mailboxes without a mailbox hold (informational, Info). Data sets UserManagers and
  GuestSponsors; Mailboxes add forwarding properties, SharePointSites adds SensitivityLabel.
- Console banner at the start of `Invoke-Argus`: ASCII wordmark, version (`[Preview]` for prerelease
  builds), author and copyright read from the manifest. `-NoBanner` turns it off.
- `ARG.COP.009` users can register agent identity blueprints
  (`defaultUserRolePermissions.allowedToCreateAgentIdentityBlueprints`, Graph beta only and not yet on Learn;
  Skipped until the tenant returns the property, rollout from 4 November 2026). Data set AuthorizationPolicyBeta.

### Changed

- **Check IDs renumbered before the first release** so that, inside each area, checks follow their
  categories. IDs mentioned in the entries above use the previous numbering. Old → new:
  ENT 002→007, 003→005, 005→012, 006→008, 007→009, 008→013, 009→014, 010→003, 011→010, 012→011, 013→015;
  APP 001→002, 002→003, 003→005, 004→006, 005→001, 006→004;
  LIC 001→006, 002→005, 003→007, 004→008, 005→001, 006→002;
  GRP 001→007, 002→004, 003→005, 004→003, 005→001, 006→002, 007→008, 008→006;
  SPO 001→008, 002→009, 003→002, 004→010, 005→012, 006→001, 007→011, 008→005, 009→004, 010→003, 011→006, 012→013;
  EXO 002→009, 003→004, 004→006, 006→002, 007→010, 008→003;
  COP 003→004, 004→005, 005→008, 006→010, 007→006, 008→007, 009→003, 010→011, 011→012. Unlisted IDs are unchanged.
  Configuration overrides (`Checks` in the config file) must use the new IDs.
- ARG.EXO.006 (mailboxes near quota) measures against the Issue Warning Quota (Prohibit Send when no
  warning quota is set) and shows the mailbox type, so shared mailboxes, which receive no warnings, stand out.

- ARG.ENT.005 (disabled users with licences) is now ARG.LIC.005 and the former ARG.ENT.002 (licensed
  users inactive for 90 days) is now ARG.LIC.006. ARG.ENT.002 and ARG.ENT.005 are reused for the emergency access and LinkedIn checks;
  configuration overrides for the old IDs must be renamed.
- ARG.LIC.001 ignores trial SKUs; ARG.LIC.003 uses 50 GB as the size that justifies a licence.
- Report: To review (Investigate) is shown in orange with its own counter, bar segment, legend entry
  and filter; Error, Skipped and Not run stay grey under Other. Page title is just `ARGUS`.
- Report overview redesigned as the "Iris": every check is a segment around an iris (grouped by area,
  coloured by status, length by severity, click to open), score and grade in the pupil, next to an
  assessment verdict, status counters, failed-by-severity strip and the top 5 priorities. Replaces
  the score bar and the three charts.
- Report overview: a head band shows the governance score as a large percentage with grade pill,
  weighted points earned and a F–A grade scale, beside the assessment. The pupil and area labels
  show the score as a percentage; area labels in the upper half no longer touch the area arc.
  The score uses one continuous red → orange → yellow → green spectrum: the grade scale shows the
  spectrum (veiled above the score) and the score number is a gradient of the stretch leading to it.
- Report areas: a "Where the score is lost" card fills the free space of the last row of area cards:
  a line chart of the weighted points not earned per area, coloured by points lost (above 15 red,
  above 10 orange, above 5 yellow, 5 or less yellow-green), drawn when it scrolls into view,
  with hover details; the expand button opens a compact zoom (at most 62% of the screen) with a
  larger chart and a scrollable detail table.
- Report header: a grey "Preview" label next to the ARGUS wordmark for prerelease versions.

### Fixed

- Usage-report checks no longer show an empty site URL when the report leaves `Site URL` blank
  (Microsoft advisory SP676147): ARG.SPO.009 and ARG.SPO.010 resolve it from the `Site Id`,
  ARG.SPO.012 and ARG.SPO.013 from the user's `mySite` (or the OneDrive naming convention for deleted
  users, shown in `UrlSource`). ARG.SPO.009 skips system sites (search center, compliance policy center,
  tenant fundamental site, app catalog) and shows "Not reported" when the report has no owner.
- ARG.SPO.009 and ARG.SPO.010: private group and channel sites, which a delegated `GET /sites/{id}`
  cannot read when the account is not a member, now get their URL from the PnP tenant site list
  (`SharePointSites` adds `SiteId`, optional data set). Without PnP the summary counts the sites whose URL
  could not be read.
- `Connect-Argus` interactive: `-ClientId` is used only for PnP, so Graph no longer fails when the PnP
  app registration is not set up for Graph sign-in.
- `Connect-Argus` interactive: Exchange Online connects with `-DisableWAM` (ExchangeOnlineManagement
  3.7.2+), avoiding the WAM NullReferenceException in PowerShell 7 terminals.
- `Mailboxes` data set now includes archive status, litigation hold and in-place holds.
