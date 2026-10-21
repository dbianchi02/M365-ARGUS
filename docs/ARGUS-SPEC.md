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
| `Connect-Argus` | Connects Graph (and optionally EXO / PnP). Parameter sets: **Interactive** (delegated, default), **Certificate** (`-ClientId -TenantId -CertificateThumbprint`), **ManagedIdentity**. `-Service Graph,Exchange,SharePoint,Commerce` or `-Service All` (every service whose module and prerequisites are available; the others are skipped with a warning — SharePoint needs `-ClientId` for interactive PnP, Commerce needs Windows + interactive). Default: Graph only. Requests only the read scopes from `Get-ArgusRequiredPermission`. |
| `Disconnect-Argus` | Disconnects all sessions opened by ARGUS. |
| `Test-ArgusPrerequisite` | Reports modules, connections, granted scopes/roles, detected licences (Entra ID P1/P2) and which checks would be skipped and why. |
| `Get-ArgusRequiredPermission` | Lists Graph permissions + directory roles + EXO role needed, per check and aggregated (`-AsAppPermission` for app-registration setup). |
| `Get-ArgusCheck` | Lists the catalogue with metadata; filter by `-Area -Severity -Id -Tag`. |
| `New-ArgusConfig` | Writes a config JSON with defaults to a path, for customisation. |
| `Invoke-Argus` | Runs checks and writes outputs. Params: `-Area -Id -ExcludeId -Tag -ConfigPath -OutputPath -OutputFormat Html,Json,Csv -NoBrowser -NoBanner -PassThru -CustomCheckPath -MaxFindingsInHtml (default 500)`. Returns the results object with `-PassThru`. |
| `Export-ArgusReport` | Re-renders HTML from an existing results JSON (`-InputPath`). Used also for the sample report. |

Console output of `Invoke-Argus`: at the start, an ASCII banner with name, version (`[Preview]` for prerelease builds), author and copyright from the manifest (`-NoBanner` to omit); at the end, a compact summary (score, grade, counts per status, path of the report).

## 4. Check contract

Each file in `Checks/<Area>/ARG.<AREA>.<NNN>.ps1` calls `Register-ArgusCheck` (private) with a hashtable:

```powershell
Register-ArgusCheck @{
    Id            = 'ARG.ENT.001'
    Title         = 'Users inactive for more than {InactiveDays} days'
    Area          = 'EntraID'            # EntraID | Applications | Licensing | GroupsTeams | SharePoint | Exchange | Copilot
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
        Services      = @('Graph')                # Graph | Exchange | SharePoint | Commerce
        GraphScopes   = @('User.Read.All','AuditLog.Read.All')
        Licenses      = @('AAD_PREMIUM')          # optional: P1 needed for signInActivity
        DataSets      = @('Users')                # cached datasets it consumes
        OptionalDataSets = @('Mailboxes')         # loaded only if their service is connected; absent from $Context.Data otherwise
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
  `Users` (id, UPN, displayName, userType, accountEnabled, createdDateTime, externalUserState, externalUserStateChangeDateTime, assignedLicenses, licenseAssignmentStates, signInActivity *if P1*, onPremisesSyncEnabled), `Groups` (Unified + security, visibility, owners count), `DirectoryRoles` (active + eligible assignments), `Applications` (password/key credentials, owners), `SubscribedSkus`, `Organization`, `AuthorizationPolicy`, `AuthorizationPolicyBeta`, `GroupSettings`, `GroupLifecyclePolicies`, `Devices`, `ReportSettings`, `TeamsActivity` (report), `SharePointSiteUsage` (report), `SharePointTenantSettings`, `Mailboxes` (EXO: RecipientTypeDetails, ExternalDirectoryObjectId, ArchiveStatus, LitigationHoldEnabled, InPlaceHolds).
- Licence detection: from `subscribedSkus` servicePlans (`AAD_PREMIUM`, `AAD_PREMIUM_P2`).

### Data sets as implemented (verified on Microsoft Learn, 2026-10-19)

Graph endpoints are **v1.0**, except CopilotWebSearchPolicy and CopilotPersonalization (beta, no v1.0 equivalent; their checks set `UsesBeta`). "Roles" = least-privileged built-in roles that can read the data with delegated sign-in.

| Data set | Endpoint | Permission | Roles (delegated) | Notes |
|---|---|---|---|---|
| Users | `GET /users?$select=…[,signInActivity]` | User.Read.All, AuditLog.Read.All | Global Reader | signInActivity needs Entra ID P1 + AuditLog.Read.All; `$top` max 500 when selected; `lastSuccessfulSignInDateTime` only populated since Dec 2023 (fallback to `lastSignInDateTime`). Without it users load without sign-in data (note recorded). |
| UserManagers | `GET /users?$filter=userType eq 'Member'&$select=id,department&$expand=manager($select=id,displayName)` | User.Read.All | Global Reader, Directory Readers | Department and manager per member (ARG.ENT.002). Separate from Users: directory objects expand one relationship per request. |
| GuestSponsors | `GET /users?$filter=userType eq 'Guest'&$select=id&$expand=sponsors($select=id,displayName)` | User.Read.All | Directory Readers, Guest Inviter, User Administrator | Sponsors per guest (ARG.ENT.006). Delegated reads need `microsoft.directory/users/sponsors/read`; 400/401/403 → `ArgusUnavailable` (check Skipped). |
| Groups | `GET /groups?$select=…&$expand=owners($select=…)` | Group.Read.All | Global Reader, Directory Readers | `$expand` returns max 20 owners, no paging: OwnerCount exact up to 19. Adds IsUnified, IsTeam, IsDynamic. |
| DirectoryRoles | `GET /roleManagement/directory/roleDefinitions`, `roleAssignments?$expand=principal`, `roleEligibilitySchedules?$expand=principal` | RoleManagement.Read.Directory, RoleEligibilitySchedule.Read.Directory | Global Reader | Eligible (PIM) only with Entra ID P2, otherwise `EligibleAvailable = $false`. |
| Applications | `GET /applications?$select=…&$expand=owners($select=…)` | Application.Read.All | Global Reader, Application Administrator | Credential metadata only (never secret values). |
| SubscribedSkus | `GET /subscribedSkus` | LicenseAssignment.Read.All | Global Reader, Directory Readers | Also licence detection. |
| Subscriptions | `GET /directory/subscriptions` | Organization.Read.All | Global Reader, Directory Readers | `isTrial` and status per subscription: trial SKU detection for ARG.LIC.003, ARG.LIC.004, ARG.LIC.006 and ARG.LIC.008. |
| Organization | `GET /organization` | Organization.Read.All | Global Reader, Directory Readers | Name, domains, sync status. |
| AuthorizationPolicy | `GET /policies/authorizationPolicy` | Policy.Read.All | Global Reader | |
| AuthorizationPolicyBeta | `GET /beta/policies/authorizationPolicy` | Policy.Read.All | Global Reader | Beta: allowedToCreateAgentIdentityBlueprints (ARG.COP.009). |
| GroupSettings | `GET /groupSettings` | GroupSettings.Read.All | Global Reader, Directory Readers | Empty when never configured. |
| GroupLifecyclePolicies | `GET /groupLifecyclePolicies` | Directory.Read.All | Global Reader, Directory Readers | Least privileged documented permission. |
| Devices | `GET /devices?$select=…` | Device.Read.All | Global Reader, Directory Readers | |
| ReportSettings | `GET /admin/reportSettings` | ReportSettings.Read.All | Reports Reader, Global Reader | `displayConcealedNames`. |
| TeamsActivity, SharePointSiteUsage, OneDriveUsage, MailboxUsage | `GET /reports/get…Detail(period='D180')` → 302 → CSV | Reports.Read.All | **Reports Reader** | v1.0 returns CSV (downloaded to a temp file, parsed, deleted). **Global Reader only sees tenant-level totals**, not per-object rows. |
| SharePointTenantSettings | `GET /admin/sharepoint/settings` | SharePointTenantSettings.Read.All | Global Reader, SharePoint Administrator | `sharingCapability`. |
| Mailboxes, DistributionGroups | `Get-EXOMailbox`, `Get-DistributionGroup` (EXO) | — (Exchange.ManageAsApp app-only) | Global Reader, View-Only Organization Management | Requires ExchangeOnlineManagement. Mailboxes also carry ForwardingSmtpAddress, ForwardingAddress, DeliverToMailboxAndForward (ARG.EXO.007) and LitigationHoldEnabled / InPlaceHolds (ARG.EXO.005, ARG.EXO.008). ARG.LIC.007 also calls `Get-EXOMailboxStatistics` (TotalItemSize) for licensed shared mailboxes only. |
| SharePointSites | `Get-PnPTenantSite` (PnP.PowerShell) | — (PnP app registration) | SharePoint Administrator, Global Reader | Optional (ARG.SPO.008, ARG.SPO.009, ARG.SPO.010). Url, SiteId (empty report URLs, ARG.SPO.009/010), Template, Owner, GroupId, SharingCapability (ARG.SPO.006), SensitivityLabel (ARG.SPO.007). Owner without `-Detailed` to be confirmed on a real tenant. |
| SharePointTenant | `Get-PnPTenant` (PnP.PowerShell) | — (PnP app registration) | SharePoint Administrator, Global Reader | Sharing settings Graph does not expose: ExternalUserExpirationRequired / ExpireInDays, RequireAnonymousLinksExpireInDays (0 = never), DefaultSharingLinkType, CoreDefaultShareLinkScope, OneDriveDefaultShareLinkScope, DefaultLinkPermission (Set-SPOTenant reference). |
| SharedMailboxPermissions | `Get-EXOMailboxPermission` per shared mailbox (EXO) | — | Global Reader, View-Only Organization Management | Explicit FullAccess trustees (not inherited, not denied, NT AUTHORITY\SELF ignored), keyed by ExternalDirectoryObjectId. One call per shared mailbox. |
| DistributionGroupMembers | `$batch` `GET /groups/{id}/members?$select=id&$top=1` | GroupMember.Read.All | Global Reader, Directory Readers | HasMembers per group of DistributionGroups ($null when unreadable). |
| CopilotUsage | `GET /copilot/reports/getMicrosoft365CopilotUsageUserDetail(period='D180')` → CSV | Reports.Read.All | Reports Reader, AI Administrator | Only users with a Microsoft 365 Copilot licence. Concealed names apply. |
| CopilotWebSearchPolicy | `GET /beta/copilot/admin/policySettings/microsoft.copilot.allowwebsearch` | CopilotPolicySettings.Read (delegated only) | AI Administrator (least-privileged reader not documented) | **Beta.** `value`/`policyId` null when not configured; 422 = group-scoped (not readable); 401/403 → `ArgusUnavailable`, check Skipped. Read with `-Raw` (the entity has its own `value`). Meaning of the values not documented. |
| CopilotPersonalization | `GET /beta/copilot/settings/people/enhancedpersonalization` | PeopleSettings.Read.All | Global Administrator (Learn) | **Beta.** isEnabledInOrganization, disabledForGroup (documented response wraps it in `value`). 401/403 → `ArgusUnavailable`. |
| CopilotPackages | `GET /copilot/admin/catalog/packages` and `?$filter=requestStatus eq 'pending'` | CopilotPackages.Read.All | AI Administrator | v1.0, **requires a Microsoft Agent 365 licence** (service plan AGENT_365; checks Skipped without it). Packages + PendingRequests. |
| CommercePolicies | `Get-MSCommerceProductPolicies -PolicyId AllowSelfServicePurchase` (MSCommerce 3.x) | — (own app, WAM broker) | Global Reader | **Windows + interactive only** (`Connect-Argus -Service Commerce`). ProductName, ProductId, PolicyValue (Enabled / OnlyTrialsWithoutPaymentMethod / Disabled). MSCommerce bundles its own MSAL (Microsoft.Identity.Client 4.67.2), which cannot load next to the MSAL of Graph/EXO/PnP, so `Connect-Argus` runs it in a **separate pwsh process** in the same console (`Get-ArgusCommercePolicy`): sign-in, Get-* only, JSON via a temp file (deleted). The policies are kept in memory for the session; the token never enters the ARGUS process. |

Core permissions always requested: Organization.Read.All, LicenseAssignment.Read.All, ReportSettings.Read.All, RoleManagement.Read.Directory. JSON `$batch` (POST envelope of GET sub-requests, max 20, per-item 429 retried) is the only POST ARGUS sends.
- **Concealed report names**: if `admin/reportSettings.displayConcealedNames` is `true`, usage reports return hashed names/URLs. Checks based on reports must then return `Investigate` with an explanatory summary instead of wrong data, and the report shows a banner.
- Group owners: avoid N+1 calls — use `$expand=owners($select=id)` or JSON `$batch` (20 requests per batch); verify limits on Learn.

## 8. Check catalogue v0.1

Default thresholds are configurable. "Src" = main data source.

### Entra ID (`ENT`)

| Id | Check | Sev | Logic / Src |
|---|---|---|---|
| ARG.ENT.001 | Enabled members inactive > 90 d | Medium | `signInActivity.lastSuccessfulSignInDateTime` (fallback `lastSignInDateTime`); never signed in & created > 90 d counts as inactive. Requires P1. |
| ARG.ENT.002 | Licensed users without manager or department | Low | Enabled licensed members (Users) whose `manager` or `department` is empty (UserManagers: `GET /users?$filter=userType eq 'Member'&$expand=manager`). |
| ARG.ENT.003 | Guest invitation restricted | Medium | `authorizationPolicy.allowInvitesFrom` = `everyone` → Failed; `adminsAndGuestInviters`/`adminsGuestInvitersAndAllMembers` → Passed/Investigate. |
| ARG.ENT.004 | Guests that never accepted the invitation (> 30 d) | Medium | `externalUserState eq 'PendingAcceptance'` and `externalUserStateChangeDateTime`/`createdDateTime` older than threshold. |
| ARG.ENT.005 | Guests inactive > 90 d | Medium | `userType eq 'Guest'`, accepted, same inactivity logic. |
| ARG.ENT.006 | Guests without a sponsor | Medium | Enabled guests with no `sponsors` (GuestSponsors: `GET /users?$filter=userType eq 'Guest'&$expand=sponsors`). Skipped when sponsors cannot be read (role). |
| ARG.ENT.007 | At least 2 emergency access (break-glass) accounts | High | Accounts from the `Accounts` parameter, or users matching `NamePatterns` (*breakglass*, *emergency*...). Compliant = enabled, member, cloud-only, UPN on *.onmicrosoft.com, direct **active** Global Administrator assignment (not only eligible, not via group). Fail if fewer than `MinCount` (2) compliant. Authentication methods, CA exclusions and alerting are security controls and out of scope. Exclusions not applied. Added 2026-10-19. |
| ARG.ENT.008 | Global Administrator count outside 2–4 | High | Active + PIM-eligible assignments of role template `62e90394-69f5-4237-9190-012177145e10`, expanding role-assignable groups. Fail if < 2 or > 4 (configurable). |
| ARG.ENT.009 | Privileged roles assigned to guests | High | Any directory role assignment whose principal is a guest. |
| ARG.ENT.010 | Users can register applications | Medium | `defaultUserRolePermissions.allowedToCreateApps`. |
| ARG.ENT.011 | Users can create tenants | Low | `defaultUserRolePermissions.allowedToCreateTenants`. |
| ARG.ENT.012 | LinkedIn account connections disabled | Low / Investigate | No documented Microsoft Graph API exposes the setting (verified on Microsoft Learn 2026-10-19), so the check is always **Investigate** with manual verification steps (Entra admin center > Users > User settings; expected No or Selected group). Becomes Failed/Passed if an API is published. Added 2026-10-19. |
| ARG.ENT.013 | Security groups without owners | Low | Non-dynamic, non-role-assignable security groups, 0 owners. |
| ARG.ENT.014 | Stale devices (no sign-in > 180 d) | Low | `devices.approximateLastSignInDateTime`. |
| ARG.ENT.015 | Directory sync freshness (hybrid only) | Medium | `organization.onPremisesLastSyncDateTime` older than 24 h → Failed; cloud-only → Skipped. |

### Applications (`APP`)
| Id | Check | Sev | Logic |
|---|---|---|---|
| ARG.APP.001 | App registrations without owners | Medium | `/applications/{id}/owners` (batched). |
| ARG.APP.002 | Client secrets expiring within 30 d | Medium | `passwordCredentials.endDateTime`. |
| ARG.APP.003 | Expired client secrets still present | Low | endDateTime < now. |
| ARG.APP.004 | Secrets with lifetime > 24 months | Low | endDateTime − startDateTime. |
| ARG.APP.005 | Certificates expiring within 30 d | Medium | `keyCredentials` (usage Verify). |
| ARG.APP.006 | Expired certificates still present | Low | |
| ARG.APP.007 | Certificates with lifetime > 180 days | Low | Valid `keyCredentials` (usage Verify), endDateTime − startDateTime; Microsoft recommends ≤ 180 days. Added 2026-10-19. |

APP.002 / APP.005: expiring credentials that already have a newer credential of the same type valid beyond the window are listed with `Replaced = Yes` but do not fail the check (agreed 2026-10-19).

### Licensing (`LIC`)
| Id | Check | Sev | Logic |
|---|---|---|---|
| ARG.LIC.001 | Disabled users still licensed (excl. shared/room/equipment mailboxes) | High | `accountEnabled eq false` + licences; exclude objects whose mailbox RecipientTypeDetails is Shared/Room/Equipment (EXO). Without EXO → Investigate with note. Formerly ARG.ENT.012 (moved 2026-10-19). |
| ARG.LIC.002 | Enabled **licensed** users inactive > 90 d | High | Same inactivity logic as ARG.ENT.001 ∩ `assignedLicenses` not empty. Findings include SKU names (wasted licences). Requires P1. Formerly ARG.ENT.007 (moved 2026-10-19). |
| ARG.LIC.003 | Paid licences assigned to guest users | Medium | Guests whose `assignedLicenses` include a Paid SKU (`Get-ArgusSkuCategory`: free/viral/trial ignored). |
| ARG.LIC.004 | Users with overlapping licences | Medium | Paid SKUs assigned to the same user where all `servicePlans` ids of one are contained in the other (data-driven, no SKU list); AffectedCount = users. |
| ARG.LIC.005 | Licence assignment errors | Medium | users' `licenseAssignmentStates` with state `Error` or `ActiveWithError`; error code and assigning group (name from optional Groups data). |
| ARG.LIC.006 | Unused licences per SKU (> 10 % or > 5 seats) | Medium | `subscribedSkus` with capabilityStatus Enabled and appliesTo User: prepaidUnits.enabled − consumedUnits, paid SKUs only. Not paid: `IgnoredSkus` (free/viral/developer part numbers, default list in the module, verified against the Microsoft licensing reference), SKUs with ≥ `FreeSeatThreshold` (10,000) seats, and trial SKUs (all `/directory/subscriptions` entries `isTrial`). Findings: SKU friendly name, part number, purchased, assigned, unused, unused %. |
| ARG.LIC.007 | Shared mailboxes with a licence | Low / Investigate | Licensed shared mailboxes. Justified (not listed): size ≥ `SizeThresholdGB` (50), ArchiveStatus Active, LitigationHoldEnabled, non-empty InPlaceHolds. Others → Investigate (org-wide retention policies are not visible). Requires EXO. |
| ARG.LIC.008 | Paid licences assigned directly to users | Low | `licenseAssignmentStates` entries with no `assignedByGroup` for **paid** SKUs (same Free/Trial classification as ARG.LIC.006) → Failed. Free/trial-only direct assignments are counted in the summary only. AlsoFromGroup = same SKU also inherited from a group (redundant). Added 2026-10-19. |

### Microsoft 365 Groups & Teams (`GRP`)
| Id | Check | Sev | Logic |
|---|---|---|---|
| ARG.GRP.001 | Group creation restricted | Medium | `groupSettings` (Group.Unified) `EnableGroupCreation` / `GroupCreationAllowedGroupId`. Not configured or true → Investigate; false → Passed. |
| ARG.GRP.002 | Group naming policy configured | Low | `PrefixSuffixNamingRequirement` or `CustomBlockedWordsList` non-empty → Passed, else Failed. Requires Entra ID P1. |
| ARG.GRP.003 | Group expiration policy configured | Medium | `groupLifecyclePolicies`: none or managedGroupTypes None → Failed; Selected → Investigate; All → Passed. |
| ARG.GRP.004 | M365 groups / Teams without owners | High | 0 owners. |
| ARG.GRP.005 | M365 groups / Teams with a single owner | Low | exactly 1 owner; OwnerEnabled from optional Users (disabled owners first). |
| ARG.GRP.006 | Teams with guests and no owner | High | Ownerless Teams; members read with `$batch` `GET /groups/{id}/members/microsoft.graph.user` (first 999), userType Guest. |
| ARG.GRP.007 | Public Microsoft 365 groups | Medium | Unified groups with `visibility eq 'Public'`; Team column. Failed when any. |
| ARG.GRP.008 | Inactive Teams (> 180 d) | Low | `getTeamsTeamActivityDetail(period='D180')` Last Activity Date older or empty; optional Groups ignores deleted teams and teams created within the threshold. Concealed names or empty report → Investigate. |

### SharePoint & OneDrive (`SPO`)
| Id | Check | Sev | Logic |
|---|---|---|---|
| ARG.SPO.001 | SharePoint site creation is restricted | Medium / Investigate | `sharepointSettings.isSiteCreationEnabled` true → Investigate (as ARG.GRP.001), false → Passed. |
| ARG.SPO.002 | Tenant external sharing level | Medium / Investigate | `admin/sharepoint/settings.sharingCapability` = `externalUserAndGuestSharing` (Anyone links) → Investigate, otherwise Passed. Findings also show domain restriction mode and guest resharing. |
| ARG.SPO.003 | Default sharing link is Specific people | Medium | `CoreDefaultShareLinkScope` / `OneDriveDefaultShareLinkScope` (fallback `DefaultSharingLinkType` when Uninitialized): Anyone → Failed, Organization or widest allowed → Investigate, Specific people → Passed. Needs PnP. |
| ARG.SPO.004 | Anyone links expire within 30 d | Medium | Only when Anyone links are allowed: `RequireAnonymousLinksExpireInDays` ≤ 0 or > `MaxDays` → Failed. Needs PnP. |
| ARG.SPO.005 | Guest access expires | Medium | PnP `ExternalUserExpirationRequired` false → Failed. Passed without evaluation when sharingCapability = disabled. Needs PnP (Skipped otherwise). |
| ARG.SPO.006 | Sites that allow Anyone links | Low / Investigate | Sites (no OneDrive) with SharingCapability ExternalUserAndGuestSharing → Investigate; Passed when the tenant does not allow Anyone links. Needs PnP. |
| ARG.SPO.007 | Sites without a sensitivity label | Low / Investigate | PnP sites (OneDrive and system templates excluded) with empty `SensitivityLabel`: Failed when other sites are labelled, Investigate when no site is (labels probably not used). Needs PnP. |
| ARG.SPO.008 | Orphaned sites | High | Ownerless Unified groups → site via `$batch` `GET /groups/{id}/sites/root` (Sites.Read.All). With PnP (`SharePointSites` = `Get-PnPTenantSite`): sites without group whose `Owner` is empty, disabled or not found in Users. Without PnP the summary says those sites were not evaluated. |
| ARG.SPO.009 | Inactive sites (> 180 d) | Low | `getSharePointSiteUsageDetail(period='D180')` Last Activity Date older or empty; deleted sites ignored. System templates are excluded (`ExcludedTemplates`). Empty `Site URL` (advisory SP676147) → resolved from `Site Id`: first from the optional `SharePointSites` (PnP, includes private group and channel sites), then with `$batch` `GET /sites/{id}?$select=webUrl` (delegated: only sites the account can access; without PnP the summary counts the unresolved URLs); owner falls back to Owner Display Name, else "Not reported". Concealed names or empty report → Investigate. |
| ARG.SPO.010 | Sites near storage quota (> 90 %) | Low | site usage report Storage Used / Storage Allocated (Byte); sites without allocation ignored. Empty `Site URL` resolved from `Site Id` as in ARG.SPO.009. Concealed names or empty report → Investigate. |
| ARG.SPO.011 | OneDrive retention for deleted users ≥ 90 d | Low | `deletedUserPersonalSiteRetentionPeriodInDays` < `MinRetentionDays` (90; default 30) → Failed. |
| ARG.SPO.012 | OneDrive of deleted/disabled users with content | Low | OneDrive usage report (Storage Used > 0, not deleted) whose Owner Principal Name is disabled or not found in Users. Empty `Site URL` (no Site Id in this report) → `mySite` of the user (`$batch` `GET /users/{id}?$select=mySite`), or derived from the UPN with the OneDrive naming convention for users that no longer exist (`UrlSource`). Concealed names or empty report → Investigate. |
| ARG.SPO.013 | OneDrives near storage quota (> 90 %) | Low | OneDrive usage report Storage Used / Storage Allocated. Empty `Site URL` (no Site Id in this report) → `mySite` of the user (`$batch` `GET /users/{id}?$select=mySite`), or derived from the UPN with the OneDrive naming convention for users that no longer exist (`UrlSource`). Concealed names or empty report → Investigate. |

### Exchange Online (`EXO`)
| Id | Check | Sev | Logic |
|---|---|---|---|
| ARG.EXO.001 | Shared mailboxes with sign-in enabled | Medium | Shared mailbox + corresponding user `accountEnabled eq true`. |
| ARG.EXO.002 | Shared mailboxes without delegates | Low | No explicit FullAccess trustee (SharedMailboxPermissions). |
| ARG.EXO.003 | Inactive shared mailboxes (> 90 d) | Low | Mailbox usage report (no recipient type) joined with Mailboxes (SharedMailbox). Concealed names or empty report → Investigate. |
| ARG.EXO.004 | Inactive mailboxes (> 90 d, user mailboxes) | Low | Mailbox usage report Last Activity Date older or empty (Created Date before threshold). Optional Mailboxes restricts to UserMailbox; without EXO shared mailboxes are included with a note. Concealed names or empty report → Investigate. |
| ARG.EXO.005 | User mailboxes of disabled accounts | Low | UserMailbox whose Entra account is disabled; litigation hold / in-place holds counted as kept on purpose (summary note). |
| ARG.EXO.006 | Mailboxes near quota (> 90 % of the warning quota) | Low | Mailbox usage report Storage Used / Issue Warning Quota (Prohibit Send Quota when no warning quota); shows % of Prohibit Send and, with EXO (optional Mailboxes), the mailbox type (shared mailboxes receive no warnings). Concealed names or empty report → Investigate. |
| ARG.EXO.007 | Mailboxes with forwarding configured (inventory) | Low / Investigate | `ForwardingSmtpAddress` / `ForwardingAddress` (Get-EXOMailbox); External when the SMTP domain is not a verified domain (`organization.verifiedDomains`). Inbox rules not evaluated. Inventory for lifecycle governance; blocking external forwarding is a security control, out of scope. |
| ARG.EXO.008 | User mailboxes without a mailbox hold (informational) | Info / Investigate | UserMailbox without `LitigationHoldEnabled` and with empty `InPlaceHolds`. Purview retention policies are not visible, so always To review when such mailboxes exist; no score impact. |
| ARG.EXO.009 | Distribution groups without owner (ManagedBy) | Low | `Get-DistributionGroup` (distribution and mail-enabled security groups) with empty `ManagedBy`. |
| ARG.EXO.010 | Empty distribution groups | Low | Distribution / mail-enabled security groups with no members (DistributionGroupMembers); unreadable groups left out. |

### Copilot & Agents (`COP`, added 2026-10-19)
Governance of Copilot licensing, AI data processing and agents (not security posture). Several admin-center settings have **no API**: those checks are **manual reviews** — always Investigate, severity **Info** (weight 0, no score impact), tag `Manual`, findings list Setting / Location / Default / Recommended.

| Id | Check | Sev | Logic |
|---|---|---|---|
| ARG.COP.001 | Self-service purchase and trials of Copilot products disabled | Medium | CommercePolicies, products matching `ProductNamePattern` ('Copilot'): PolicyValue ≠ Disabled → Failed. No match → Investigate. Needs Commerce (Skipped otherwise). |
| ARG.COP.002 | Users cannot sign up for self-service trials | Medium | `authorizationPolicy.allowedToSignUpEmailBasedSubscriptions` true → Failed (viral trials such as Copilot Studio). |
| ARG.COP.003 | Copilot licences unused > 30 d | Medium | CopilotUsage Last Activity Date older or empty. Requires licence M365_COPILOT_APPS (Skipped otherwise). Concealed names or empty report → Investigate. |
| ARG.COP.004 | Anthropic as Microsoft subprocessor | Info / manual | States the default from `organization.countryLetterCode`: EU, EFTA (IS, LI, NO, CH), UK → Off; otherwise On. Anthropic is excluded from the EU Data Boundary. |
| ARG.COP.005 | Anthropic models with Data Retention (independent processor) | Info / manual | Off by default everywhere; under Anthropic's own terms and DPA. |
| ARG.COP.006 | Web search in Copilot is a deliberate choice | Low / Investigate | CopilotWebSearchPolicy (beta): not configured → Investigate (web queries outside DPA and EUDB); configured value → Investigate unless listed in `DisabledValues` (empty by default, values not documented); group-scoped → Investigate. |
| ARG.COP.007 | Enhanced personalization (memory) is a deliberate choice | Low / Investigate | CopilotPersonalization (beta): enabled with no excluded group → Investigate; off or group excluded → Passed. |
| ARG.COP.008 | Agent creation and access controlled | Info / manual | Agents > Settings > User access, Agent and plugin access; Copilot Studio makers per Power Platform environment. |
| ARG.COP.009 | Users can register agent identity blueprints | Medium | AuthorizationPolicyBeta (beta, not yet on Learn): `defaultUserRolePermissions.allowedToCreateAgentIdentityBlueprints` true → Failed, false → Passed, property not returned → Skipped (rollout from 2026-11-04, default on). Independent of ARG.ENT.010. |
| ARG.COP.010 | Org-wide agent sharing restricted | Info / manual | Agents > Settings > Sharing (Agent Builder agents). |
| ARG.COP.011 | External agents available to all users | Low / Investigate | CopilotPackages type = external, not blocked, availableTo allowedForAll (or 'all' as in Learn samples). Requires AGENT_365. |
| ARG.COP.012 | Agent requests pending > 7 d | Low | PendingRequests with lastModifiedDateTime older than `PendingDays` (the API has no request date). Requires AGENT_365. |

The catalogue is a starting point: every data source is verified on Microsoft Learn, and adjustments are proposed (not made silently) when an endpoint/property doesn't behave as described.

## 9. Required permissions (to verify per check)

Graph application/delegated, read-only: `User.Read.All`, `Group.Read.All`, `GroupMember.Read.All`, `Directory.Read.All`, `AuditLog.Read.All`, `Application.Read.All`, `RoleManagement.Read.Directory`, `RoleEligibilitySchedule.Read.Directory`, `Organization.Read.All`, `LicenseAssignment.Read.All`, `GroupSettings.Read.All`, `Policy.Read.All`, `Device.Read.All`, `Reports.Read.All`, `ReportSettings.Read.All`, `Sites.Read.All`, `SharePointTenantSettings.Read.All`, `CopilotPolicySettings.Read` (delegated only, beta), `PeopleSettings.Read.All`, `CopilotPackages.Read.All`. The exact list per check comes from `Get-ArgusRequiredPermission` (check scopes + data set permissions, §7).
Exchange: `Exchange.ManageAsApp` + Entra role **Global Reader** (app-only) or View-Only Organization Management (delegated).
Commerce (MSCommerce): interactive sign-in on Windows with **Global Reader** (read-only list of product policies); not available app-only.
Recommended delegated role for interactive runs: **Global Reader** (+ Reports Reader).

### Authentication model (decided 2026-10-19)

- **Primary mode: interactive, delegated.** The operator runs ARGUS signed in as a user holding **Application Administrator** (or Cloud Application Administrator) or **Global Administrator**. `Connect-Argus` requests only the read-only delegated Graph scopes returned by `Get-ArgusRequiredPermission`; on the first run in a tenant the operator grants **tenant-wide admin consent** for them at sign-in.
- Per Microsoft Learn (*Grant tenant-wide admin consent*), Application Administrator / Cloud Application Administrator can consent to any permission **except Microsoft Graph application permissions (app roles)**; delegated Graph scopes are allowed. App-only Graph consent (Certificate / ManagedIdentity sets) requires Privileged Role Administrator or Global Administrator.
- In delegated mode the effective access is the **intersection** of consented scopes and the signed-in user's own directory role. Some data sets may need a reader role the Application Administrator role doesn't include (sign-in activity, usage reports, SharePoint tenant settings). Phase 4 verifies on Learn the role needed per data set; `Test-ArgusPrerequisite` reports it, and checks whose data can't be read are Skipped with the reason, not Error.
- Open for Phase 4: consent to the default Microsoft Graph PowerShell client app vs. a dedicated ARGUS app registration (`-ClientId`).

## 10. HTML report

### Look & feel (revised 2026-10-19 after review: "more minimal, essentials only")
Minimal, document-like. Neutral greys, flat surfaces with hairline borders (no shadows, gradients or decorative icons). **Green for Passed, red for Failed, orange for Investigate (shown as "To review")**; every other status (Error, Skipped, NotRun) is grey and always written out (orange added 2026-10-19). Status marks use shape as well as colour (check / cross / dash). System font stack, monospace for IDs/code. Light/dark mode (follows `prefers-color-scheme`, manual toggle). Responsive down to tablet width. Print stylesheet (light palette, expanded details, no interactive controls) so it can be saved as PDF for a customer.

### Structure
1. **Header** — ARGUS wordmark (with a grey "Preview" label when the module version has a prerelease suffix, e.g. 1.0.0-preview1), tenant name, default domain, run date/time (with time zone), account used, optional company/logo from config. Tenant ID, duration and version move to the footer run details.
2. **Warnings** — amber informational banner when relevant (concealed report names); amber is used only here.
3. **Overview — "Iris" (redesigned 2026-10-19)** — one card. Head band, two columns: "Governance score" as a large percentage with a grade pill, "N of M weighted points earned" and a grade scale (F <40 · D 40+ · C 60+ · B 75+ · A 90+, filled up to the score, marker at the score). Score colour (2026-10-19): one continuous spectrum red → orange → yellow → green (stops at the grade thresholds, separate light/dark sets in `SPECTRUM`, report.js): every scale band shows its stretch of the spectrum, veiled above the score; the score number is a gradient over the 25 points of spectrum that lead to the score; the grade pill border, the iris arc and the pupil value take the colour at the score; beside it the "Assessment" verdict sentence from the grade, one-line summary (failed, high/critical, to review, coverage) and *Partial* note. Body, two columns. Left: an SVG iris; every check is an annular segment around the ring, grouped by area (area name + score % outside, click filters the list), coloured by status (green/red/orange/grey) and as long as its severity; hovering shows the check, clicking opens it. Inside: score arc and the score % with grade in the pupil, fine radial "fibres" as texture. Segments open with a short staggered animation (off for reduced motion and print). Right ("Results"): four clickable counters (Passed / Failed / To review / Other) with the "Other" breakdown, Failed-by-severity strip, and Priorities (top 5 failed checks by severity then affected objects, each opens its check).
4. **Area cards** — score, grade, passed/failed/other bar and counts; selecting a card filters the list. A wide card "Where the score is lost" fills the rest of the last row (spans the free columns: 3 − n mod 3, or 2 − n mod 2 on two-column layouts): a line chart of weighted points not earned per area (evaluated − earned weight), largest first, coloured by bands of weighted points lost (`LOSS_BANDS` in report.js: above 15 red `--loss-high`, above 10 orange `--loss-mid`, above 5 yellow `--loss-low`, 5 or less yellow-green `--loss-min`; per-theme tokens) — a vertical gradient with a short blend at each threshold on line and area, exact band colour on the dots, drawn when it scrolls into view (IntersectionObserver; immediate for reduced motion and print), hover tooltip (points lost, share, area score), click filters the area. The expand button opens a compact modal "zoom" (at most 540px or 62% of the viewport, centred; the table scrolls inside with a sticky header) with a larger chart (y grid 0 / half / max) and a table: Area, Score, Points earned, Points lost, Share of loss, Cumulative, Failed checks.
5. **Test list** — one collapsible card per Area with column headings (Status, Id, Check, Severity, Affected); inside each area Failed first (by severity), then the other statuses, then Passed. Status badge: green Passed, red Failed, orange To review, grey for the rest with the name written out. Column headings Status, Id, Check and Severity sort every area (click again to reverse; default Status). Toolbar (sticky): All / Failed / Passed / To review / Other filter and text search. Only one check is open at a time. Page title (also the default PDF file name): `ARGUS` (tenant and date are shown in the page header; changed 2026-10-19).
6. **Test detail** (expandable row, single-column panel with a status-coloured edge, deep-linkable via `#ARG.ENT.001`, Previous / Next buttons that follow the active filters):
   - Status, severity, summary sentence, affected/evaluated counts;
   - *Description* and *Why it matters*;
   - *What was found* — findings table (first `MaxFindingsInHtml` rows, note "showing 500 of 3,214 — full list in CSV/JSON"), with per-table search and **Export CSV** button (client-side);
   - *How to fix* — numbered steps, portal link, PowerShell snippet in a code block with **Copy** button, clearly labelled "sample — review before running";
   - *References* (Learn links);
   - Skip reason / error message when relevant; parameters used (e.g. `InactiveDays = 90`).
7. **Footer** — collapsible "Run details" (checks not evaluated and why, scopes used, connected services, filters, configuration, tenant ID, duration, version), one-line disclaimer, link to project repo.

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
