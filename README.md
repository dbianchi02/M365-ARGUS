# ARGUS — Automated Report & Governance Utility Suite

[![CI](https://github.com/dbianchi02/M365-ARGUS/actions/workflows/ci.yml/badge.svg)](https://github.com/dbianchi02/M365-ARGUS/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

> **Status: 1.0.0-preview1.** The module is feature complete and has been run against production tenants, but it is a preview: check titles, thresholds and the JSON schema may still change before 1.0.0.

ARGUS is a PowerShell module that runs **read-only governance checks** against a Microsoft 365 tenant, computes a weighted **Governance Score** and produces a self-contained **HTML report** (plus JSON and optional CSV) listing every check, what was found and how to fix it.

See [`samples/sample-report.html`](samples/sample-report.html) for a report generated from fictitious data (download it and open it in a browser).

<img width="1279" height="940" alt="image" src="https://github.com/user-attachments/assets/8c0292d8-c053-4697-8f9e-6f5ccd934080" />


## What ARGUS is

- A **governance / hygiene** assessment of 73 checks across Entra ID, app registrations, licensing, Microsoft 365 Groups & Teams, SharePoint & OneDrive, Exchange Online and Copilot & agents.
- **Strictly read-only**: it never writes, updates or deletes anything in the tenant. Remediation is text and sample code in the report, never executed.
- Cross-platform: PowerShell 7.2+ on Windows, macOS and Linux.
- Lightweight: only `Microsoft.Graph.Authentication` is required. `ExchangeOnlineManagement`, `PnP.PowerShell` and `MSCommerce` are optional; checks that need a missing module or connection are reported as **Skipped** with the reason, never as errors.
- A single HTML file with no external dependencies (no CDN, no web fonts), light and dark mode, printable as PDF.

## What ARGUS is not

- **Not a security baseline**: no CIS / CISA / MFA / Conditional Access / Defender checks. Use dedicated tools (for example [Maester](https://maester.dev)) for that.
- **Not a remediation tool**: it tells you what to change; you decide and apply it.

## Requirements

| Component | Needed for | Notes |
|---|---|---|
| PowerShell 7.2+ | everything | Windows, macOS or Linux |
| `Microsoft.Graph.Authentication` 2.0+ | all Graph checks | installed automatically with ARGUS |
| `ExchangeOnlineManagement` 3.7.2+ | Exchange checks, shared-mailbox detection | optional |
| `PnP.PowerShell` 2.x+ | classic site administrators, site sharing and labels, private site URLs | optional, needs its own app registration (`-ClientId`) |
| `MSCommerce` | Copilot self-service purchase policies | optional, interactive sign-in on Windows only |

Some checks need a licence in the tenant (Entra ID P1/P2 for sign-in activity, Microsoft 365 Copilot for Copilot usage); without it they are Skipped.

## Installation

```powershell
Install-Module ARGUS -AllowPrerelease -Scope CurrentUser
# Optional modules
Install-Module ExchangeOnlineManagement, PnP.PowerShell -Scope CurrentUser
```

## Quick start

```powershell
Connect-Argus                     # Graph only, interactive sign-in in the browser
Invoke-Argus                      # runs every check, writes HTML + JSON to ./output and opens the report
```

To include Exchange Online, SharePoint (PnP) and, on Windows, the Commerce policies:

```powershell
Connect-Argus -Service All -ClientId <PnP app registration client id>
Invoke-Argus
```

Before the first run, `Test-ArgusPrerequisite` lists the missing modules, connections, scopes and licences, and which checks would be skipped.

### Interactive sign-in and roles

- The first time ARGUS is used in a tenant, sign in with an account that can grant **tenant-wide admin consent** for delegated Microsoft Graph permissions (Application Administrator, Cloud Application Administrator or Global Administrator) and accept *Consent on behalf of your organization*. Only read scopes are requested.
- With delegated access ARGUS sees only what the signed-in user can read: **Global Reader + Reports Reader** is the recommended combination.
- Graph and Exchange Online sign in with their own Microsoft apps. `-ClientId` is used only for PnP.PowerShell, which requires an app registration of your own (see [PnP: register an Entra ID application](https://pnp.github.io/powershell/articles/registerapplication.html)).

### Usage reports with concealed names

If *Display concealed user, group, and site names in all reports* is on (Microsoft 365 admin center > Settings > Org settings > Reports), usage reports return hashed names. The checks based on them (inactive sites, Teams, mailboxes, OneDrive, Copilot licences) then return **To review** instead of wrong data, and the report shows a banner. Turn the setting off for the duration of the assessment to get those results.

### Common options

```powershell
Invoke-Argus -Area EntraID, Licensing                     # only some areas
Invoke-Argus -Id ARG.SPO.009, ARG.SPO.010                 # only some checks
Invoke-Argus -ExcludeId ARG.EXO.008 -OutputFormat Html, Json, Csv -NoBrowser
Invoke-Argus -ConfigPath ./contoso.config.json -OutputPath ./reports
$result = Invoke-Argus -PassThru -NoBrowser -NoBanner     # results object for scripting

Export-ArgusReport -InputPath ./output/ARGUS-Report-contoso-20261021-1144.json   # re-render the HTML from JSON
```

## Unattended runs (app-only)

```powershell
# Certificate
Connect-Argus -TenantId contoso.onmicrosoft.com -ClientId <app id> -CertificateThumbprint <thumbprint> -Service Graph, Exchange, SharePoint
# Managed identity (Azure Automation, Azure Functions, VMs)
Connect-Argus -ManagedIdentity
Invoke-Argus -NoBrowser -NoBanner
```

The app registration needs the Microsoft Graph **application** permissions listed by `Get-ArgusRequiredPermission -Aggregate -AsAppPermission`, granted by a Privileged Role Administrator or Global Administrator. For Exchange Online add `Exchange.ManageAsApp` and the Entra role Global Reader to the app. The Commerce checks are not available app-only.

## Permissions

All permissions are read-only. The exact list per check, or aggregated, comes from the check metadata:

```powershell
Get-ArgusRequiredPermission -Aggregate                     # what Connect-Argus requests (delegated)
Get-ArgusRequiredPermission -Aggregate -AsAppPermission    # for an app registration
Get-ArgusRequiredPermission -Id ARG.ENT.001                # one check
```

Microsoft Graph scopes in the full catalogue: `Application.Read.All`, `AuditLog.Read.All`, `CopilotPackages.Read.All`, `CopilotPolicySettings.Read`, `Device.Read.All`, `Directory.Read.All`, `Group.Read.All`, `GroupMember.Read.All`, `GroupSettings.Read.All`, `LicenseAssignment.Read.All`, `Organization.Read.All`, `PeopleSettings.Read.All`, `Policy.Read.All`, `Reports.Read.All`, `ReportSettings.Read.All`, `RoleEligibilitySchedule.Read.Directory`, `RoleManagement.Read.Directory`, `SharePointTenantSettings.Read.All`, `Sites.Read.All`, `User.Read.All`.

Exchange Online: Global Reader or the View-Only Organization Management role group.

## Governance Score

Each check has a severity weight (Critical 10, High 5, Medium 3, Low 1, Info 0). Passed checks get full credit, *To review* half credit, Failed none; Skipped, Error and Not run checks are left out.

`Score = round(100 × Σ(weight × credit) / Σ(weight of evaluated checks))`, also computed per area. Grades: A ≥ 90, B ≥ 75, C ≥ 60, D ≥ 40, F < 40. When less than 70 % of the selected weight could be evaluated, the score is labelled *Partial*.

## Configuration

`New-ArgusConfig -Path ./contoso.config.json` writes the defaults. You can set global exclusions (for example emergency-access accounts), per-check parameters, severity or `Enabled`, scoring weights and report branding:

```json
{
  "Exclusions": { "UserPrincipalNames": ["breakglass01@contoso.onmicrosoft.com"], "ObjectIds": [], "GroupIds": [], "SiteUrls": [], "AppIds": [] },
  "Checks": { "ARG.ENT.001": { "Enabled": true, "Parameters": { "InactiveDays": 60 }, "Severity": "High" } },
  "Scoring": { "Weights": { "Critical": 10, "High": 5, "Medium": 3, "Low": 1, "Info": 0 }, "InvestigateCredit": 0.5 },
  "Report": { "MaxFindingsInHtml": 500, "CompanyName": "Contoso IT", "LogoPath": "./logo.png" }
}
```

## Check catalogue

| Area | Checks | Examples |
|---|---|---|
| Entra ID (`ARG.ENT`) | 15 | inactive members and guests, guests without sponsor, break-glass accounts, Global Administrator count, stale devices |
| Applications (`ARG.APP`) | 7 | app registrations without owners, expiring or long-lived secrets and certificates |
| Licensing (`ARG.LIC`) | 8 | licences on disabled or inactive users, overlapping licences, unused licences per SKU |
| Groups & Teams (`ARG.GRP`) | 8 | group creation, naming and expiration policies, ownerless groups and Teams, inactive Teams |
| SharePoint & OneDrive (`ARG.SPO`) | 13 | sharing defaults, Anyone links, orphaned and inactive sites, storage quotas, OneDrive of departed users |
| Exchange Online (`ARG.EXO`) | 10 | shared mailboxes with sign-in, inactive mailboxes, forwarding, distribution groups without owner |
| Copilot & agents (`ARG.COP`) | 12 | self-service purchase and trials, unused Copilot licences, web search, agent sharing and requests |

The full catalogue, with one page per check (what is checked, why it matters, how to fix it, permissions, parameters and references), is in [docs/checks](docs/checks/README.md). `Get-ArgusCheck` returns the same metadata in PowerShell.

## Custom checks

Checks are discovered from the built-in `Checks/` folder and from any folder passed with `-CustomCheckPath`. A check is one `.ps1` file that calls `Register-ArgusCheck` with its metadata and a `Test` script block returning `New-ArgusResult`; use any built-in check as a template, and see §4 of the [specification](docs/ARGUS-SPEC.md) for the full contract. Custom checks must stay read-only.

```powershell
Invoke-Argus -CustomCheckPath ./my-checks
```

## Development

```powershell
./build/build.ps1 -Task Lint      # PSScriptAnalyzer
./build/build.ps1 -Task Test      # Pester (Graph fully mocked)
./build/build.ps1 -Task Docs      # regenerate docs/checks from the check metadata
./build/build.ps1 -Task Sample    # regenerate samples/sample-report.html from fixtures
./build/build.ps1 -Task Package   # stage the module for publishing
```

See [CONTRIBUTING.md](CONTRIBUTING.md), the [CHANGELOG](CHANGELOG.md) and the full specification in [docs/ARGUS-SPEC.md](docs/ARGUS-SPEC.md).

## Disclaimer

ARGUS is provided "as is", without warranty of any kind. Findings depend on the permissions and licences available to the account that runs it; review them before acting. ARGUS is not affiliated with or endorsed by Microsoft.

## License

[MIT](LICENSE) © 2026 Davide Bianchi
