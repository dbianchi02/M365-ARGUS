# ARGUS — Technical Specification (v0.1 beta)

## 1. Goal

Run a catalogue of read-only governance checks against a Microsoft 365 tenant (Maester-style experience, governance-only scope), compute a weighted **Governance Score**, and export:

1. a self-contained **HTML report** (dashboard + per-check detail with findings and remediation);
2. a **JSON results file** (machine-readable, diffable between runs, re-renderable into HTML);
3. optionally one **CSV per failed check** with the full findings list.

Target users: M365 administrators and MSPs running periodic governance assessments on customer tenants (interactive or unattended).

## 2. Design decisions

| Decision | Choice | Why |
|---|---|---|
| Test engine | **Custom lightweight runner**, not Pester | Governance checks return *lists of offending objects* plus counts and thresholds, not a boolean assertion. A custom result object makes scoring, findings tables and remediation first-class. Pester is used only to unit-test the module itself. |
| Graph client | `Microsoft.Graph.Authentication` + `Invoke-MgGraphRequest` | Small install footprint, no SDK version conflicts, full control over paging/retry. |
| Report | Single HTML file, data embedded as JSON, vanilla JS | Works offline, can be emailed to a customer, no CDN/privacy issues. |
| PowerShell | 7.2+ | Cross-platform, `ForEach-Object -Parallel` available later, modern syntax. |
| Extensibility | Checks discovered from `Checks/**` and optionally from a user folder (`-CustomCheckPath`) | Lets MSPs add their own checks without forking. |

## 3. Public cmdlets (v0.1)

| Cmdlet | Purpose |
|---|---|
| `Connect-Argus` | Connects Graph (and optionally EXO / PnP). Parameter sets: **Interactive** (delegated, default), **Certificate** (`-ClientId -TenantId -CertificateThumbprint`), **ManagedIdentity**. `-Service Graph,Exchange,SharePoint`. Requests only the read scopes from `Get-ArgusRequiredPermission`. |
| `Disconnect-Argus` | Disconnects all sessions opened by ARGUS. |
| `Test-ArgusPrerequisite` | Reports modules, connections, granted scopes/roles, detected licences (Entra ID P1/P2) and which checks would be skipped and why. |
| `Get-ArgusRequiredPermission` | Lists Graph permissions + directory roles + EXO role needed, per check and aggregated (`-AsAppPermission` for app-registration setup). |
| `Get-ArgusCheck` | Lists the catalogue with metadata; filter by `-Area -Severity -Id -Tag`. |
| `New-ArgusConfig` | Writes a config JSON with defaults to a path, for customisation. |
| `Invoke-Argus` | Runs checks and writes outputs. Params: `-Area -Id -ExcludeId -Tag -ConfigPath -OutputPath -OutputFormat Html,Json,Csv -NoBrowser -PassThru -CustomCheckPath -MaxFindingsInHtml (default 500)`. Returns the results object with `-PassThru`. |
| `Export-ArgusReport` | Re-renders HTML from an existing results JSON (`-InputPath`). Used also for the sample report. |

Console output at the end of `Invoke-Argus`: compact summary (score, grade, counts per status, path of the report).

## 4. Check contract

Each file in `Checks/<Area>/ARG.<AREA>.<NNN>.ps1` calls `Register-ArgusCheck` (private) with a hashtable:

```powershell
Register-ArgusCheck @{
    Id            = 'ARG.ENT.001'
    Title         = 'Users inactive for more than {InactiveDays} days'
    Area          = 'EntraID'            # EntraID | Applications | Licensing | GroupsTeams | SharePoint | Exchange
    Category      = 'Identity lifecycle' # free text, used for grouping inside the area
    Severity      = 'Medium'             # Critical | High | Medium | Low | Info
    Description   = 'What the check evaluates (markdown).'
    Rationale     = 'Why it matters for governance (markdown).'
    Remediation   = @{
        Steps     = 'Numbered steps in the admin portal (markdown).'
        PowerShell= 'Sample remediation snippet (NOT executed by ARGUS).'
        PortalUrl = 'https://entra.microsoft.com/...'
    }
    References    = @( @{ Title = '...'; Url = 'https://learn.microsoft.com/...' } )
    Requires      = @{
        Services      = @('Graph')                # Graph | Exchange | SharePoint
        GraphScopes   = @('User.Read.All','AuditLog.Read.All')
        Licenses      = @('AAD_PREMIUM')          # optional: P1 needed for signInActivity
        DataSets      = @('Users')                # cached datasets it consumes
    }
    Parameters    = @{ InactiveDays = 90 }        # defaults, overridable from config
    Tags          = @('Lifecycle','Users')
    UsesBeta      = $false
    Test          = {
        param($Context)  # $Context.Config, $Context.Data, $Context.Parameters, $Context.Now
        # return New-ArgusResult ...
    }
}
```

`New-ArgusResult` builds the result:

| Field | Notes |
|---|---|
| `Status` | `Passed` · `Failed` · `Investigate` (manual review needed, e.g. setting acceptable in some orgs) · `Skipped` (prerequisite missing — reason mandatory) · `Error` (exception — message mandatory) · `NotRun` (excluded by filter) |
| `Summary` | One sentence, e.g. `37 of 1,204 enabled users have not signed in for 90+ days.` |
| `AffectedCount` / `EvaluatedCount` | Numbers shown in the report and used for trend. |
| `Findings` | Array of flat `PSCustomObject` (same properties per row) → findings table. Include identifiers useful for remediation (UPN, ObjectId, last sign-in, licences…). |
| `FindingColumns` | Ordered column list for the table. |
| `SkipReason` / `ErrorMessage` | As applicable. |
| `Duration` | Set by the runner. |

Runner rules: checks run sequentially in v0.1; data sets are prefetched once based on the union of `Requires.DataSets` of the selected checks; a check whose `Requires` aren't met is Skipped *before* execution with an explicit reason (`Entra ID P1 licence not detected — signInActivity unavailable`, `Not connected to Exchange Online`, `Missing scope AuditLog.Read.All`).

## 5. Configuration (`argus.default.json`)

```json
{
  "Exclusions": {
    "UserPrincipalNames": ["breakglass01@contoso.onmicrosoft.com"],
    "ObjectIds": [],
    "GroupIds": [],
    "SiteUrls": [],
    "AppIds": []
  },
  "Checks": {
    "ARG.ENT.001": { "Enabled": true, "Parameters": { "InactiveDays": 90 }, "Severity": "Medium" }
  },
  "Scoring": { "Weights": { "Critical": 10, "High": 5, "Medium": 3, "Low": 1, "Info": 0 }, "InvestigateCredit": 0.5 },
  "Report":  { "MaxFindingsInHtml": 500, "CompanyName": "", "LogoPath": "" }
}
```

Global exclusions apply to every check (emergency-access accounts, service accounts). Per-check overrides for parameters, severity, enabled.

## 6. Scoring

- Weight per check = `Scoring.Weights[Severity]`.
- Credit: Passed = 1, Investigate = `InvestigateCredit` (0.5), Failed = 0.
- Skipped, Error, NotRun are **excluded** from the denominator.
- `Score = round(100 × Σ(weight × credit) / Σ(weight of evaluated checks))`.
- Same formula per Area → area score.
- **Coverage** = evaluated weight / total weight of selected checks. If coverage < 70 %, the score is labelled *Partial* in the report so errors/skips can't inflate it.
- Grade: A ≥ 90 · B ≥ 75 · C ≥ 60 · D ≥ 40 · F < 40.
- Scoring logic lives in one private function (`Get-ArgusScore`) with dedicated Pester tests (edge cases: zero evaluated checks, all skipped, Info-only).

## 7. Data layer

- `Invoke-ArgusGraphRequest -Uri -Method GET -All -Headers -Beta`: follows `@odata.nextLink`, handles 429/503 with `Retry-After` + exponential backoff (max 5 retries), adds `ConsistencyLevel: eventual` + `$count=true` for advanced queries, returns plain objects.
- `Get-ArgusData -Name <DataSet>`: per-run cache. Initial data sets:
  `Users` (id, UPN, displayName, userType, accountEnabled, createdDateTime, externalUserState, externalUserStateChangeDateTime, assignedLicenses, signInActivity *if P1*, onPremisesSyncEnabled), `Groups` (Unified + security, visibility, owners count), `DirectoryRoles` (active + eligible assignments), `Applications` (password/key credentials, owners), `SubscribedSkus`, `Organization`, `AuthorizationPolicy`, `GroupSettings`, `GroupLifecyclePolicies`, `Devices`, `ReportSettings`, `TeamsActivity` (report), `SharePointSiteUsage` (report), `SharePointTenantSettings`, `Mailboxes` (EXO: RecipientTypeDetails, for shared/resource exclusion).
- Licence detection: from `subscribedSkus` servicePlans (`AAD_PREMIUM`, `AAD_PREMIUM_P2`).
- **Concealed report names**: if `admin/reportSettings.displayConcealedNames` is `true`, usage reports return hashed names/URLs. Checks based on reports must then return `Investigate` with an explanatory summary instead of wrong data, and the report shows a banner.
- Group owners: avoid N+1 calls — use `$expand=owners($select=id)` or JSON `$batch` (20 requests per batch); verify limits on Learn.

## 8. Check catalogue v0.1

Default thresholds are configurable. "Src" = main data source.

### Entra ID (`ENT`)
| Id | Check | Sev | Logic / Src |
|---|---|---|---|
| ARG.ENT.001 | Enabled members inactive > 90 d | Medium | `signInActivity.lastSuccessfulSignInDateTime` (fallback `lastSignInDateTime`); never signed in & created > 90 d counts as inactive. Requires P1. |
| ARG.ENT.002 | Enabled **licensed** users inactive > 90 d | High | As above ∩ `assignedLicenses` not empty. Findings include SKU names (wasted licences). |
| ARG.ENT.003 | Guests inactive > 90 d | Medium | `userType eq 'Guest'`, accepted, same inactivity logic. |
| ARG.ENT.004 | Guests that never accepted the invitation (> 30 d) | Medium | `externalUserState eq 'PendingAcceptance'` and `externalUserStateChangeDateTime`/`createdDateTime` older than threshold. |
| ARG.ENT.005 | Disabled users still licensed (excl. shared/room/equipment mailboxes) | High | `accountEnabled eq false` + licences; exclude objects whose mailbox RecipientTypeDetails is Shared/Room/Equipment (EXO). Without EXO → Investigate with note. |
| ARG.ENT.006 | Global Administrator count outside 2–4 | High | Active + PIM-eligible assignments of role template `62e90394-69f5-4237-9190-012177145e10`, expanding role-assignable groups. Fail if < 2 or > 4 (configurable). |
| ARG.ENT.007 | Privileged roles assigned to guests | High | Any directory role assignment whose principal is a guest. |
| ARG.ENT.008 | Security groups without owners | Low | Non-dynamic, non-role-assignable security groups, 0 owners. |
| ARG.ENT.009 | Stale devices (no sign-in > 180 d) | Low | `devices.approximateLastSignInDateTime`. |
| ARG.ENT.010 | Guest invitation restricted | Medium | `authorizationPolicy.allowInvitesFrom` = `everyone` → Failed; `adminsAndGuestInviters`/`adminsGuestInvitersAndAllMembers` → Passed/Investigate. |
| ARG.ENT.011 | Users can register applications | Medium | `defaultUserRolePermissions.allowedToCreateApps`. |
| ARG.ENT.012 | Users can create tenants | Low | `defaultUserRolePermissions.allowedToCreateTenants`. |
| ARG.ENT.013 | Directory sync freshness (hybrid only) | Medium | `organization.onPremisesLastSyncDateTime` older than 24 h → Failed; cloud-only → Skipped. |

### Applications (`APP`)
| Id | Check | Sev | Logic |
|---|---|---|---|
| ARG.APP.001 | Client secrets expiring within 30 d | Medium | `passwordCredentials.endDateTime`. |
| ARG.APP.002 | Expired client secrets still present | Low | endDateTime < now. |
| ARG.APP.003 | Certificates expiring within 30 d | Medium | `keyCredentials` (usage Verify). |
| ARG.APP.004 | Expired certificates still present | Low | |
| ARG.APP.005 | App registrations without owners | Medium | `/applications/{id}/owners` (batched). |
| ARG.APP.006 | Secrets with lifetime > 24 months | Low | endDateTime − startDateTime. |

### Licensing (`LIC`)
| Id | Check | Sev | Logic |
|---|---|---|---|
| ARG.LIC.001 | Unused licences per SKU (> 10 % or > 5 seats) | Medium | `subscribedSkus` prepaidUnits.enabled − consumedUnits; ignore free/viral SKUs (list in config). Findings: SKU friendly name, purchased, assigned, unused. |
| ARG.LIC.002 | Licence assignment errors | Medium | users' `licenseAssignmentStates` with `state eq 'Error'`. |
| ARG.LIC.003 | Shared mailboxes with a licence | Low / Investigate | Licensed shared mailboxes — legit only for > 50 GB, archive, holds → Investigate. Requires EXO. |

### Microsoft 365 Groups & Teams (`GRP`)
| Id | Check | Sev | Logic |
|---|---|---|---|
| ARG.GRP.001 | Public Microsoft 365 groups | Medium | Unified groups with `visibility eq 'Public'`; flag whether Team-enabled. |
| ARG.GRP.002 | M365 groups / Teams without owners | High | 0 owners. |
| ARG.GRP.003 | M365 groups / Teams with a single owner | Low | exactly 1 owner. |
| ARG.GRP.004 | Group expiration policy configured | Medium | `groupLifecyclePolicies` empty → Failed. |
| ARG.GRP.005 | Group creation restricted | Medium | `groupSettings` (Group.Unified) `EnableGroupCreation`. Unrestricted → Investigate. |
| ARG.GRP.006 | Group naming policy configured | Low | `PrefixSuffixNamingRequirement` / blocked words. |
| ARG.GRP.007 | Inactive Teams (> 180 d) | Low | `getTeamsTeamActivityDetail(period='D180')` lastActivityDate; honours concealed-names rule. |
| ARG.GRP.008 | Teams with guests and no owner | High | Intersection of guest members and ownerless. |

### SharePoint & OneDrive (`SPO`)
| Id | Check | Sev | Logic |
|---|---|---|---|
| ARG.SPO.001 | Orphaned sites | High | Group-connected sites whose group has 0 owners (Graph). Classic/communication sites without valid site admins via PnP if connected, otherwise those are reported as not evaluated in the summary. |
| ARG.SPO.002 | Inactive sites (> 180 d) | Low | `getSharePointSiteUsageDetail(period='D180')`. |
| ARG.SPO.003 | Tenant external sharing level | Medium / Investigate | `admin/sharepoint/settings.sharingCapability` = `externalUserAndGuestSharing` (Anyone links) → Investigate. |
| ARG.SPO.004 | Sites near storage quota (> 90 %) | Low | site usage report storageUsed / storageAllocated. |
| ARG.SPO.005 | OneDrive of deleted/disabled users with content | Low | OneDrive usage report owner vs Users dataset. |

### Exchange Online (`EXO`)
| Id | Check | Sev | Logic |
|---|---|---|---|
| ARG.EXO.001 | Shared mailboxes with sign-in enabled | Medium | Shared mailbox + corresponding user `accountEnabled eq true`. |
| ARG.EXO.002 | Distribution groups without owner (ManagedBy) | Low | `Get-EXORecipient`/`Get-DistributionGroup`. |
| ARG.EXO.003 | Inactive mailboxes (> 90 d, user mailboxes) | Low | Mailbox usage report lastActivityDate. |

The catalogue is a starting point: Claude Code must verify each data source on Microsoft Learn and propose adjustments (not silently change them) when an endpoint/property doesn't behave as described.

## 9. Required permissions (to verify per check)

Graph application/delegated, read-only: `User.Read.All`, `Group.Read.All`, `GroupMember.Read.All`, `Directory.Read.All`, `AuditLog.Read.All`, `Application.Read.All`, `RoleManagement.Read.Directory`, `RoleEligibilitySchedule.Read.Directory`, `Organization.Read.All`, `Policy.Read.All`, `Device.Read.All`, `Reports.Read.All`, `ReportSettings.Read.All`, `Sites.Read.All`, `SharePointTenantSettings.Read.All`.
Exchange: `Exchange.ManageAsApp` + Entra role **Global Reader** (app-only) or View-Only Organization Management (delegated).
Recommended delegated role for interactive runs: **Global Reader** (+ Reports Reader).

## 10. HTML report

### Look & feel
Minimal, functional, inspired by the Maester report layout. Neutral palette (near-white / near-black backgrounds, grey borders), **one accent colour**, status colours used only for status: Passed green, Failed red, Investigate amber, Error purple, Skipped grey, NotRun light grey. System font stack, monospace for IDs/code. Light/dark mode (follows `prefers-color-scheme`, manual toggle). Responsive down to tablet width. Print stylesheet (expanded details, no interactive controls) so it can be saved as PDF for a customer.

### Structure
1. **Header** — ARGUS logo/wordmark, tenant name + tenant ID, run date/time (with time zone), duration, account used, ARGUS version, optional customer logo/company from config.
2. **Score panel** — large Governance Score (0–100) as a ring gauge, grade letter, coverage %, *Partial* label when coverage < 70 %.
3. **KPI tiles** — Total, Passed, Failed, Investigate, Error, Skipped, NotRun. Clicking a tile filters the test list.
4. **Charts (inline SVG, no libraries)** — status donut; per-area horizontal stacked bars (status distribution) with area score; failed checks by severity.
5. **Areas overview table** — Area, score, Passed/Failed/Investigate/Error/Skipped, link to the area section (like Maester's block summary).
6. **Test list** — grouped by Area (EntraID, Applications, Licensing, Groups & Teams, SharePoint, Exchange), each group collapsible. Row: status badge, Id, Title, Severity, AffectedCount, duration. Toolbar: text search, filters (status, area, severity), sort, "expand all / collapse all", "show only failed".
7. **Test detail** (expandable row or side panel, deep-linkable via `#ARG.ENT.001`):
   - Status, severity, summary sentence, affected/evaluated counts;
   - *Description* and *Why it matters*;
   - *What was found* — findings table (first `MaxFindingsInHtml` rows, note "showing 500 of 3,214 — full list in CSV/JSON"), with per-table search and **Export CSV** button (client-side);
   - *How to fix* — numbered steps, portal link, PowerShell snippet in a code block with **Copy** button, clearly labelled "sample — review before running";
   - *References* (Learn links);
   - Skip reason / error message when relevant; parameters used (e.g. `InactiveDays = 90`).
8. **Footer** — permissions/scopes used, checks not evaluated and why, disclaimer, link to project repo.

### Implementation
- `Report/template.html` contains `<script type="application/json" id="argus-data">__ARGUS_DATA__</script>`; the renderer serialises results with `ConvertTo-Json -Depth 10 -Compress`, escapes `</` sequences, and inlines `report.css` + `report.js`.
- All tenant strings rendered via `textContent` / DOM APIs; markdown in Description/Remediation comes only from check metadata (trusted) and is rendered by a tiny internal markdown subset (paragraphs, lists, bold, code, links).
- Target: a 5,000-finding run must open smoothly; findings beyond the HTML cap stay in JSON/CSV.
- File name: `ARGUS-Report-<tenant>-<yyyyMMdd-HHmm>.html` (+ same base name `.json`).

## 11. Quality, CI and release

- Pester 5 unit tests with mocked `Invoke-ArgusGraphRequest` / EXO cmdlets and fixtures; one Passed + one Failed test per check; scoring and config-merge tests; a test asserting no check calls a non-GET Graph method.
- `ci.yml`: on PR/push, PSScriptAnalyzer + Pester on `ubuntu-latest` and `windows-latest`, upload sample report as artifact.
- `release.yml`: on tag `v*`, build, run tests, `Publish-Module -NuGetApiKey ${{ secrets.PSGALLERY_API_KEY }}`. Prerelease via `PrivateData.PSData.Prerelease = 'beta1'` → version `0.1.0-beta1`.
- Manifest: `CompatiblePSEditions = 'Core'`, `PowerShellVersion = '7.2'`, `RequiredModules = 'Microsoft.Graph.Authentication'`, tags (`M365`, `Governance`, `EntraID`, `SharePoint`, `Teams`, `Report`, `Graph`), ProjectUri, LicenseUri (MIT), ReleaseNotes.
- README: what ARGUS is / is not, quick start (`Install-Module ARGUS -AllowPrerelease`, `Connect-Argus`, `Invoke-Argus`), app-registration setup for unattended runs, permission table, check list (generated), screenshot of the sample report, how to write a custom check.

## 12. Out of scope for v0.1 (backlog)

Parallel execution, trend comparison between two JSON runs, multi-tenant batch runs for MSPs, PDF export, localisation (IT), Power BI export, anonymisation of findings (`-Anonymize`).
