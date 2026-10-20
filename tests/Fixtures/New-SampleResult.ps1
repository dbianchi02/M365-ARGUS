#Requires -Version 7.2
<#
.SYNOPSIS
    Regenerates tests/Fixtures/sample-results.json: a realistic, fully fictitious ARGUS run.

.DESCRIPTION
    Builds a results document for the fictitious tenant "Contoso" with checks in all seven areas,
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
            'PowerShell', 'PortalUrl', 'References', 'Services', 'Scopes', 'Licenses', 'DataSets', 'Tags', 'UsesBeta',
            'Title', 'Category', 'Severity', 'Description', 'Rationale', 'Steps') {
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
            References      = @($m.References | Where-Object { $_ } | ForEach-Object { [pscustomobject]@{ Title = $_[0]; Url = $_[1] } })
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
                Id = 'ARG.ENT.007'; Title = 'At least 2 emergency access (break-glass) accounts'; Area = 'EntraID'; Category = 'Privileged access'; Severity = 'High'
                Status = 'Failed'; Summary = '1 of 2 emergency access accounts (matching NamePatterns (no account listed in the Accounts parameter)) meet the requirements; at least 2 are needed.'
                Evaluated = 2; Affected = 1
                Findings = @(
                    [pscustomobject][ordered]@{ DisplayName = 'Break Glass 02'; UserPrincipalName = "breakglass02@$domain"; Compliant = 'No'; Issues = 'no direct active Global Administrator assignment'; GlobalAdmin = 'Eligible only'; CloudOnly = $true; LastSignIn = 'Never or unknown'; ObjectId = (& $newId) }
                    [pscustomobject][ordered]@{ DisplayName = 'Break Glass 01'; UserPrincipalName = "breakglass01@$domain"; Compliant = 'Yes'; Issues = ''; GlobalAdmin = 'Active (direct)'; CloudOnly = $true; LastSignIn = 'Never or unknown'; ObjectId = (& $newId) }
                )
                Description = 'Emergency access accounts.'; Rationale = 'Lockout prevention.'; Steps = '1. Create two cloud-only accounts.'
                PortalUrl = $entraPortal; References = @(, $refRoles)
                Scopes = 'User.Read.All', 'RoleManagement.Read.Directory', 'GroupMember.Read.All'; DataSets = 'Users', 'DirectoryRoles'; Tags = 'Roles', 'Privileged access', 'Resilience'
            }))
    $records.Add((& $record @{
                Id = 'ARG.ENT.005'; Title = 'Guests inactive for more than 90 days'; Area = 'EntraID'; Category = 'External identities'; Severity = 'Medium'
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
    $records.Add((& $record @{
                Id = 'ARG.ENT.012'; Title = 'LinkedIn account connections disabled'; Area = 'EntraID'; Category = 'User settings'; Severity = 'Low'
                Status = 'Investigate'; Summary = 'Manual verification required: the LinkedIn account connections setting cannot be read through Microsoft Graph. Check it in the Microsoft Entra admin center (Users > User settings); it should be No, or limited to a selected group.'
                Description = 'LinkedIn account connections.'; Rationale = 'Data sharing with LinkedIn.'; Steps = '1. Check the setting.'
                PortalUrl = $entraPortal; References = @(, $refB2B); Tags = 'User settings', 'Manual'
            }))

    $admins = foreach ($i in 1..6) {
        $p = & $person
        [pscustomobject]@{ DisplayName = $p.DisplayName; UserPrincipalName = $p.UserPrincipalName; ObjectId = (& $newId); AssignmentType = 'Active'; Via = if ($i -eq 6) { 'Group: Tier0-Admins' } else { 'Direct' } }
    }
    $admins[0].DisplayName = 'Break Glass 01'; $admins[0].UserPrincipalName = "breakglass01@$domain"
    $records.Add((& $record @{
                Id = 'ARG.ENT.008'; Title = 'Global Administrator count outside 2 to 4'; Area = 'EntraID'; Category = 'Privileged access'; Severity = 'High'
                Status = 'Failed'; Summary = '6 Global Administrators found (active assignments); the recommended range is 2 to 4. Eligible PIM assignments not evaluated: Entra ID P2 not detected.'
                Affected = 6; Evaluated = 6; Findings = $admins; Parameters = @{ MinCount = 2; MaxCount = 4 }
                Description = 'Counts active (and, with Entra ID P2, eligible) assignments of the Global Administrator role, expanding role-assignable groups.'
                Rationale = 'Too few Global Administrators is a recovery risk; too many widens the blast radius of a compromised account.'
                Steps = "1. Keep two emergency-access accounts.`n2. Move day-to-day administration to least-privileged roles.`n3. Remove unnecessary Global Administrator assignments."
                PortalUrl = $entraPortal; References = @(, $refRoles)
                Scopes = 'RoleManagement.Read.Directory', 'Directory.Read.All'; DataSets = @('DirectoryRoles'); Tags = 'Roles'
            }))
    $records.Add((& $record @{
                Id = 'ARG.ENT.009'; Title = 'Privileged roles assigned to guests'; Area = 'EntraID'; Category = 'Privileged access'; Severity = 'High'
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
                Id = 'ARG.ENT.013'; Title = 'Security groups without owners'; Area = 'EntraID'; Category = 'Group governance'; Severity = 'Low'
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
                Id = 'ARG.ENT.014'; Title = 'Stale devices (no sign-in for more than 180 days)'; Area = 'EntraID'; Category = 'Device hygiene'; Severity = 'Low'
                Status = 'Failed'; Summary = '3,000 of 8,412 devices have not signed in for 180+ days.'; Evaluated = 8412; Findings = $devices; Parameters = @{ StaleDays = 180 }
                Description = 'Devices whose `approximateLastSignInDateTime` is older than **{StaleDays}** days.'
                Rationale = 'Stale devices make device-based reporting unreliable and clutter the directory.'
                Steps = "1. Disable stale devices.`n2. After a grace period, delete them.`n3. Make sure BitLocker recovery keys you still need are preserved."
                PowerShell = "# Sample only - review before running`nConnect-MgGraph -Scopes 'Device.ReadWrite.All'`nUpdate-MgDevice -DeviceId '<Id>' -AccountEnabled:`$false"
                PortalUrl = $entraPortal; References = @(, $refDevices)
                Scopes = @('Device.Read.All'); DataSets = @('Devices'); Tags = 'Devices', 'Lifecycle'
            }))
    $records.Add((& $record @{
                Id = 'ARG.ENT.003'; Title = 'Guest invitations are restricted'; Area = 'EntraID'; Category = 'External identities'; Severity = 'Medium'
                Status = 'Investigate'; Summary = 'Guest invitations are allowed for admins, guest inviters and all members (allowInvitesFrom = adminsGuestInvitersAndAllMembers).'
                Description = 'Reads `authorizationPolicy.allowInvitesFrom`.'
                Rationale = 'Letting every member invite guests is acceptable in some organisations but should be a deliberate decision.'
                Steps = '1. In **External collaboration settings**, restrict guest invitations to admins and users in the Guest Inviter role if appropriate.'
                PortalUrl = $entraPortal; References = @(, $refCollab)
                Scopes = @('Policy.Read.All'); DataSets = @('AuthorizationPolicy'); Tags = 'Guests', 'Policy'
            }))
    $records.Add((& $record @{
                Id = 'ARG.ENT.010'; Title = 'Users can register applications'; Area = 'EntraID'; Category = 'Application governance'; Severity = 'Medium'
                Status = 'Failed'; Summary = 'All users can register applications (defaultUserRolePermissions.allowedToCreateApps = true).'
                Description = 'Reads `authorizationPolicy.defaultUserRolePermissions.allowedToCreateApps`.'
                Rationale = 'Uncontrolled app registrations make application ownership and credential hygiene hard to govern.'
                Steps = "1. In **User settings**, set *Users can register applications* to **No**.`n2. Assign the Application Developer role to users who need it."
                PortalUrl = $entraPortal; References = @(, $refCreds)
                Scopes = @('Policy.Read.All'); DataSets = @('AuthorizationPolicy'); Tags = 'Applications', 'Policy'
            }))
    $records.Add((& $record @{
                Id = 'ARG.ENT.011'; Title = 'Users can create tenants'; Area = 'EntraID'; Category = 'Tenant governance'; Severity = 'Low'
                Status = 'Passed'; Summary = 'Non-admin users cannot create tenants.'
                Description = 'Reads `authorizationPolicy.defaultUserRolePermissions.allowedToCreateTenants`.'
                Rationale = 'Tenants created by users fall outside central governance.'
                Steps = '1. In **User settings**, set *Restrict non-admin users from creating tenants* to **Yes**.'
                PortalUrl = $entraPortal; References = @(, $refCollab)
                Scopes = @('Policy.Read.All'); DataSets = @('AuthorizationPolicy'); Tags = 'Policy'
            }))
    $records.Add((& $record @{
                Id = 'ARG.ENT.015'; Title = 'Directory synchronisation freshness'; Area = 'EntraID'; Category = 'Hybrid identity'; Severity = 'Medium'
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
                Id = 'ARG.APP.002'; Title = 'Client secrets expiring within 30 days'; Area = 'Applications'; Category = 'Credential hygiene'; Severity = 'Medium'
                Status = 'Failed'; Summary = '4 client secrets on 4 of 162 app registrations expire within 30 days.'; Affected = 4; Evaluated = 162
                Findings = @((& $appRow 3 'Secret'), (& $appRow 9 'Secret'), (& $appRow 17 'Secret'), (& $appRow 28 'Secret')); Parameters = @{ DaysAhead = 30 }
                Description = 'Password credentials whose `endDateTime` falls within the next **{DaysAhead}** days.'
                Rationale = 'Expired secrets break integrations; planned rotation avoids outages.'
                Steps = "1. Create a new secret.`n2. Update the consuming service.`n3. Delete the old secret."
                PortalUrl = $entraPortal; References = @(, $refCreds)
                Scopes = @('Application.Read.All'); DataSets = @('Applications'); Tags = 'Applications', 'Credentials'
            }))
    $records.Add((& $record @{
                Id = 'ARG.APP.003'; Title = 'Expired client secrets still present'; Area = 'Applications'; Category = 'Credential hygiene'; Severity = 'Low'
                Status = 'Failed'; Summary = '9 expired client secrets are still present on 7 app registrations.'; Affected = 9; Evaluated = 162
                Findings = @(1..9 | ForEach-Object { & $appRow (-$rng.Next(5, 700)) 'Secret' })
                Description = 'Password credentials whose `endDateTime` is in the past.'
                Rationale = 'Expired credentials are clutter and hide which credentials are really in use.'
                Steps = '1. Delete expired secrets from the app registration.'
                PortalUrl = $entraPortal; References = @(, $refCreds)
                Scopes = @('Application.Read.All'); DataSets = @('Applications'); Tags = 'Applications', 'Credentials'
            }))
    $records.Add((& $record @{
                Id = 'ARG.APP.005'; Title = 'Certificates expiring within 30 days'; Area = 'Applications'; Category = 'Credential hygiene'; Severity = 'Medium'
                Status = 'Passed'; Summary = 'No certificate expires within 30 days (41 certificates evaluated).'; Evaluated = 41; Parameters = @{ DaysAhead = 30 }
                Description = 'Key credentials (usage Verify) whose `endDateTime` falls within **{DaysAhead}** days.'
                Rationale = 'Expired certificates break app-only integrations.'
                Steps = '1. Upload a new certificate, update the service, then remove the old one.'
                PortalUrl = $entraPortal; References = @(, $refCreds)
                Scopes = @('Application.Read.All'); DataSets = @('Applications'); Tags = 'Applications', 'Credentials'
            }))
    $records.Add((& $record @{
                Id = 'ARG.APP.006'; Title = 'Expired certificates still present'; Area = 'Applications'; Category = 'Credential hygiene'; Severity = 'Low'
                Status = 'Error'; ErrorMessage = 'Response status code does not indicate success: 429 (Too Many Requests). Retry limit (5) reached for GET /v1.0/applications.'
                Description = 'Key credentials whose `endDateTime` is in the past.'
                Rationale = 'Expired certificates are clutter.'
                Steps = '1. Remove expired certificates from the app registration.'
                PortalUrl = $entraPortal; References = @(, $refCreds)
                Scopes = @('Application.Read.All'); DataSets = @('Applications'); Tags = 'Applications', 'Credentials'
            }))
    $records.Add((& $record @{
                Id = 'ARG.APP.001'; Title = 'App registrations without owners'; Area = 'Applications'; Category = 'Application governance'; Severity = 'Medium'
                Status = 'Failed'; Summary = '17 of 162 app registrations have no owner.'; Evaluated = 162
                Findings = @(1..17 | ForEach-Object { [pscustomobject]@{ DisplayName = (& $pick $appNames) + " $_"; AppId = (& $newId); Created = (& $iso (& $daysAgo 30 1800)); SignInAudience = (& $pick @('AzureADMyOrg', 'AzureADMultipleOrgs')) } })
                Description = 'App registrations with zero owners (owners fetched with JSON batching).'
                Rationale = 'Ownerless apps have nobody responsible for credentials, permissions and lifecycle.'
                Steps = '1. Assign at least one owner (ideally two) to each app registration.'
                PortalUrl = $entraPortal; References = @(, $refCreds)
                Scopes = @('Application.Read.All'); DataSets = @('Applications'); Tags = 'Applications', 'Ownership'
            }))
    $records.Add((& $record @{
                Id = 'ARG.APP.004'; Title = 'Client secrets with a lifetime above 24 months'; Area = 'Applications'; Category = 'Credential hygiene'; Severity = 'Low'
                Status = 'Failed'; Summary = '5 client secrets have a lifetime longer than 24 months.'; Affected = 5; Evaluated = 162; Parameters = @{ MaxLifetimeMonths = 24 }
                Findings = @(1..5 | ForEach-Object { $r = & $appRow ($rng.Next(200, 3000)) 'Secret'; $r | Add-Member -NotePropertyName LifetimeMonths -NotePropertyValue ($rng.Next(25, 120)) -PassThru })
                Description = 'Password credentials whose lifetime (`endDateTime` minus `startDateTime`) exceeds **{MaxLifetimeMonths}** months.'
                Rationale = 'Long-lived secrets are rarely rotated and outlive the people who created them.'
                Steps = '1. Replace the secret with one of shorter lifetime, or move to a certificate or managed identity.'
                PortalUrl = $entraPortal; References = @(, $refCreds)
                Scopes = @('Application.Read.All'); DataSets = @('Applications'); Tags = 'Applications', 'Credentials'
            }))
    $records.Add((& $record @{
                Id = 'ARG.APP.007'; Title = 'Certificates with a lifetime above 180 days'; Area = 'Applications'; Category = 'Credential hygiene'; Severity = 'Low'
                Status = 'Failed'; Summary = '3 of 41 valid authentication certificates have a lifetime longer than 180 days.'; Affected = 3; Evaluated = 41
                Findings = @(1..3 | ForEach-Object {
                        $lifetime = $rng.Next(365, 1826); $start = & $daysAgo 30 300
                        [pscustomobject][ordered]@{
                            AppName = (& $pick $appNames); AppId = (& $newId); CertificateName = "CN=app-$_.contoso.com"
                            ValidFrom = $start.ToString('yyyy-MM-dd'); Expires = $start.AddDays($lifetime).ToString('yyyy-MM-dd'); LifetimeDays = $lifetime
                            KeyId = (& $newId); ObjectId = (& $newId)
                        }
                    } | Sort-Object LifetimeDays -Descending)
                Description = 'Valid authentication certificates whose lifetime exceeds **{MaxLifetimeDays}** days.'
                Rationale = 'Long-lived certificates are rarely rotated.'
                Steps = '1. Replace the certificate with one of shorter lifetime.'
                PortalUrl = $entraPortal; References = @(, $refCreds)
                Scopes = @('Application.Read.All'); DataSets = @('Applications'); Tags = 'Applications', 'Credentials'
            }))

    # ------------------------------------------------------------------ Licensing
    $records.Add((& $record @{
                Id = 'ARG.LIC.006'; Title = 'Unused licences per SKU'; Area = 'Licensing'; Category = 'Cost'; Severity = 'Medium'
                Status = 'Failed'; Summary = '3 of 9 paid SKUs have more than 10% or more than 5 seats unused (81 unused seats in total).'; Evaluated = 9; Parameters = @{ UnusedPercent = 10; UnusedSeats = 5 }
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
                Id = 'ARG.LIC.005'; Title = 'Licence assignment errors'; Area = 'Licensing'; Category = 'Licence hygiene'; Severity = 'Medium'
                Status = 'Passed'; Summary = 'No licence assignment errors (1,391 licensed users evaluated).'; Evaluated = 1391
                Description = 'Users whose `licenseAssignmentStates` contain an entry in state Error.'
                Rationale = 'Assignment errors leave users without the services they are expected to have.'
                Steps = '1. Resolve the conflict (for example missing usage location or conflicting service plans) and reprocess.'
                PortalUrl = $entraPortal; References = @(, $refLicErr)
                Scopes = @('User.Read.All'); DataSets = @('Users'); Tags = 'Licensing'
            }))
    $records.Add((& $record @{
                Id = 'ARG.LIC.007'; Title = 'Shared mailboxes with a licence'; Area = 'Licensing'; Category = 'Cost'; Severity = 'Low'
                Status = 'Investigate'; Summary = '2 of 14 shared mailboxes have a licence with no size, archive or hold that requires it (2 more are justified by size, archive or hold).'; Evaluated = 14
                Findings = @(
                    [pscustomobject][ordered]@{ DisplayName = 'Info'; UserPrincipalName = "info@$domain"; Licences = @('Office 365 E1'); MailboxSizeGB = 4.1; ObjectId = (& $newId) }
                    [pscustomobject][ordered]@{ DisplayName = 'Reception'; UserPrincipalName = "reception@$domain"; Licences = @('Microsoft 365 Business Basic'); MailboxSizeGB = 0.7; ObjectId = (& $newId) }
                )
                Description = 'Shared mailboxes (Exchange Online) whose user object has licences assigned.'
                Rationale = 'Shared mailboxes do not need a licence unless they exceed 50 GB, have an archive or are on hold.'
                Steps = "1. Check size, archive and holds.`n2. Remove the licence where it is not required."
                PortalUrl = $m365Portal; References = @(, $refShared)
                Services = 'Graph', 'Exchange'; Scopes = @('User.Read.All'); DataSets = 'Users', 'Mailboxes'; Tags = 'Licensing', 'Exchange'
            }))

    $skus = 'Microsoft 365 E3', 'Microsoft 365 Business Premium', 'Office 365 E1', 'Exchange Online (Plan 1)'
    $direct = foreach ($i in 1..12) {
        $p = & $person
        $licence = & $pick $skus
        [pscustomobject][ordered]@{
            DisplayName = $p.DisplayName; UserPrincipalName = $p.UserPrincipalName; DirectLicences = @($licence)
            AlsoFromGroup = [string[]]@(if ($i -le 4) { $licence }); AccountEnabled = $true; UserType = 'Member'; ObjectId = (& $newId)
        }
    }
    $records.Add((& $record @{
                Id = 'ARG.LIC.008'; Title = 'Paid licences assigned directly to users'; Area = 'Licensing'; Category = 'Licence management'; Severity = 'Low'
                Status = 'Failed'; Summary = '12 of 1,391 licensed users have paid licences assigned directly; 4 of them also receive the same licence from a group. 37 more have only free or trial licences assigned directly (not counted).'; Evaluated = 1391; Findings = $direct
                Description = 'Users with licences assigned directly instead of through group-based licensing.'
                Rationale = 'Direct assignments are not driven by group membership.'
                Steps = '1. Move the users to group-based licensing and remove the direct assignments.'
                PortalUrl = $entraPortal; References = @(, $refLicErr)
                Scopes = @('User.Read.All'); DataSets = 'Users', 'SubscribedSkus'; Tags = 'Licensing', 'Groups'
            }))

    $disabled = foreach ($i in 1..6) {
        $p = & $person
        [pscustomobject][ordered]@{ DisplayName = $p.DisplayName; UserPrincipalName = $p.UserPrincipalName; Licences = @((& $pick $skus)); UserType = 'Member'; SyncedFromOnPrem = ($i % 2 -eq 0); ObjectId = (& $newId) }
    }
    $disabled[2].DisplayName = 'Former employee <b>bold</b> & "quotes"'
    $records.Add((& $record @{
                Id = 'ARG.LIC.001'; Title = 'Disabled users that still have licences'; Area = 'Licensing'; Category = 'Licence hygiene'; Severity = 'High'
                Status = 'Failed'; Summary = '6 of 87 disabled accounts still have licences assigned (3 shared, room or equipment mailboxes excluded).'; Evaluated = 87; Findings = $disabled
                Description = 'Disabled accounts with licences, excluding shared, room and equipment mailboxes (detected through Exchange Online).'
                Rationale = 'Licences on disabled accounts are paid for but unusable.'
                Steps = "1. Check whether the mailbox must be retained (convert to shared or apply a hold).`n2. Remove the licences."
                PortalUrl = $m365Portal; References = @(, $refInactive)
                Services = 'Graph', 'Exchange'; Scopes = @('User.Read.All'); DataSets = 'Users', 'SubscribedSkus', 'Mailboxes'; Tags = 'Licensing', 'Lifecycle'
            }))

    $records.Add((& $record @{
                Id = 'ARG.LIC.002'; Title = 'Enabled licensed users inactive for more than 90 days'; Area = 'Licensing'; Category = 'Licence hygiene'; Severity = 'High'
                Status = 'Skipped'; SkipReason = $p1Skip; Parameters = @{ InactiveDays = 90 }
                Description = 'Same as ARG.ENT.001, restricted to users with at least one licence assigned.'
                Rationale = 'Licences assigned to inactive users are a direct cost with no business value.'
                Steps = "1. Confirm the users are no longer active.`n2. Remove the licences or reassign them."
                PortalUrl = $m365Portal; References = @(, $refInactive)
                Scopes = 'User.Read.All', 'AuditLog.Read.All'; Licenses = 'AAD_PREMIUM'; DataSets = 'Users', 'SubscribedSkus'; Tags = 'Lifecycle', 'Licensing'
            }))

    # ------------------------------------------------------------------ Groups & Teams
    $groupRow = {
        param([string] $Name, [bool] $Team, [int] $Owners = 2)
        [pscustomobject][ordered]@{
            DisplayName = $Name; Mail = (($Name -replace '[^A-Za-z0-9]', '').ToLowerInvariant() + "@$domain"); Team = if ($Team) { 'Yes' } else { 'No' }
            Owners = $Owners; Created = (& $daysAgo 30 1500).ToString('yyyy-MM-dd'); GroupId = (& $newId)
        }
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
    ) | Sort-Object DisplayName
    $records.Add((& $record @{
                Id = 'ARG.GRP.007'; Title = 'Public Microsoft 365 groups'; Area = 'GroupsTeams'; Category = 'Group governance'; Severity = 'Medium'
                Status = 'Failed'; Summary = '11 of 486 Microsoft 365 groups are public (8 are Teams).'; Evaluated = 486; Findings = $publicGroups
                Description = 'Public Microsoft 365 groups.'; Rationale = 'Anyone can join.'; Steps = '1. Review.'
                PortalUrl = $m365Portal; References = @(, $refCreation)
                Scopes = @('Group.Read.All'); DataSets = @('Groups'); Tags = 'Groups', 'Teams'
            }))
    $ownerless = @('Project Atlas', 'Temp Workshop 2024', 'Vendor Onboarding <x>', 'Old Newsletter') | ForEach-Object {
        $g = & $groupRow $_ ($_ -ne 'Old Newsletter') 0
        [pscustomobject][ordered]@{ DisplayName = $g.DisplayName; Mail = $g.Mail; Team = $g.Team; Visibility = 'Private'; Created = $g.Created; GroupId = $g.GroupId }
    }
    $records.Add((& $record @{
                Id = 'ARG.GRP.004'; Title = 'Microsoft 365 groups and Teams without owners'; Area = 'GroupsTeams'; Category = 'Ownership'; Severity = 'High'
                Status = 'Failed'; Summary = '4 of 486 Microsoft 365 groups have no owner (3 are Teams).'; Evaluated = 486; Findings = $ownerless
                Description = 'Ownerless groups.'; Rationale = 'Nobody manages them.'; Steps = '1. Add owners.'
                PortalUrl = $m365Portal; References = @(, $refExpiry)
                Scopes = @('Group.Read.All'); DataSets = @('Groups'); Tags = 'Groups', 'Teams', 'Ownership'
            }))
    $singleOwner = @(1..38 | ForEach-Object {
            $p = & $person
            [pscustomobject][ordered]@{
                DisplayName = "Team $_ - " + (& $pick @('Planning', 'Ops', 'Design', 'Support')); Team = if ($rng.Next(2) -eq 1) { 'Yes' } else { 'No' }
                Owner = $p.UserPrincipalName; OwnerEnabled = if ($_ -le 5) { 'No' } else { 'Yes' }; Created = (& $daysAgo 30 1500).ToString('yyyy-MM-dd'); GroupId = (& $newId)
            }
        })
    $records.Add((& $record @{
                Id = 'ARG.GRP.005'; Title = 'Microsoft 365 groups and Teams with a single owner'; Area = 'GroupsTeams'; Category = 'Ownership'; Severity = 'Low'
                Status = 'Failed'; Summary = '38 of 486 Microsoft 365 groups have exactly one owner (5 with a disabled owner).'; Evaluated = 486; Findings = $singleOwner
                Description = 'Single-owner groups.'; Rationale = 'Single point of failure.'; Steps = '1. Add a second owner.'
                PortalUrl = $m365Portal; References = @(, $refExpiry)
                Scopes = @('Group.Read.All'); DataSets = @('Groups'); Tags = 'Groups', 'Ownership'
            }))
    $records.Add((& $record @{
                Id = 'ARG.GRP.003'; Title = 'Group expiration policy configured'; Area = 'GroupsTeams'; Category = 'Lifecycle'; Severity = 'Medium'
                Status = 'Failed'; Summary = 'No Microsoft 365 group expiration policy is configured.'
                Description = 'Expiration policy.'; Rationale = 'Unused groups accumulate.'; Steps = '1. Configure expiration.'
                PortalUrl = $entraPortal; References = @(, $refExpiry)
                Scopes = @('Directory.Read.All'); DataSets = @('GroupLifecyclePolicies'); Tags = 'Groups', 'Lifecycle'
            }))
    $records.Add((& $record @{
                Id = 'ARG.GRP.001'; Title = 'Microsoft 365 group creation is restricted'; Area = 'GroupsTeams'; Category = 'Group governance'; Severity = 'Medium'
                Status = 'Investigate'; Summary = 'All users can create Microsoft 365 groups and Teams (the Group.Unified setting is not configured, so the default applies). Confirm this is intended and that ownership and expiration are governed.'
                Description = 'Group creation.'; Rationale = 'Sprawl.'; Steps = '1. Decide on a creation policy.'
                PortalUrl = $entraPortal; References = @(, $refCreation)
                Scopes = @('GroupSettings.Read.All'); DataSets = @('GroupSettings'); Tags = 'Groups', 'Policy'
            }))
    $records.Add((& $record @{
                Id = 'ARG.GRP.002'; Title = 'Group naming policy configured'; Area = 'GroupsTeams'; Category = 'Group governance'; Severity = 'Low'
                Status = 'Skipped'; SkipReason = $p1Skip
                Description = 'Naming policy.'; Rationale = 'Consistent names.'; Steps = '1. Configure a naming policy.'
                PortalUrl = $entraPortal; References = @(, $refNaming)
                Scopes = @('GroupSettings.Read.All'); Licenses = 'AAD_PREMIUM'; DataSets = @('GroupSettings'); Tags = 'Groups', 'Policy'
            }))
    $records.Add((& $record @{
                Id = 'ARG.GRP.008'; Title = 'Inactive Teams (more than 180 days)'; Area = 'GroupsTeams'; Category = 'Lifecycle'; Severity = 'Low'
                Status = 'Investigate'; Summary = 'Usage reports return concealed names (admin/reportSettings.displayConcealedNames = true), so inactive Teams cannot be identified. Turn the setting off in the Microsoft 365 admin center (Settings > Org settings > Reports) to evaluate this check.'
                Description = 'Inactive Teams.'; Rationale = 'Uncurated content.'; Steps = '1. Archive or delete.'
                PortalUrl = $m365Portal; References = @(, $refReports)
                Scopes = @('Reports.Read.All'); DataSets = 'TeamsActivity', 'ReportSettings'; Tags = 'Teams', 'Lifecycle', 'Reports'
            }))
    $records.Add((& $record @{
                Id = 'ARG.GRP.006'; Title = 'Teams with guests and no owner'; Area = 'GroupsTeams'; Category = 'Ownership'; Severity = 'High'
                Status = 'Failed'; Summary = '2 of 312 Teams have guest members and no owner.'; Evaluated = 312
                Findings = @(
                    [pscustomobject][ordered]@{ DisplayName = 'Vendor Onboarding <x>'; Guests = 4; Members = 19; GuestUsers = @('ana_fabrikam.example#EXT#@contoso.onmicrosoft.com', 'li_tailspin.example#EXT#@contoso.onmicrosoft.com', 'joe_wingtip.example#EXT#@contoso.onmicrosoft.com', 'eva_adatum.example#EXT#@contoso.onmicrosoft.com'); Visibility = 'Private'; GroupId = $ownerless[2].GroupId }
                    [pscustomobject][ordered]@{ DisplayName = 'Project Atlas'; Guests = 1; Members = 8; GuestUsers = @('pm_northwind.example#EXT#@contoso.onmicrosoft.com'); Visibility = 'Private'; GroupId = $ownerless[0].GroupId }
                )
                Description = 'Ownerless Teams with guests.'; Rationale = 'Guests not reviewed.'; Steps = '1. Assign owners.'
                PortalUrl = $m365Portal; References = @(, $refB2B)
                Scopes = 'Group.Read.All', 'GroupMember.Read.All'; DataSets = 'Groups'; Tags = 'Teams', 'Guests', 'Ownership'
            }))

    # ------------------------------------------------------------------ SharePoint
    $records.Add((& $record @{
                Id = 'ARG.SPO.008'; Title = 'Orphaned SharePoint sites'; Area = 'SharePoint'; Category = 'Ownership'; Severity = 'High'
                Status = 'Failed'; Summary = '3 of 486 sites have no responsible owner. Sites without a Microsoft 365 group were not evaluated (connect SharePoint with PnP.PowerShell to include them).'; Evaluated = 486
                Findings = @(
                    [pscustomobject][ordered]@{ SiteUrl = 'https://contoso.sharepoint.com/sites/OldNewsletter'; Title = 'Old Newsletter'; Type = 'Group-connected team site'; Reason = 'Microsoft 365 group has no owner'; Owner = ''; GroupId = $ownerless[3].GroupId }
                    [pscustomobject][ordered]@{ SiteUrl = 'https://contoso.sharepoint.com/sites/ProjectAtlas'; Title = 'Project Atlas'; Type = 'Team site (Teams)'; Reason = 'Microsoft 365 group has no owner'; Owner = ''; GroupId = $ownerless[0].GroupId }
                    [pscustomobject][ordered]@{ SiteUrl = 'https://contoso.sharepoint.com/sites/VendorOnboarding'; Title = 'Vendor Onboarding <x>'; Type = 'Team site (Teams)'; Reason = 'Microsoft 365 group has no owner'; Owner = ''; GroupId = $ownerless[2].GroupId }
                )
                Description = 'Orphaned sites.'; Rationale = 'Nobody manages them.'; Steps = '1. Assign owners.'
                PortalUrl = $spoPortal; References = @(, $refSharing)
                Scopes = 'Group.Read.All', 'Sites.Read.All'; DataSets = 'Groups'; Tags = 'SharePoint', 'Ownership'
            }))
    $records.Add((& $record @{
                Id = 'ARG.SPO.009'; Title = 'Inactive SharePoint sites (more than 180 days)'; Area = 'SharePoint'; Category = 'Lifecycle'; Severity = 'Low'
                Status = 'Investigate'; Summary = 'Usage reports return concealed names (admin/reportSettings.displayConcealedNames = true), so inactive sites cannot be identified. Turn the setting off in the Microsoft 365 admin center (Settings > Org settings > Reports) to evaluate this check.'
                Description = 'Inactive sites.'; Rationale = 'Uncurated content.'; Steps = '1. Archive or delete.'
                PortalUrl = $spoPortal; References = @(, $refReports)
                Scopes = @('Reports.Read.All'); DataSets = 'SharePointSiteUsage', 'ReportSettings'; Tags = 'SharePoint', 'Lifecycle', 'Reports'
            }))
    $records.Add((& $record @{
                Id = 'ARG.SPO.002'; Title = 'Tenant external sharing level'; Area = 'SharePoint'; Category = 'Sharing'; Severity = 'Medium'
                Status = 'Investigate'; Summary = 'External sharing allows Anyone links at organisation level (Anyone (links without sign-in)). Confirm this is intended and which sites need it.'
                Findings = @([pscustomobject][ordered]@{ SharingCapability = 'externalUserAndGuestSharing'; Level = 'Anyone (links without sign-in)'; DomainRestriction = 'none'; GuestsCanReshare = $true; GuestMustMatchInvitedAccount = $false })
                Description = 'Sharing level.'; Rationale = 'Anyone links.'; Steps = '1. Decide the sharing level.'
                PortalUrl = $spoPortal; References = @(, $refSharing)
                Scopes = @('SharePointTenantSettings.Read.All'); DataSets = @('SharePointTenantSettings'); Tags = 'SharePoint', 'Sharing'
            }))
    $records.Add((& $record @{
                Id = 'ARG.SPO.010'; Title = 'Sites near their storage quota (more than 90%)'; Area = 'SharePoint'; Category = 'Storage'; Severity = 'Low'
                Status = 'Investigate'; Summary = 'Usage reports return concealed names (admin/reportSettings.displayConcealedNames = true), so sites near their quota cannot be identified. Turn the setting off in the Microsoft 365 admin center (Settings > Org settings > Reports) to evaluate this check.'
                Description = 'Quota.'; Rationale = 'Read-only sites.'; Steps = '1. Clean up or increase quota.'
                PortalUrl = $spoPortal; References = @(, $refReports)
                Scopes = @('Reports.Read.All'); DataSets = 'SharePointSiteUsage', 'ReportSettings'; Tags = 'SharePoint', 'Storage', 'Reports'
            }))
    $records.Add((& $record @{
                Id = 'ARG.SPO.012'; Title = 'OneDrive of deleted or disabled users with content'; Area = 'SharePoint'; Category = 'Lifecycle'; Severity = 'Low'
                Status = 'NotRun'; SkipReason = 'Excluded with -ExcludeId.'
                Description = 'Leaver OneDrives.'; Rationale = 'Unowned files.'; Steps = '1. Transfer content.'
                PortalUrl = $spoPortal; References = @(, $refReports)
                Scopes = 'Reports.Read.All', 'User.Read.All'; DataSets = 'OneDriveUsage', 'ReportSettings', 'Users'; Tags = 'OneDrive', 'Lifecycle', 'Reports'
            }))

    $records.Add((& $record @{
                Id = 'ARG.SPO.001'; Area = 'SharePoint'; Status = 'Investigate'; Evaluated = 1
                Summary = 'Users can create SharePoint sites (isSiteCreationEnabled = true). Confirm this is intended and governed.'
                Findings = @([pscustomobject][ordered]@{ Setting = 'isSiteCreationEnabled'; Value = 'True'; CreateCommandsShown = $true; DefaultManagedPath = 'sites' })
            }))
    $records.Add((& $record @{
                Id = 'ARG.SPO.011'; Area = 'SharePoint'; Status = 'Failed'; Evaluated = 1
                Summary = 'The OneDrive of a deleted user is kept for 30 days, less than 90.'
                Findings = @([pscustomobject][ordered]@{ Setting = 'deletedUserPersonalSiteRetentionPeriodInDays'; Days = 30; MinimumDays = 90 })
            }))
    foreach ($id in 'ARG.SPO.005', 'ARG.SPO.004', 'ARG.SPO.003', 'ARG.SPO.006') {
        $records.Add((& $record @{ Id = $id; Area = 'SharePoint'; Status = 'Skipped'; SkipReason = 'Not connected to SharePoint Online (PnP.PowerShell).' }))
    }
    $records.Add((& $record @{
                Id = 'ARG.SPO.013'; Area = 'SharePoint'; Status = 'Investigate'
                Summary = 'Usage reports return concealed names (admin/reportSettings.displayConcealedNames = true), so OneDrives near their quota cannot be identified. Turn the setting off in the Microsoft 365 admin center (Settings > Org settings > Reports) to evaluate this check.'
            }))

    # ------------------------------------------------------------------ Exchange
    $records.Add((& $record @{
                Id = 'ARG.EXO.001'; Title = 'Shared mailboxes with sign-in enabled'; Area = 'Exchange'; Category = 'Mailbox governance'; Severity = 'Medium'
                Status = 'Failed'; Summary = '3 of 41 shared mailboxes have sign-in enabled.'; Evaluated = 41
                Findings = @(
                    [pscustomobject][ordered]@{ DisplayName = '=cmd|'' /C calc''!A0'; PrimarySmtpAddress = "events@$domain"; UserPrincipalName = "events@$domain"; Licensed = 'No'; ObjectId = (& $newId) }
                    [pscustomobject][ordered]@{ DisplayName = 'Reception'; PrimarySmtpAddress = "reception@$domain"; UserPrincipalName = "reception@$domain"; Licensed = 'Yes'; ObjectId = (& $newId) }
                    [pscustomobject][ordered]@{ DisplayName = 'Support Desk'; PrimarySmtpAddress = "support@$domain"; UserPrincipalName = "support@$domain"; Licensed = 'No'; ObjectId = (& $newId) }
                )
                Description = 'Shared mailbox sign-in.'; Rationale = 'Direct sign-in.'; Steps = '1. Block sign-in.'
                PortalUrl = $exoPortal; References = @(, $refShared)
                Services = 'Graph', 'Exchange'; Scopes = @('User.Read.All'); DataSets = 'Users', 'Mailboxes'; Tags = 'Exchange', 'Mailboxes'
            }))
    $records.Add((& $record @{
                Id = 'ARG.EXO.009'; Title = 'Distribution groups without owner'; Area = 'Exchange'; Category = 'Ownership'; Severity = 'Low'
                Status = 'Failed'; Summary = '7 of 96 distribution and mail-enabled security groups have no owner.'; Evaluated = 96
                Findings = @(1..7 | ForEach-Object {
                        [pscustomobject][ordered]@{
                            DisplayName = 'DL-' + (& $pick @('Newsletter', 'Alerts', 'Suppliers', 'Partners', 'Branch')) + "-$_"; PrimarySmtpAddress = "dl$_@$domain"
                            Type = if ($_ -eq 7) { 'MailUniversalSecurityGroup' } else { 'MailUniversalDistributionGroup' }; GroupId = (& $newId)
                        }
                    })
                Description = 'Distribution groups without owner.'; Rationale = 'Unmanaged lists.'; Steps = '1. Set owners.'
                PortalUrl = $exoPortal; References = @(, $refShared)
                Services = 'Graph', 'Exchange'; DataSets = @('DistributionGroups'); Tags = 'Exchange', 'Groups', 'Ownership'
            }))
    $records.Add((& $record @{
                Id = 'ARG.EXO.004'; Title = 'Inactive user mailboxes (more than 90 days)'; Area = 'Exchange'; Category = 'Lifecycle'; Severity = 'Low'
                Status = 'NotRun'; SkipReason = 'Disabled in configuration.'
                Description = 'Inactive mailboxes.'; Rationale = 'Leavers.'; Steps = '1. Convert or remove.'
                PortalUrl = $exoPortal; References = @(, $refReports)
                Scopes = @('Reports.Read.All'); DataSets = 'MailboxUsage', 'ReportSettings'; Tags = 'Exchange', 'Lifecycle', 'Reports'
            }))

    $records.Add((& $record @{
                Id = 'ARG.EXO.006'; Area = 'Exchange'; Status = 'Investigate'
                Summary = 'Usage reports return concealed names (admin/reportSettings.displayConcealedNames = true), so mailboxes near their quota cannot be identified. Turn the setting off in the Microsoft 365 admin center (Settings > Org settings > Reports) to evaluate this check.'
            }))
    $records.Add((& $record @{
                Id = 'ARG.EXO.005'; Area = 'Exchange'; Status = 'Failed'; Evaluated = 1158
                Summary = '2 of 1,158 user mailboxes belong to disabled accounts and are not on hold. 4 more on hold are kept on purpose.'
                Findings = @(1..2 | ForEach-Object {
                        $p = & $person
                        [pscustomobject][ordered]@{ DisplayName = $p.DisplayName; UserPrincipalName = $p.UserPrincipalName; PrimarySmtpAddress = $p.UserPrincipalName; Licensed = if ($_ -eq 1) { 'Yes' } else { 'No' }; ArchiveStatus = 'None'; ObjectId = (& $newId) }
                    })
            }))
    $records.Add((& $record @{
                Id = 'ARG.EXO.002'; Area = 'Exchange'; Status = 'Failed'; Evaluated = 41
                Summary = '2 of 41 shared mailboxes have no FullAccess delegate.'
                Findings = @(
                    [pscustomobject][ordered]@{ DisplayName = 'Expo 2024'; PrimarySmtpAddress = "expo2024@$domain"; UserPrincipalName = "expo2024@$domain"; ObjectId = (& $newId) }
                    [pscustomobject][ordered]@{ DisplayName = 'Old Helpdesk'; PrimarySmtpAddress = "oldhelpdesk@$domain"; UserPrincipalName = "oldhelpdesk@$domain"; ObjectId = (& $newId) }
                )
            }))
    $records.Add((& $record @{
                Id = 'ARG.EXO.010'; Area = 'Exchange'; Status = 'Failed'; Evaluated = 96
                Summary = '3 of 96 distribution and mail-enabled security groups have no members.'
                Findings = @('Launch-2023', 'Branch-Turin', 'Supplier-Alerts' | ForEach-Object {
                        [pscustomobject][ordered]@{ DisplayName = "DL-$_"; PrimarySmtpAddress = ("dl-$_@$domain").ToLowerInvariant(); Type = 'MailUniversalDistributionGroup'; ManagedBy = ''; GroupId = (& $newId) }
                    })
            }))
    $records.Add((& $record @{
                Id = 'ARG.EXO.003'; Area = 'Exchange'; Status = 'Investigate'
                Summary = 'Usage reports return concealed names (admin/reportSettings.displayConcealedNames = true), so inactive shared mailboxes cannot be identified. Turn the setting off in the Microsoft 365 admin center (Settings > Org settings > Reports) to evaluate this check.'
            }))

    # ------------------------------------------------------------------ Copilot
    $records.Add((& $record @{
                Id = 'ARG.COP.001'; Area = 'Copilot'; Status = 'Failed'; Evaluated = 3
                Summary = '2 of 3 Copilot products allow self-service purchases or trials.'
                Findings = @(
                    [pscustomobject][ordered]@{ ProductName = 'Microsoft Copilot'; ProductId = 'CFQ7TTC0MM8R'; PolicyValue = 'Enabled'; Allows = 'Purchases and trials' }
                    [pscustomobject][ordered]@{ ProductName = 'Copilot Studio (fictitious)'; ProductId = 'CFQ7TTC0XXXX'; PolicyValue = 'OnlyTrialsWithoutPaymentMethod'; Allows = 'Trials without payment method' }
                )
            }))
    $records.Add((& $record @{
                Id = 'ARG.COP.002'; Area = 'Copilot'; Status = 'Failed'; Evaluated = 1
                Summary = 'Users can sign up for self-service trials such as Copilot Studio (allowedToSignUpEmailBasedSubscriptions = true).'
                Findings = @([pscustomobject][ordered]@{ Setting = 'allowedToSignUpEmailBasedSubscriptions'; Value = 'True'; Related = 'allowEmailVerifiedUsersToJoinOrganization = False' })
            }))
    $records.Add((& $record @{
                Id = 'ARG.COP.004'; Area = 'Copilot'; Status = 'Investigate'; Evaluated = 2
                Summary = 'Verify in the admin center whether Anthropic models are enabled; no API exposes this setting. Default for this tenant: Off (No users) - tenant country IT is in the EU, EFTA or UK.'
                Findings = @(
                    [pscustomobject][ordered]@{ Setting = 'AI providers operating as Microsoft subprocessors > Anthropic'; Location = 'Microsoft 365 admin center > Copilot > Settings > View all'; Default = 'Off (No users) - tenant country IT is in the EU, EFTA or UK'; Recommended = 'Enabled only after a documented decision, for approved users or groups' }
                    [pscustomobject][ordered]@{ Setting = 'Copilot in Microsoft 365 apps with Anthropic models'; Location = 'Microsoft 365 admin center > Copilot > Settings > View all'; Default = 'Separate setting for Word, Excel and PowerPoint'; Recommended = 'Aligned with the subprocessor decision above' }
                )
            }))
    $records.Add((& $record @{
                Id = 'ARG.COP.005'; Area = 'Copilot'; Status = 'Investigate'; Evaluated = 1
                Summary = 'Verify in the admin center that Anthropic models with Data Retention (Anthropic as independent processor) are not enabled, or only for approved groups; no API exposes this setting.'
                Findings = @([pscustomobject][ordered]@{ Setting = 'Anthropic models with Data Retention'; Location = 'Microsoft 365 admin center > Copilot > Settings > View all'; Default = 'Off for all users, in every region'; Recommended = 'Off, unless Anthropic''s Commercial Terms and DPA were approved; then only for approved groups' })
            }))
    $records.Add((& $record @{
                Id = 'ARG.COP.008'; Area = 'Copilot'; Status = 'Investigate'; Evaluated = 3
                Summary = 'Verify who can use, install and build agents; no API exposes these settings.'
                Findings = @(
                    [pscustomobject][ordered]@{ Setting = 'User access'; Location = 'Microsoft 365 admin center > Agents > Settings'; Default = 'All users'; Recommended = 'Specific users or groups, unless agents are open to everybody by decision' }
                    [pscustomobject][ordered]@{ Setting = 'Agent and plugin access'; Location = 'Microsoft 365 admin center > Agents > Settings'; Default = 'Check the current selection'; Recommended = 'Only the publisher types the organisation supports' }
                    [pscustomobject][ordered]@{ Setting = 'Copilot Studio makers'; Location = 'Power Platform admin center > Environments'; Default = 'Every licensed user can build agents in the default environment'; Recommended = 'A maker security group per environment; environment creation for admins only' }
                )
            }))
    $records.Add((& $record @{
                Id = 'ARG.COP.009'; Area = 'Copilot'; Status = 'Failed'
                Summary = 'All users can register agent identity blueprints (allowedToCreateAgentIdentityBlueprints = true).'
            }))
    $records.Add((& $record @{
                Id = 'ARG.COP.010'; Area = 'Copilot'; Status = 'Investigate'; Evaluated = 1
                Summary = 'Verify who can share agents with the whole organisation; no API exposes this setting.'
                Findings = @([pscustomobject][ordered]@{ Setting = 'Sharing (agents built with Copilot Agent Builder)'; Location = 'Microsoft 365 admin center > Agents > Settings > Sharing'; Default = 'All users'; Recommended = 'No users, or Specific users (approved publishers)' })
            }))
    $records.Add((& $record @{
                Id = 'ARG.COP.006'; Area = 'Copilot'; Status = 'Investigate'; Evaluated = 1
                Summary = 'Allow web search in Copilot is not configured: web search is available to users and its queries are outside the DPA and the EU Data Boundary.'
                Findings = @([pscustomobject][ordered]@{ Setting = 'Allow web search in Copilot'; Value = 'Not configured'; PolicyId = 'No tenant-level policy' })
            }))
    $records.Add((& $record @{
                Id = 'ARG.COP.007'; Area = 'Copilot'; Status = 'Passed'; Evaluated = 1; Affected = 0
                Summary = 'Enhanced personalization is on, except for the members of group 3f1c9a2e-0000-4000-8000-0000000000aa.'
            }))
    $records.Add((& $record @{
                Id = 'ARG.COP.003'; Area = 'Copilot'; Status = 'Investigate'
                Summary = 'Usage reports return concealed names (admin/reportSettings.displayConcealedNames = true), so Copilot users cannot be identified. Turn the setting off in the Microsoft 365 admin center (Settings > Org settings > Reports) to evaluate this check.'
            }))
    foreach ($id in 'ARG.COP.011', 'ARG.COP.012') {
        $records.Add((& $record @{ Id = $id; Area = 'Copilot'; Status = 'Skipped'; SkipReason = 'Agent 365 licence (AGENT_365) not detected.' }))
    }

    # ------------------------------------------------------------------ Checks added with the renumbering (2026-10-20)
    $records.Add((& $record @{
                Id = 'ARG.ENT.002'; Area = 'EntraID'; Status = 'Failed'; Evaluated = 1158
                Summary = '14 of 1,158 licensed users have no manager or no department.'
                Findings = @(1..14 | ForEach-Object {
                        $p = & $person
                        $missing = @('Manager', 'Department', 'Manager, Department')[$_ % 3]
                        [pscustomobject][ordered]@{ DisplayName = $p.DisplayName; UserPrincipalName = $p.UserPrincipalName; Missing = $missing
                            Manager = if ($missing -like '*Manager*') { '' } else { (& $person).DisplayName }
                            Department = if ($missing -like '*Department*') { '' } else { & $pick @('Finance', 'Sales', 'Operations', 'Legal') }
                            ObjectId = (& $newId) }
                    })
            }))
    $records.Add((& $record @{
                Id = 'ARG.ENT.006'; Area = 'EntraID'; Status = 'Failed'; Evaluated = 214
                Summary = '23 of 214 enabled guests have no sponsor.'
                Findings = @(1..23 | ForEach-Object {
                        $guestDomain = & $pick @('fabrikam.example', 'tailspin.example', 'wingtip.example', 'adatum.example')
                        $name = (& $pick $first).ToLowerInvariant() + $_
                        [pscustomobject][ordered]@{ DisplayName = "$name ($guestDomain)"; UserPrincipalName = "${name}_$($guestDomain)#EXT#@$domain"; Mail = "$name@$guestDomain"
                            Created = (& $daysAgo 200 1500).ToString('yyyy-MM-dd'); ObjectId = (& $newId) }
                    })
            }))
    $records.Add((& $record @{
                Id = 'ARG.LIC.003'; Area = 'Licensing'; Status = 'Failed'; Evaluated = 214
                Summary = '3 of 214 guest users have a paid licence.'
                Findings = @(
                    [pscustomobject][ordered]@{ DisplayName = 'Consultant (fabrikam.example)'; UserPrincipalName = "consultant_fabrikam.example#EXT#@$domain"; Licences = @('Microsoft 365 E3'); AccountEnabled = $true; ObjectId = (& $newId) }
                    [pscustomobject][ordered]@{ DisplayName = 'Auditor (adatum.example)'; UserPrincipalName = "auditor_adatum.example#EXT#@$domain"; Licences = @('Microsoft 365 E3', 'Power BI Pro'); AccountEnabled = $true; ObjectId = (& $newId) }
                    [pscustomobject][ordered]@{ DisplayName = 'Former vendor (wingtip.example)'; UserPrincipalName = "vendor_wingtip.example#EXT#@$domain"; Licences = @('Microsoft 365 E3'); AccountEnabled = $false; ObjectId = (& $newId) }
                )
            }))
    $records.Add((& $record @{
                Id = 'ARG.LIC.004'; Area = 'Licensing'; Status = 'Failed'; Evaluated = 87; Affected = 6
                Summary = '6 of 87 users with two or more paid SKUs have a licence fully included in another (6 redundant assignments).'
                Findings = @(1..6 | ForEach-Object {
                        $p = & $person
                        [pscustomobject][ordered]@{ DisplayName = $p.DisplayName; UserPrincipalName = $p.UserPrincipalName
                            RedundantLicence = & $pick @('Exchange Online (Plan 1)', 'Office 365 E1'); IncludedIn = 'Microsoft 365 E3'; ObjectId = (& $newId) }
                    })
            }))
    $records.Add((& $record @{ Id = 'ARG.SPO.007'; Area = 'SharePoint'; Status = 'Skipped'; SkipReason = 'Not connected to SharePoint Online (PnP.PowerShell).' }))
    $records.Add((& $record @{
                Id = 'ARG.EXO.007'; Area = 'Exchange'; Status = 'Investigate'; Evaluated = 1199
                Summary = '4 of 1,199 mailboxes forward mail (2 to external addresses); review each one.'
                Findings = @(
                    [pscustomobject][ordered]@{ DisplayName = 'Former employee'; PrimarySmtpAddress = "former.employee@$domain"; MailboxType = 'UserMailbox'; ForwardsTo = 'former.employee@mail.example'; Target = 'External'; KeepsCopy = $true; ObjectId = (& $newId) }
                    [pscustomobject][ordered]@{ DisplayName = 'Events <b>2024</b>'; PrimarySmtpAddress = "events2024@$domain"; MailboxType = 'SharedMailbox'; ForwardsTo = 'bookings@agency.example'; Target = 'External'; KeepsCopy = $false; ObjectId = (& $newId) }
                    [pscustomobject][ordered]@{ DisplayName = 'Sales Italy'; PrimarySmtpAddress = "sales.it@$domain"; MailboxType = 'SharedMailbox'; ForwardsTo = "sales@$domain"; Target = 'Internal'; KeepsCopy = $true; ObjectId = (& $newId) }
                    [pscustomobject][ordered]@{ DisplayName = 'Reception'; PrimarySmtpAddress = "reception@$domain"; MailboxType = 'SharedMailbox'; ForwardsTo = 'Facility Contact'; Target = 'Directory recipient'; KeepsCopy = $true; ObjectId = (& $newId) }
                )
            }))
    $records.Add((& $record @{
                Id = 'ARG.EXO.008'; Area = 'Exchange'; Status = 'Investigate'; Evaluated = 1158; Affected = 1137
                Summary = '21 of 1,158 user mailboxes have a mailbox hold; 1,137 have none. Confirm in Microsoft Purview that a retention policy covers them.'
                Findings = @(1..40 | ForEach-Object {
                        $p = & $person
                        [pscustomobject][ordered]@{ DisplayName = $p.DisplayName; UserPrincipalName = $p.UserPrincipalName; PrimarySmtpAddress = $p.UserPrincipalName; ArchiveStatus = & $pick @('None', 'Active'); ObjectId = (& $newId) }
                    })
            }))

    # Checks already implemented in the module: use their real metadata (title, texts, remediation,
    # references, requirements, parameters) so the sample shows what users will see. Results stay fictitious.
    foreach ($r in $records) {
        $definition = @($script:ArgusBuiltInChecks | Where-Object Id -EQ $r.Id) | Select-Object -First 1
        if (-not $definition) { continue }
        $r.Title = $definition.Title
        $r.Category = $definition.Category
        $r.Severity = $definition.Severity
        $r.Description = $definition.Description
        $r.Rationale = $definition.Rationale
        $r.Remediation = $definition.Remediation
        $r.References = @($definition.References)
        $r.Requires = $definition.Requires
        $r.Tags = [string[]]@($definition.Tags)
        $r.UsesBeta = $definition.UsesBeta
        $r.Parameters = $definition.Parameters.Clone()
    }

    # Resolve {Parameter} placeholders in titles/descriptions the way the runner does.
    foreach ($r in $records) {
        $r.Title = Resolve-ArgusTemplate -Template $r.Title -Values $r.Parameters
        $r.Description = Resolve-ArgusTemplate -Template $r.Description -Values $r.Parameters
    }

    $config = Get-ArgusConfig
    $config.Report.CompanyName = 'Fabrikam IT Services (fictitious MSP)'
    $config.Exclusions.UserPrincipalNames = @("breakglass02@$domain")

    $environment = [pscustomobject]@{
        ConnectedServices    = [string[]]@('Graph', 'Exchange', 'Commerce')
        GrantedScopes        = [string[]]@('User.Read.All', 'Group.Read.All', 'GroupMember.Read.All', 'Directory.Read.All', 'AuditLog.Read.All', 'Application.Read.All',
            'RoleManagement.Read.Directory', 'Organization.Read.All', 'Policy.Read.All', 'Device.Read.All', 'Reports.Read.All', 'ReportSettings.Read.All',
            'Sites.Read.All', 'SharePointTenantSettings.Read.All')
        Licenses             = [string[]]@('M365_COPILOT_APPS')
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
        -StartedAt $started -FinishedAt $started.AddSeconds(192.4) -Filter @{ ExcludeId = @('ARG.SPO.012') } -ConfigPath 'contoso.config.json'
    $document.Run.TimeZone = 'W. Europe Standard Time'

    $file = Export-ArgusResultJson -Document $document -Path $OutputPath
    Write-Information "Sample results written to $($file.FullName) (score $($score.Score) $($score.Grade), coverage $($score.Coverage)%)." -InformationAction Continue
} $OutputPath
