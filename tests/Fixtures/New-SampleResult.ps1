#Requires -Version 7.2
<#
.SYNOPSIS
    Regenerates tests/Fixtures/sample-results.json: a realistic, fully fictitious ARGUS run.

.DESCRIPTION
    Builds a results document for the fictitious tenant "Contoso" with checks in all six areas,
    every status, mixed severities, a check with 3,000 findings (HTML cap / performance), a check
    Skipped for a missing Entra ID P1 licence, an Error, and tenant strings containing HTML/script
    payloads (to verify the report renders them as text).

    Output is deterministic (fixed seed and timestamps). No real tenant data is used.
    Score and document are produced by the module's own Get-ArgusScore / ConvertTo-ArgusResultDocument.

.EXAMPLE
    ./tests/Fixtures/New-SampleResult.ps1
#>
[CmdletBinding()]
param(
    [Parameter()]
    [string] $OutputPath = (Join-Path $PSScriptRoot 'sample-results.json')
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '../../ARGUS/ARGUS.psd1') -Force

& (Get-Module ARGUS) {
    param($OutputPath)

    $rng = [System.Random]::new(20261019)
    $now = [datetime]::new(2026, 10, 19, 7, 0, 0, [System.DateTimeKind]::Utc)
    $domain = 'contoso.onmicrosoft.com'
    $first = 'Alex', 'Sam', 'Jordan', 'Taylor', 'Morgan', 'Casey', 'Riley', 'Jamie', 'Avery', 'Quinn', 'Robin', 'Drew', 'Elena', 'Marco', 'Giulia', 'Luca'
    $last = 'Rossi', 'Bianchi', 'Smith', 'Garcia', 'Novak', 'Dubois', 'Muller', 'Silva', 'Kowalski', 'Jensen', 'Moretti', 'Larsen', 'Ferri', 'Conti'

    $pick = { param($List) $List[$rng.Next($List.Count)] }
    $newId = { $bytes = [byte[]]::new(16); $rng.NextBytes($bytes); ([guid]::new($bytes)).ToString() }
    $iso = { param([datetime] $Date) $Date.ToString('yyyy-MM-ddTHH:mm:ssZ') }
    $daysAgo = { param([int] $Min, [int] $Max) $now.AddDays(-$rng.Next($Min, $Max)).AddMinutes(-$rng.Next(0, 1440)) }
    $person = {
        $f = & $pick $first; $l = & $pick $last
        [pscustomobject]@{ DisplayName = "$f $l"; UserPrincipalName = ('{0}.{1}{2}@{3}' -f $f, $l, $rng.Next(1, 99), $domain).ToLowerInvariant() }
    }

    $record = {
        param([hashtable] $m)
        # Strict mode: dot access to a missing hashtable key throws, so pre-fill the optional keys.
        foreach ($key in 'Summary', 'Affected', 'Evaluated', 'Excluded', 'Findings', 'Columns', 'SkipReason', 'ErrorMessage', 'Parameters',
            'PowerShell', 'PortalUrl', 'References', 'Services', 'Scopes', 'Licenses', 'DataSets', 'Tags', 'UsesBeta') {
            if (-not $m.ContainsKey($key)) { $m[$key] = $null }
        }
        $findings = @($m.Findings | Where-Object { $null -ne $_ })
        $columns = if ($m.Columns) { [string[]]$m.Columns } elseif ($findings.Count) { [string[]]$findings[0].PSObject.Properties.Name } else { [string[]]@() }
        $notEvaluated = $m.Status -in 'Skipped', 'Error', 'NotRun'
        [pscustomobject][ordered]@{
            Id              = $m.Id
            Title           = $m.Title
            Area            = $m.Area
            AreaDisplayName = $script:ArgusAreas[$m.Area].DisplayName
            Category        = $m.Category
            Severity        = $m.Severity
            Status          = $m.Status
            Summary         = if ($m.Summary) { $m.Summary } else { '' }
            AffectedCount   = if ($null -ne $m.Affected) { $m.Affected } elseif ($notEvaluated) { 0 } else { $findings.Count }
            EvaluatedCount  = $m.Evaluated
            ExcludedCount   = if ($m.Excluded) { $m.Excluded } else { 0 }
            Findings        = $findings
            FindingColumns  = $columns
            SkipReason      = $m.SkipReason
            ErrorMessage    = $m.ErrorMessage
            Duration        = if ($m.Status -in 'NotRun', 'Skipped') { 0.0 } else { [math]::Round(0.2 + $rng.NextDouble() * 3, 3) }
            Parameters      = if ($m.Parameters) { $m.Parameters } else { @{} }
            Description     = $m.Description
            Rationale       = $m.Rationale
            Remediation     = [pscustomobject]@{
                Steps      = $m.Steps
                PowerShell = if ($m.PowerShell) { $m.PowerShell } else { '' }
                PortalUrl  = if ($m.PortalUrl) { $m.PortalUrl } else { '' }
            }
            References      = @($m.References | ForEach-Object { [pscustomobject]@{ Title = $_[0]; Url = $_[1] } })
            Requires        = [pscustomobject]@{
                Services    = [string[]]@(if ($m.Services) { $m.Services } else { 'Graph' })
                GraphScopes = [string[]]@($m.Scopes)
                Licenses    = [string[]]@($m.Licenses | Where-Object { $_ })
                DataSets    = [string[]]@($m.DataSets)
            }
            Tags            = [string[]]@($m.Tags)
            UsesBeta        = [bool]$m.UsesBeta
            IsCustom        = $false
        }
    }

    $entraPortal = 'https://entra.microsoft.com/'
    $m365Portal = 'https://admin.microsoft.com/'
    $spoPortal = 'https://admin.microsoft.com/sharepoint'
    $exoPortal = 'https://admin.exchange.microsoft.com/'
    $refInactive = @('Manage inactive user accounts', 'https://learn.microsoft.com/en-us/entra/identity/monitoring-health/howto-manage-inactive-user-accounts')
    $refB2B = @('B2B collaboration overview', 'https://learn.microsoft.com/en-us/entra/external-id/what-is-b2b')
    $refRoles = @('Best practices for Microsoft Entra roles', 'https://learn.microsoft.com/en-us/entra/identity/role-based-access-control/best-practices')
    $refDevices = @('Manage stale devices', 'https://learn.microsoft.com/en-us/entra/identity/devices/manage-stale-devices')
    $refCollab = @('Configure external collaboration settings', 'https://learn.microsoft.com/en-us/entra/external-id/external-collaboration-settings-configure')
    $refCreds = @('Add credentials to an app registration', 'https://learn.microsoft.com/en-us/entra/identity-platform/how-to-add-credentials')
    $refLicErr = @('Resolve group licensing problems', 'https://learn.microsoft.com/en-us/entra/identity/users/licensing-groups-resolve-problems')
    $refExpiry = @('Microsoft 365 group expiration policy', 'https://learn.microsoft.com/en-us/microsoft-365/solutions/microsoft-365-groups-expiration-policy')
    $refCreation = @('Manage who can create Microsoft 365 groups', 'https://learn.microsoft.com/en-us/microsoft-365/solutions/manage-creation-of-groups')
    $refNaming = @('Microsoft 365 groups naming policy', 'https://learn.microsoft.com/en-us/microsoft-365/solutions/groups-naming-policy')
    $refSharing = @('Manage sharing settings for SharePoint and OneDrive', 'https://learn.microsoft.com/en-us/sharepoint/turn-external-sharing-on-or-off')
    $refReports = @('Microsoft 365 usage reports', 'https://learn.microsoft.com/en-us/microsoft-365/admin/activity-reports/activity-reports')
    $refShared = @('About shared mailboxes', 'https://learn.microsoft.com/en-us/microsoft-365/admin/email/about-shared-mailboxes')
    $p1Skip = 'Entra ID P1 licence (AAD_PREMIUM) not detected.'
    $concealed = 'Usage reports return concealed names (admin/reportSettings.displayConcealedNames = true), so inactive objects cannot be identified. Turn the setting off to evaluate this check.'

    $records = [System.Collections.Generic.List[object]]::new()

    # ------------------------------------------------------------------ Entra ID
    $records.Add((& $record @{
                Id = 'ARG.ENT.001'; Title = 'Enabled members inactive for more than 90 days'; Area = 'EntraID'; Category = 'Identity lifecycle'; Severity = 'Medium'
                Status = 'Skipped'; SkipReason = $p1Skip; Parameters = @{ InactiveDays = 90 }
                Description = 'Lists enabled member accounts whose last successful sign-in is older than **{InactiveDays}** days, including accounts that never signed in and were created before the threshold.'
                Rationale = 'Unused accounts accumulate access, licences and group memberships that nobody reviews.'
                Steps = "1. Review the listed accounts with their managers.`n2. Disable accounts that are no longer needed.`n3. Remove licences and group memberships after the retention period."
                PortalUrl = $entraPortal; References = @(, $refInactive)
                Scopes = 'User.Read.All', 'AuditLog.Read.All'; Licenses = 'AAD_PREMIUM'; DataSets = 'Users'; Tags = 'Lifecycle', 'Users'
            }))
    $records.Add((& $record @{
                Id = 'ARG.ENT.002'; Title = 'Enabled licensed users inactive for more than 90 days'; Area = 'EntraID'; Category = 'Identity lifecycle'; Severity = 'High'
                Status = 'Skipped'; SkipReason = $p1Skip; Parameters = @{ InactiveDays = 90 }
                Description = 'Same as ARG.ENT.001, restricted to users with at least one licence assigned.'
                Rationale = 'Licences assigned to inactive users are a direct cost with no business value.'
                Steps = "1. Confirm the users are no longer active.`n2. Remove the licences or reassign them."
                PortalUrl = $m365Portal; References = @(, $refInactive)
                Scopes = 'User.Read.All', 'AuditLog.Read.All'; Licenses = 'AAD_PREMIUM'; DataSets = 'Users', 'SubscribedSkus'; Tags = 'Lifecycle', 'Licensing'
            }))
    $records.Add((& $record @{
                Id = 'ARG.ENT.003'; Title = 'Guests inactive for more than 90 days'; Area = 'EntraID'; Category = 'External identities'; Severity = 'Medium'
                Status = 'Skipped'; SkipReason = $p1Skip; Parameters = @{ InactiveDays = 90 }
                Description = 'Guests that accepted their invitation but have not signed in for **{InactiveDays}** days.'
                Rationale = 'Stale guest accounts keep access to Teams, sites and files long after the collaboration ended.'
                Steps = "1. Run an access review for guests.`n2. Remove guests that are no longer needed."
                PortalUrl = $entraPortal; References = @(, $refB2B)
                Scopes = 'User.Read.All', 'AuditLog.Read.All'; Licenses = 'AAD_PREMIUM'; DataSets = 'Users'; Tags = 'Guests', 'Lifecycle'
            }))

    $pending = foreach ($i in 1..14) {
        $p = & $person
        $created = & $daysAgo 35 400
        [pscustomobject]@{ DisplayName = $p.DisplayName; Mail = ($p.UserPrincipalName -replace '@.*$', '@fabrikam.example'); ObjectId = (& $newId); InvitedOn = (& $iso $created); DaysPending = [int]($now - $created).TotalDays }
    }
    $records.Add((& $record @{
                Id = 'ARG.ENT.004'; Title = 'Guests that never accepted the invitation (more than 30 days)'; Area = 'EntraID'; Category = 'External identities'; Severity = 'Medium'
                Status = 'Failed'; Summary = '14 of 212 guests have not accepted their invitation for 30+ days.'; Evaluated = 212; Findings = $pending; Parameters = @{ PendingDays = 30 }
                Description = 'Guests with `externalUserState` = PendingAcceptance whose invitation is older than **{PendingDays}** days.'
                Rationale = 'Unredeemed invitations clutter the directory and can be redeemed later by whoever controls the mailbox.'
                Steps = "1. Confirm whether the collaboration is still needed.`n2. Delete the pending guest or resend the invitation."
                PowerShell = "# Sample only - review before running`nConnect-MgGraph -Scopes 'User.ReadWrite.All'`nRemove-MgUser -UserId '<ObjectId>'"
                PortalUrl = $entraPortal; References = @(, $refB2B)
                Scopes = @('User.Read.All'); DataSets = 'Users'; Tags = 'Guests'
            }))

    $skus = 'Microsoft 365 E3', 'Microsoft 365 Business Premium', 'Office 365 E1', 'Exchange Online (Plan 1)'
    $disabled = foreach ($i in 1..6) {
        $p = & $person
        [pscustomobject]@{ DisplayName = $p.DisplayName; UserPrincipalName = $p.UserPrincipalName; ObjectId = (& $newId); Licences = @((& $pick $skus)); DisabledSince = (& $iso (& $daysAgo 10 300)) }
    }
    $disabled[2].DisplayName = 'Former employee <b>bold</b> & "quotes"'
    $records.Add((& $record @{
                Id = 'ARG.ENT.005'; Title = 'Disabled users that still have licences'; Area = 'EntraID'; Category = 'Licence hygiene'; Severity = 'High'
                Status = 'Failed'; Summary = '6 of 87 disabled users still have licences assigned (shared, room and equipment mailboxes excluded).'; Evaluated = 87; Findings = $disabled
                Description = 'Disabled accounts with licences, excluding shared, room and equipment mailboxes (detected through Exchange Online).'
                Rationale = 'Licences on disabled accounts are paid for but unusable.'
                Steps = "1. Check whether the mailbox must be retained (convert to shared or apply a hold).`n2. Remove the licences."
                PortalUrl = $m365Portal; References = @(, $refInactive)
                Services = 'Graph', 'Exchange'; Scopes = @('User.Read.All'); DataSets = 'Users', 'SubscribedSkus', 'Mailboxes'; Tags = 'Licensing', 'Lifecycle'
            }))

    $admins = foreach ($i in 1..6) {
        $p = & $person
        [pscustomobject]@{ DisplayName = $p.DisplayName; UserPrincipalName = $p.UserPrincipalName; ObjectId = (& $newId); AssignmentType = 'Active'; Via = if ($i -eq 6) { 'Group: Tier0-Admins' } else { 'Direct' } }
    }
    $admins[0].DisplayName = 'Break Glass 01'; $admins[0].UserPrincipalName = "breakglass01@$domain"
    $records.Add((& $record @{
                Id = 'ARG.ENT.006'; Title = 'Global Administrator count outside 2 to 4'; Area = 'EntraID'; Category = 'Privileged access'; Severity = 'High'
                Status = 'Failed'; Summary = '6 Global Administrators found (active assignments); the recommended range is 2 to 4. Eligible PIM assignments not evaluated: Entra ID P2 not detected.'
                Affected = 6; Evaluated = 6; Findings = $admins; Parameters = @{ MinCount = 2; MaxCount = 4 }
                Description = 'Counts active (and, with Entra ID P2, eligible) assignments of the Global Administrator role, expanding role-assignable groups.'
                Rationale = 'Too few Global Administrators is a recovery risk; too many widens the blast radius of a compromised account.'
                Steps = "1. Keep two emergency-access accounts.`n2. Move day-to-day administration to least-privileged roles.`n3. Remove unnecessary Global Administrator assignments."
                PortalUrl = $entraPortal; References = @(, $refRoles)
                Scopes = 'RoleManagement.Read.Directory', 'Directory.Read.All'; DataSets = @('DirectoryRoles'); Tags = 'Roles'
            }))
    $records.Add((& $record @{
                Id = 'ARG.ENT.007'; Title = 'Privileged roles assigned to guests'; Area = 'EntraID'; Category = 'Privileged access'; Severity = 'High'
                Status = 'Passed'; Summary = 'No directory role is assigned to a guest (143 assignments evaluated).'; Evaluated = 143
                Description = 'Any directory role assignment whose principal is a guest user.'
                Rationale = 'Administrative access should be held by accounts the organisation controls.'
                Steps = '1. Remove the role assignment from the guest and assign it to an internal account.'
                PortalUrl = $entraPortal; References = @(, $refRoles)
                Scopes = 'RoleManagement.Read.Directory', 'User.Read.All'; DataSets = 'DirectoryRoles', 'Users'; Tags = 'Roles', 'Guests'
            }))

    $ownerless = foreach ($i in 1..22) {
        [pscustomobject]@{ DisplayName = ('SG-{0}-{1}' -f (& $pick @('Finance', 'HR', 'IT', 'Sales', 'Legal', 'Ops')), (& $pick @('Readers', 'Editors', 'Project', 'Share', 'VPN'))); GroupId = (& $newId); Members = $rng.Next(0, 240); Created = (& $iso (& $daysAgo 100 2500)) }
    }
    $records.Add((& $record @{
                Id = 'ARG.ENT.008'; Title = 'Security groups without owners'; Area = 'EntraID'; Category = 'Group governance'; Severity = 'Low'
                Status = 'Failed'; Summary = '22 of 318 security groups have no owner.'; Evaluated = 318; Findings = $ownerless
                Description = 'Assigned (non-dynamic), non-role-assignable security groups with zero owners.'
                Rationale = 'Without an owner, nobody is accountable for membership reviews.'
                Steps = '1. Identify the business owner of each group and add them as owner.'
                PortalUrl = $entraPortal; References = @(, $refCreation)
                Scopes = @('Group.Read.All'); DataSets = @('Groups'); Tags = 'Groups'
            }))

    $os = 'Windows', 'Windows', 'Windows', 'iOS', 'Android', 'MacMDM'
    $trust = 'AzureAd', 'ServerAd', 'Workplace'
    $devices = foreach ($i in 1..3000) {
        $seen = & $daysAgo 181 1400
        [pscustomobject]@{ DeviceName = ('CTS-{0}{1:D5}' -f (& $pick @('LT', 'DT', 'MB')), $i); DeviceId = (& $newId); OperatingSystem = (& $pick $os); TrustType = (& $pick $trust); ApproximateLastSignIn = (& $iso $seen); DaysSinceSignIn = [int]($now - $seen).TotalDays }
    }
    $records.Add((& $record @{
                Id = 'ARG.ENT.009'; Title = 'Stale devices (no sign-in for more than 180 days)'; Area = 'EntraID'; Category = 'Device hygiene'; Severity = 'Low'
                Status = 'Failed'; Summary = '3,000 of 8,412 devices have not signed in for 180+ days.'; Evaluated = 8412; Findings = $devices; Parameters = @{ StaleDays = 180 }
                Description = 'Devices whose `approximateLastSignInDateTime` is older than **{StaleDays}** days.'
                Rationale = 'Stale devices make device-based reporting unreliable and clutter the directory.'
                Steps = "1. Disable stale devices.`n2. After a grace period, delete them.`n3. Make sure BitLocker recovery keys you still need are preserved."
                PowerShell = "# Sample only - review before running`nConnect-MgGraph -Scopes 'Device.ReadWrite.All'`nUpdate-MgDevice -DeviceId '<Id>' -AccountEnabled:`$false"
                PortalUrl = $entraPortal; References = @(, $refDevices)
                Scopes = @('Device.Read.All'); DataSets = @('Devices'); Tags = 'Devices', 'Lifecycle'
            }))
    $records.Add((& $record @{
                Id = 'ARG.ENT.010'; Title = 'Guest invitations are restricted'; Area = 'EntraID'; Category = 'External identities'; Severity = 'Medium'
                Status = 'Investigate'; Summary = 'Guest invitations are allowed for admins, guest inviters and all members (allowInvitesFrom = adminsGuestInvitersAndAllMembers).'
                Description = 'Reads `authorizationPolicy.allowInvitesFrom`.'
                Rationale = 'Letting every member invite guests is acceptable in some organisations but should be a deliberate decision.'
                Steps = '1. In **External collaboration settings**, restrict guest invitations to admins and users in the Guest Inviter role if appropriate.'
                PortalUrl = $entraPortal; References = @(, $refCollab)
                Scopes = @('Policy.Read.All'); DataSets = @('AuthorizationPolicy'); Tags = 'Guests', 'Policy'
            }))
    $records.Add((& $record @{
                Id = 'ARG.ENT.011'; Title = 'Users can register applications'; Area = 'EntraID'; Category = 'Application governance'; Severity = 'Medium'
                Status = 'Failed'; Summary = 'All users can register applications (defaultUserRolePermissions.allowedToCreateApps = true).'
                Description = 'Reads `authorizationPolicy.defaultUserRolePermissions.allowedToCreateApps`.'
                Rationale = 'Uncontrolled app registrations make application ownership and credential hygiene hard to govern.'
                Steps = "1. In **User settings**, set *Users can register applications* to **No**.`n2. Assign the Application Developer role to users who need it."
                PortalUrl = $entraPortal; References = @(, $refCreds)
                Scopes = @('Policy.Read.All'); DataSets = @('AuthorizationPolicy'); Tags = 'Applications', 'Policy'
            }))
    $records.Add((& $record @{
                Id = 'ARG.ENT.012'; Title = 'Users can create tenants'; Area = 'EntraID'; Category = 'Tenant governance'; Severity = 'Low'
                Status = 'Passed'; Summary = 'Non-admin users cannot create tenants.'
                Description = 'Reads `authorizationPolicy.defaultUserRolePermissions.allowedToCreateTenants`.'
                Rationale = 'Tenants created by users fall outside central governance.'
                Steps = '1. In **User settings**, set *Restrict non-admin users from creating tenants* to **Yes**.'
                PortalUrl = $entraPortal; References = @(, $refCollab)
                Scopes = @('Policy.Read.All'); DataSets = @('AuthorizationPolicy'); Tags = 'Policy'
            }))
    $records.Add((& $record @{
                Id = 'ARG.ENT.013'; Title = 'Directory synchronisation freshness'; Area = 'EntraID'; Category = 'Hybrid identity'; Severity = 'Medium'
                Status = 'Skipped'; SkipReason = 'Cloud-only tenant: directory synchronisation is not enabled.'; Parameters = @{ MaxSyncAgeHours = 24 }
                Description = 'Fails when `organization.onPremisesLastSyncDateTime` is older than **{MaxSyncAgeHours}** hours.'
                Rationale = 'A stalled sync leaves leavers enabled in the cloud.'
                Steps = '1. Check the health of Microsoft Entra Connect / Cloud Sync.'
                PortalUrl = $entraPortal; References = @(, $refInactive)
                Scopes = @('Organization.Read.All'); DataSets = @('Organization'); Tags = 'Hybrid'
            }))

    # ------------------------------------------------------------------ Applications
    $appNames = 'Payroll Connector', 'CRM Sync', 'Intranet SSO', 'Backup Agent', 'Reporting Bot', 'HR Portal', 'Legacy ERP Bridge', 'Marketing Forms', 'Ticketing Webhook'
    $appRow = {
        param([int] $DaysFromNow, [string] $Kind)
        $end = $now.AddDays($DaysFromNow)
        [pscustomobject]@{ DisplayName = (& $pick $appNames); AppId = (& $newId); CredentialType = $Kind; KeyId = (& $newId); EndDateTime = (& $iso $end); DaysLeft = $DaysFromNow }
    }
    $records.Add((& $record @{
                Id = 'ARG.APP.001'; Title = 'Client secrets expiring within 30 days'; Area = 'Applications'; Category = 'Credential hygiene'; Severity = 'Medium'
                Status = 'Failed'; Summary = '4 client secrets on 4 of 162 app registrations expire within 30 days.'; Affected = 4; Evaluated = 162
                Findings = @((& $appRow 3 'Secret'), (& $appRow 9 'Secret'), (& $appRow 17 'Secret'), (& $appRow 28 'Secret')); Parameters = @{ DaysAhead = 30 }
                Description = 'Password credentials whose `endDateTime` falls within the next **{DaysAhead}** days.'
                Rationale = 'Expired secrets break integrations; planned rotation avoids outages.'
                Steps = "1. Create a new secret.`n2. Update the consuming service.`n3. Delete the old secret."
                PortalUrl = $entraPortal; References = @(, $refCreds)
                Scopes = @('Application.Read.All'); DataSets = @('Applications'); Tags = 'Applications', 'Credentials'
            }))
    $records.Add((& $record @{
                Id = 'ARG.APP.002'; Title = 'Expired client secrets still present'; Area = 'Applications'; Category = 'Credential hygiene'; Severity = 'Low'
                Status = 'Failed'; Summary = '9 expired client secrets are still present on 7 app registrations.'; Affected = 9; Evaluated = 162
                Findings = @(1..9 | ForEach-Object { & $appRow (-$rng.Next(5, 700)) 'Secret' })
                Description = 'Password credentials whose `endDateTime` is in the past.'
                Rationale = 'Expired credentials are clutter and hide which credentials are really in use.'
                Steps = '1. Delete expired secrets from the app registration.'
                PortalUrl = $entraPortal; References = @(, $refCreds)
                Scopes = @('Application.Read.All'); DataSets = @('Applications'); Tags = 'Applications', 'Credentials'
            }))
    $records.Add((& $record @{
                Id = 'ARG.APP.003'; Title = 'Certificates expiring within 30 days'; Area = 'Applications'; Category = 'Credential hygiene'; Severity = 'Medium'
                Status = 'Passed'; Summary = 'No certificate expires within 30 days (41 certificates evaluated).'; Evaluated = 41; Parameters = @{ DaysAhead = 30 }
                Description = 'Key credentials (usage Verify) whose `endDateTime` falls within **{DaysAhead}** days.'
                Rationale = 'Expired certificates break app-only integrations.'
                Steps = '1. Upload a new certificate, update the service, then remove the old one.'
                PortalUrl = $entraPortal; References = @(, $refCreds)
                Scopes = @('Application.Read.All'); DataSets = @('Applications'); Tags = 'Applications', 'Credentials'
            }))
    $records.Add((& $record @{
                Id = 'ARG.APP.004'; Title = 'Expired certificates still present'; Area = 'Applications'; Category = 'Credential hygiene'; Severity = 'Low'
                Status = 'Error'; ErrorMessage = 'Response status code does not indicate success: 429 (Too Many Requests). Retry limit (5) reached for GET /v1.0/applications.'
                Description = 'Key credentials whose `endDateTime` is in the past.'
                Rationale = 'Expired certificates are clutter.'
                Steps = '1. Remove expired certificates from the app registration.'
                PortalUrl = $entraPortal; References = @(, $refCreds)
                Scopes = @('Application.Read.All'); DataSets = @('Applications'); Tags = 'Applications', 'Credentials'
            }))
    $records.Add((& $record @{
                Id = 'ARG.APP.005'; Title = 'App registrations without owners'; Area = 'Applications'; Category = 'Application governance'; Severity = 'Medium'
                Status = 'Failed'; Summary = '17 of 162 app registrations have no owner.'; Evaluated = 162
                Findings = @(1..17 | ForEach-Object { [pscustomobject]@{ DisplayName = (& $pick $appNames) + " $_"; AppId = (& $newId); Created = (& $iso (& $daysAgo 30 1800)); SignInAudience = (& $pick @('AzureADMyOrg', 'AzureADMultipleOrgs')) } })
                Description = 'App registrations with zero owners (owners fetched with JSON batching).'
                Rationale = 'Ownerless apps have nobody responsible for credentials, permissions and lifecycle.'
                Steps = '1. Assign at least one owner (ideally two) to each app registration.'
                PortalUrl = $entraPortal; References = @(, $refCreds)
                Scopes = @('Application.Read.All'); DataSets = @('Applications'); Tags = 'Applications', 'Ownership'
            }))
    $records.Add((& $record @{
                Id = 'ARG.APP.006'; Title = 'Client secrets with a lifetime above 24 months'; Area = 'Applications'; Category = 'Credential hygiene'; Severity = 'Low'
                Status = 'Failed'; Summary = '5 client secrets have a lifetime longer than 24 months.'; Affected = 5; Evaluated = 162; Parameters = @{ MaxLifetimeMonths = 24 }
                Findings = @(1..5 | ForEach-Object { $r = & $appRow ($rng.Next(200, 3000)) 'Secret'; $r | Add-Member -NotePropertyName LifetimeMonths -NotePropertyValue ($rng.Next(25, 120)) -PassThru })
                Description = 'Password credentials whose lifetime (`endDateTime` minus `startDateTime`) exceeds **{MaxLifetimeMonths}** months.'
                Rationale = 'Long-lived secrets are rarely rotated and outlive the people who created them.'
                Steps = '1. Replace the secret with one of shorter lifetime, or move to a certificate or managed identity.'
                PortalUrl = $entraPortal; References = @(, $refCreds)
                Scopes = @('Application.Read.All'); DataSets = @('Applications'); Tags = 'Applications', 'Credentials'
            }))

    # ------------------------------------------------------------------ Licensing
    $records.Add((& $record @{
                Id = 'ARG.LIC.001'; Title = 'Unused licences per SKU'; Area = 'Licensing'; Category = 'Cost'; Severity = 'Medium'
                Status = 'Failed'; Summary = '3 of 9 paid SKUs have more than 10% or more than 5 seats unused.'; Evaluated = 9; Parameters = @{ UnusedPercent = 10; UnusedSeats = 5 }
                Findings = @(
                    [pscustomobject]@{ Sku = 'Microsoft 365 E3'; SkuPartNumber = 'SPE_E3'; Purchased = 450; Assigned = 391; Unused = 59; UnusedPercent = 13.1 }
                    [pscustomobject]@{ Sku = 'Microsoft 365 Business Premium'; SkuPartNumber = 'SPB'; Purchased = 120; Assigned = 112; Unused = 8; UnusedPercent = 6.7 }
                    [pscustomobject]@{ Sku = 'Visio Plan 2'; SkuPartNumber = 'VISIOCLIENT'; Purchased = 25; Assigned = 11; Unused = 14; UnusedPercent = 56 }
                )
                Description = 'Compares `prepaidUnits.enabled` with `consumedUnits` for each paid SKU; free and viral SKUs listed in the configuration are ignored.'
                Rationale = 'Unused seats are recurring cost.'
                Steps = '1. Reduce the subscription quantity at the next renewal, or reassign the seats.'
                PortalUrl = $m365Portal; References = @(, $refLicErr)
                Scopes = @('Organization.Read.All'); DataSets = @('SubscribedSkus'); Tags = 'Licensing', 'Cost'
            }))
    $records.Add((& $record @{
                Id = 'ARG.LIC.002'; Title = 'Licence assignment errors'; Area = 'Licensing'; Category = 'Licence hygiene'; Severity = 'Medium'
                Status = 'Passed'; Summary = 'No licence assignment errors (1,391 users evaluated).'; Evaluated = 1391
                Description = 'Users whose `licenseAssignmentStates` contain an entry in state Error.'
                Rationale = 'Assignment errors leave users without the services they are expected to have.'
                Steps = '1. Resolve the conflict (for example missing usage location or conflicting service plans) and reprocess.'
                PortalUrl = $entraPortal; References = @(, $refLicErr)
                Scopes = @('User.Read.All'); DataSets = @('Users'); Tags = 'Licensing'
            }))
    $records.Add((& $record @{
                Id = 'ARG.LIC.003'; Title = 'Shared mailboxes with a licence'; Area = 'Licensing'; Category = 'Cost'; Severity = 'Low'
                Status = 'Investigate'; Summary = '2 shared mailboxes have a licence; this is required only above 50 GB, with an archive or with a hold.'
                Findings = @(
                    [pscustomobject]@{ DisplayName = 'Accounts Payable'; UserPrincipalName = "ap@$domain"; Licences = @('Exchange Online (Plan 2)'); MailboxSizeGB = 63.4; ArchiveEnabled = $true }
                    [pscustomobject]@{ DisplayName = 'Info'; UserPrincipalName = "info@$domain"; Licences = @('Office 365 E1'); MailboxSizeGB = 4.1; ArchiveEnabled = $false }
                )
                Description = 'Shared mailboxes (Exchange Online) whose user object has licences assigned.'
                Rationale = 'Shared mailboxes do not need a licence unless they exceed 50 GB, have an archive or are on hold.'
                Steps = "1. Check size, archive and holds.`n2. Remove the licence where it is not required."
                PortalUrl = $m365Portal; References = @(, $refShared)
                Services = 'Graph', 'Exchange'; Scopes = @('User.Read.All'); DataSets = 'Users', 'Mailboxes'; Tags = 'Licensing', 'Exchange'
            }))

    # ------------------------------------------------------------------ Groups & Teams
    $groupRow = {
        param([string] $Name, [bool] $Team)
        [pscustomobject]@{ DisplayName = $Name; GroupId = (& $newId); Visibility = 'Public'; TeamEnabled = $Team; Members = $rng.Next(2, 400); Created = (& $iso (& $daysAgo 30 1500)) }
    }
    $publicGroups = @(
        (& $groupRow 'All Company' $true)
        (& $groupRow 'Project Phoenix' $true)
        (& $groupRow '<script>alert(1)</script>' $true)
        (& $groupRow '<img src=x onerror=alert(2)>' $false)
        (& $groupRow 'Sales EMEA' $true)
        (& $groupRow 'Marketing Campaigns' $false)
        (& $groupRow 'Board Prep' $true)
        (& $groupRow 'Social Club' $true)
        (& $groupRow 'IT Announcements' $false)
        (& $groupRow 'Customer X Delivery' $true)
        (& $groupRow 'R&D "Labs" & Co.' $true)
    )
    $records.Add((& $record @{
                Id = 'ARG.GRP.001'; Title = 'Public Microsoft 365 groups'; Area = 'GroupsTeams'; Category = 'Group governance'; Severity = 'Medium'
                Status = 'Failed'; Summary = '11 of 486 Microsoft 365 groups are public (8 are Teams).'; Evaluated = 486; Findings = $publicGroups
                Description = 'Microsoft 365 (Unified) groups with `visibility` = Public; the TeamEnabled column shows whether a team is connected.'
                Rationale = 'Anyone in the organisation can join a public group and read its content.'
                Steps = "1. Review each public group with its owners.`n2. Switch groups that hold restricted content to Private."
                PowerShell = "# Sample only - review before running`nConnect-MgGraph -Scopes 'Group.ReadWrite.All'`nUpdate-MgGroup -GroupId '<GroupId>' -Visibility 'Private'"
                PortalUrl = $m365Portal; References = @(, $refCreation)
                Scopes = @('Group.Read.All'); DataSets = @('Groups'); Tags = 'Groups', 'Teams'
            }))
    $records.Add((& $record @{
                Id = 'ARG.GRP.002'; Title = 'Microsoft 365 groups and Teams without owners'; Area = 'GroupsTeams'; Category = 'Ownership'; Severity = 'High'
                Status = 'Failed'; Summary = '4 of 486 Microsoft 365 groups have no owner (3 are Teams).'; Evaluated = 486
                Findings = @((& $groupRow 'Project Atlas' $true), (& $groupRow 'Temp Workshop 2024' $true), (& $groupRow 'Vendor Onboarding' $true), (& $groupRow 'Old Newsletter' $false))
                Description = 'Microsoft 365 groups with zero owners.'
                Rationale = 'Ownerless groups cannot renew under an expiration policy and nobody manages membership or guests.'
                Steps = '1. Assign at least two owners per group.'
                PortalUrl = $m365Portal; References = @(, $refExpiry)
                Scopes = @('Group.Read.All'); DataSets = @('Groups'); Tags = 'Groups', 'Teams', 'Ownership'
            }))
    $records.Add((& $record @{
                Id = 'ARG.GRP.003'; Title = 'Microsoft 365 groups and Teams with a single owner'; Area = 'GroupsTeams'; Category = 'Ownership'; Severity = 'Low'
                Status = 'Failed'; Summary = '38 of 486 Microsoft 365 groups have exactly one owner.'; Evaluated = 486
                Findings = @(1..38 | ForEach-Object { $p = & $person; [pscustomobject]@{ DisplayName = "Team $_ - " + (& $pick @('Planning', 'Ops', 'Design', 'Support')); GroupId = (& $newId); Owner = $p.UserPrincipalName; TeamEnabled = ($rng.Next(2) -eq 1) } })
                Description = 'Microsoft 365 groups with exactly one owner.'
                Rationale = 'A single owner is a single point of failure when that person leaves.'
                Steps = '1. Add a second owner to each group.'
                PortalUrl = $m365Portal; References = @(, $refExpiry)
                Scopes = @('Group.Read.All'); DataSets = @('Groups'); Tags = 'Groups', 'Ownership'
            }))
    $records.Add((& $record @{
                Id = 'ARG.GRP.004'; Title = 'Group expiration policy configured'; Area = 'GroupsTeams'; Category = 'Lifecycle'; Severity = 'Medium'
                Status = 'Failed'; Summary = 'No Microsoft 365 group expiration policy is configured.'
                Description = 'Reads `groupLifecyclePolicies`; an empty list fails.'
                Rationale = 'Without expiration, unused groups and Teams accumulate indefinitely.'
                Steps = "1. In Entra admin center > Groups > Expiration, set a lifetime (for example 365 days).`n2. Apply it to all or selected groups."
                PortalUrl = $entraPortal; References = @(, $refExpiry)
                Scopes = @('Directory.Read.All'); DataSets = @('GroupLifecyclePolicies'); Tags = 'Groups', 'Lifecycle'
            }))
    $records.Add((& $record @{
                Id = 'ARG.GRP.005'; Title = 'Microsoft 365 group creation is restricted'; Area = 'GroupsTeams'; Category = 'Group governance'; Severity = 'Medium'
                Status = 'Investigate'; Summary = 'All users can create Microsoft 365 groups and Teams (EnableGroupCreation = true).'
                Description = 'Reads the Group.Unified directory setting `EnableGroupCreation`.'
                Rationale = 'Unrestricted creation suits some organisations; others prefer a request process.'
                Steps = "1. Decide on a creation policy.`n2. If needed, restrict creation to a security group."
                PortalUrl = $entraPortal; References = @(, $refCreation)
                Scopes = @('Directory.Read.All'); DataSets = @('GroupSettings'); Tags = 'Groups', 'Policy'
            }))
    $records.Add((& $record @{
                Id = 'ARG.GRP.006'; Title = 'Group naming policy configured'; Area = 'GroupsTeams'; Category = 'Group governance'; Severity = 'Low'
                Status = 'Passed'; Summary = 'A naming policy is configured (prefix "GRP-").'
                Description = 'Reads `PrefixSuffixNamingRequirement` and custom blocked words in the Group.Unified setting.'
                Rationale = 'Consistent names make groups easier to find and govern.'
                Steps = '1. Configure a prefix/suffix naming policy.'
                PortalUrl = $entraPortal; References = @(, $refNaming)
                Scopes = @('Directory.Read.All'); DataSets = @('GroupSettings'); Tags = 'Groups', 'Policy'
            }))
    $records.Add((& $record @{
                Id = 'ARG.GRP.007'; Title = 'Inactive Teams (more than 180 days)'; Area = 'GroupsTeams'; Category = 'Lifecycle'; Severity = 'Low'
                Status = 'Investigate'; Summary = $concealed; Parameters = @{ InactiveDays = 180 }
                Description = 'Teams whose last activity in the D180 Teams activity report is older than **{InactiveDays}** days.'
                Rationale = 'Inactive Teams hold content nobody curates.'
                Steps = '1. Archive or delete inactive Teams after confirming with their owners.'
                PortalUrl = $m365Portal; References = @(, $refReports)
                Scopes = 'Reports.Read.All', 'ReportSettings.Read.All'; DataSets = 'TeamsActivity', 'ReportSettings'; Tags = 'Teams', 'Lifecycle', 'Reports'
            }))
    $records.Add((& $record @{
                Id = 'ARG.GRP.008'; Title = 'Teams with guests and no owner'; Area = 'GroupsTeams'; Category = 'Ownership'; Severity = 'High'
                Status = 'Passed'; Summary = 'No ownerless team has guest members.'
                Description = 'Intersection of ownerless Microsoft 365 groups that are Teams and groups with guest members.'
                Rationale = 'Guests in an ownerless team are not reviewed by anyone.'
                Steps = '1. Assign owners and review guest membership.'
                PortalUrl = $m365Portal; References = @(, $refB2B)
                Scopes = 'Group.Read.All', 'GroupMember.Read.All'; DataSets = 'Groups', 'Users'; Tags = 'Teams', 'Guests', 'Ownership'
            }))

    # ------------------------------------------------------------------ SharePoint
    $records.Add((& $record @{
                Id = 'ARG.SPO.001'; Title = 'Orphaned sites'; Area = 'SharePoint'; Category = 'Ownership'; Severity = 'High'
                Status = 'Failed'; Summary = '3 group-connected sites belong to a group without owners. Classic and communication sites were not evaluated (PnP.PowerShell not connected).'; Evaluated = 402
                Findings = @(
                    [pscustomobject]@{ SiteTitle = 'Project Atlas'; SiteUrl = 'https://contoso.sharepoint.com/sites/ProjectAtlas'; GroupId = (& $newId); StorageUsedGB = 12.4 }
                    [pscustomobject]@{ SiteTitle = 'Temp Workshop 2024'; SiteUrl = 'https://contoso.sharepoint.com/sites/TempWorkshop2024'; GroupId = (& $newId); StorageUsedGB = 0.8 }
                    [pscustomobject]@{ SiteTitle = 'Vendor Onboarding <x>'; SiteUrl = 'https://contoso.sharepoint.com/sites/VendorOnboarding'; GroupId = (& $newId); StorageUsedGB = 3.1 }
                )
                Description = 'Group-connected sites whose group has zero owners (Graph). Classic and communication sites without valid site administrators are evaluated through PnP.PowerShell when connected.'
                Rationale = 'Orphaned sites have nobody to manage permissions, sharing and retention.'
                Steps = '1. Assign owners to the connected group, or site administrators to the site.'
                PortalUrl = $spoPortal; References = @(, $refSharing)
                Scopes = 'Sites.Read.All', 'Group.Read.All'; DataSets = 'Groups'; Tags = 'SharePoint', 'Ownership'
            }))
    $records.Add((& $record @{
                Id = 'ARG.SPO.002'; Title = 'Inactive sites (more than 180 days)'; Area = 'SharePoint'; Category = 'Lifecycle'; Severity = 'Low'
                Status = 'Investigate'; Summary = $concealed; Parameters = @{ InactiveDays = 180 }
                Description = 'Sites whose last activity in the D180 SharePoint site usage report is older than **{InactiveDays}** days.'
                Rationale = 'Inactive sites keep content and permissions nobody reviews.'
                Steps = '1. Confirm with owners, then archive or delete inactive sites.'
                PortalUrl = $spoPortal; References = @(, $refReports)
                Scopes = 'Reports.Read.All', 'ReportSettings.Read.All'; DataSets = 'SharePointSiteUsage', 'ReportSettings'; Tags = 'SharePoint', 'Lifecycle', 'Reports'
            }))
    $records.Add((& $record @{
                Id = 'ARG.SPO.003'; Title = 'Tenant external sharing level'; Area = 'SharePoint'; Category = 'Sharing'; Severity = 'Medium'
                Status = 'Investigate'; Summary = 'Sharing allows Anyone links (sharingCapability = externalUserAndGuestSharing).'
                Description = 'Reads `admin/sharepoint/settings.sharingCapability`.'
                Rationale = 'Anyone links can be forwarded without authentication; some organisations accept this for specific scenarios.'
                Steps = "1. Decide whether Anyone links are needed.`n2. If not, set the tenant level to *New and existing guests*."
                PortalUrl = $spoPortal; References = @(, $refSharing)
                Scopes = @('SharePointTenantSettings.Read.All'); DataSets = @('SharePointTenantSettings'); Tags = 'SharePoint', 'Sharing'
            }))
    $records.Add((& $record @{
                Id = 'ARG.SPO.004'; Title = 'Sites near their storage quota (more than 90%)'; Area = 'SharePoint'; Category = 'Capacity'; Severity = 'Low'
                Status = 'Passed'; Summary = 'No site uses more than 90% of its storage quota (402 sites evaluated).'; Evaluated = 402; Parameters = @{ QuotaPercent = 90 }
                Description = 'Sites where storage used / storage allocated in the site usage report exceeds **{QuotaPercent}**%.'
                Rationale = 'Sites that hit their quota become read-only for uploads.'
                Steps = '1. Increase the quota or clean up content.'
                PortalUrl = $spoPortal; References = @(, $refReports)
                Scopes = @('Reports.Read.All'); DataSets = @('SharePointSiteUsage'); Tags = 'SharePoint', 'Capacity'
            }))
    $records.Add((& $record @{
                Id = 'ARG.SPO.005'; Title = 'OneDrive of deleted or disabled users with content'; Area = 'SharePoint'; Category = 'Lifecycle'; Severity = 'Low'
                Status = 'NotRun'; SkipReason = 'Excluded with -ExcludeId.'
                Description = 'OneDrive accounts (usage report) whose owner is deleted or disabled and that still hold content.'
                Rationale = 'Leaver OneDrives hold business data that should be transferred or retained deliberately.'
                Steps = '1. Transfer needed content to a manager, then let retention apply.'
                PortalUrl = $spoPortal; References = @(, $refReports)
                Scopes = @('Reports.Read.All'); DataSets = 'Users'; Tags = 'OneDrive', 'Lifecycle'
            }))

    # ------------------------------------------------------------------ Exchange
    $records.Add((& $record @{
                Id = 'ARG.EXO.001'; Title = 'Shared mailboxes with sign-in enabled'; Area = 'Exchange'; Category = 'Mailbox hygiene'; Severity = 'Medium'
                Status = 'Failed'; Summary = '3 of 41 shared mailboxes have sign-in enabled on the user object.'; Evaluated = 41
                Findings = @(
                    [pscustomobject]@{ DisplayName = 'Reception'; UserPrincipalName = "reception@$domain"; ObjectId = (& $newId); AccountEnabled = $true }
                    [pscustomobject]@{ DisplayName = 'Support Desk'; UserPrincipalName = "support@$domain"; ObjectId = (& $newId); AccountEnabled = $true }
                    [pscustomobject]@{ DisplayName = '=cmd|'' /C calc''!A0'; UserPrincipalName = "events@$domain"; ObjectId = (& $newId); AccountEnabled = $true }
                )
                Description = 'Shared mailboxes whose corresponding user account has `accountEnabled` = true.'
                Rationale = 'Shared mailboxes should be accessed through delegation, not by signing in to them directly.'
                Steps = '1. Block sign-in for the shared mailbox user account.'
                PowerShell = "# Sample only - review before running`nConnect-MgGraph -Scopes 'User.ReadWrite.All'`nUpdate-MgUser -UserId '<ObjectId>' -AccountEnabled:`$false"
                PortalUrl = $exoPortal; References = @(, $refShared)
                Services = 'Graph', 'Exchange'; Scopes = @('User.Read.All'); DataSets = 'Users', 'Mailboxes'; Tags = 'Exchange', 'Mailboxes'
            }))
    $records.Add((& $record @{
                Id = 'ARG.EXO.002'; Title = 'Distribution groups without owner'; Area = 'Exchange'; Category = 'Ownership'; Severity = 'Low'
                Status = 'Failed'; Summary = '7 of 96 distribution groups have no owner (ManagedBy empty).'; Evaluated = 96
                Findings = @(1..7 | ForEach-Object { [pscustomobject]@{ DisplayName = 'DL-' + (& $pick @('Newsletter', 'Alerts', 'Suppliers', 'Partners', 'Branch')) + "-$_"; PrimarySmtpAddress = "dl$_@contoso.example"; Members = $rng.Next(1, 120) } })
                Description = 'Distribution groups whose `ManagedBy` is empty.'
                Rationale = 'Without an owner nobody approves membership changes.'
                Steps = '1. Set at least one owner on each distribution group.'
                PortalUrl = $exoPortal; References = @(, $refShared)
                Services = @('Exchange'); DataSets = @('Mailboxes'); Tags = 'Exchange', 'Ownership'
            }))
    $records.Add((& $record @{
                Id = 'ARG.EXO.003'; Title = 'Inactive user mailboxes (more than 90 days)'; Area = 'Exchange'; Category = 'Lifecycle'; Severity = 'Low'
                Status = 'NotRun'; SkipReason = 'Disabled in configuration.'; Parameters = @{ InactiveDays = 90 }
                Description = 'User mailboxes whose last activity in the mailbox usage report is older than **{InactiveDays}** days.'
                Rationale = 'Inactive mailboxes may belong to leavers.'
                Steps = '1. Confirm with the manager, then convert or remove the mailbox.'
                PortalUrl = $exoPortal; References = @(, $refReports)
                Scopes = @('Reports.Read.All'); DataSets = @('ReportSettings'); Tags = 'Exchange', 'Lifecycle', 'Reports'
            }))

    # Resolve {Parameter} placeholders in titles/descriptions the way the runner does for titles.
    foreach ($r in $records) {
        $r.Title = Resolve-ArgusTemplate -Template $r.Title -Values $r.Parameters
        $r.Description = Resolve-ArgusTemplate -Template $r.Description -Values $r.Parameters
    }

    $config = Get-ArgusConfig
    $config.Report.CompanyName = 'Fabrikam IT Services (fictitious MSP)'
    $config.Exclusions.UserPrincipalNames = @("breakglass02@$domain")

    $environment = [pscustomobject]@{
        ConnectedServices    = [string[]]@('Graph', 'Exchange')
        GrantedScopes        = [string[]]@('User.Read.All', 'Group.Read.All', 'GroupMember.Read.All', 'Directory.Read.All', 'AuditLog.Read.All', 'Application.Read.All',
            'RoleManagement.Read.Directory', 'Organization.Read.All', 'Policy.Read.All', 'Device.Read.All', 'Reports.Read.All', 'ReportSettings.Read.All',
            'Sites.Read.All', 'SharePointTenantSettings.Read.All')
        Licenses             = [string[]]@()
        ConcealedReportNames = $true
        TenantId             = '7f3c2a10-0000-4000-8000-00000000c0de'
        TenantName           = 'Contoso Ltd (fictitious)'
        TenantDefaultDomain  = $domain
        Account              = "argus.auditor@$domain"
        AuthMode             = 'Interactive (delegated)'
    }

    $results = @($records)
    $score = Get-ArgusScore -Result $results -Scoring $config.Scoring
    $started = [datetimeoffset]::new(2026, 10, 19, 9, 0, 0, [timespan]::FromHours(2))
    $document = ConvertTo-ArgusResultDocument -Result $results -Score $score -Environment $environment -Config $config `
        -StartedAt $started -FinishedAt $started.AddSeconds(192.4) -Filter @{ ExcludeId = @('ARG.SPO.005') } -ConfigPath 'contoso.config.json'
    $document.Run.TimeZone = 'W. Europe Standard Time'

    $file = Export-ArgusResultJson -Document $document -Path $OutputPath
    Write-Information "Sample results written to $($file.FullName) (score $($score.Score) $($score.Grade), coverage $($score.Coverage)%)." -InformationAction Continue
} $OutputPath
