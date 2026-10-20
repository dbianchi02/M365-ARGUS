function Get-ArgusDataSetDefinition {
    <#
    .SYNOPSIS
        Catalogue of the shared tenant data sets: endpoint, permissions, roles, licence and loader.

    .DESCRIPTION
        Each data set is fetched once per run through Get-ArgusData and shared by every check that
        declares it in Requires.DataSets. Permissions here are added to a check's own GraphScopes by
        Get-ArgusRequiredPermission. Endpoints, permissions and roles were verified on Microsoft Learn
        (2026-10-19); see docs/ARGUS-SPEC.md section 7.

        Roles lists the least-privileged built-in Entra roles that can read the data with delegated
        (interactive) access. Loaders only issue GET requests (or Get-* Exchange cmdlets).
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter()]
        [string[]] $Name
    )

    $definitions = @(
        @{
            Name        = 'Users'
            Service     = 'Graph'
            Endpoint    = 'GET /users ($select incl. signInActivity when Entra ID P1 is available)'
            Permissions = @('User.Read.All', 'AuditLog.Read.All')
            Roles       = @('Global Reader')
            License     = 'AAD_PREMIUM (signInActivity only)'
            Notes       = 'signInActivity needs Entra ID P1 and AuditLog.Read.All; page size is 500 when it is selected. Without them users are loaded without sign-in data (noted).'
            Loader      = {
                $select = 'id,userPrincipalName,displayName,mail,userType,accountEnabled,createdDateTime,externalUserState,externalUserStateChangeDateTime,assignedLicenses,licenseAssignmentStates,onPremisesSyncEnabled'
                $environment = Get-ArgusEnvironment
                $scopeOk = ($null -eq $environment.GrantedScopes) -or ('AuditLog.Read.All' -in $environment.GrantedScopes)
                if ((Test-ArgusLicenseAvailable -Plan 'AAD_PREMIUM') -and $scopeOk) {
                    try {
                        $users = @(Invoke-ArgusGraphRequest -Uri "/users?`$select=$select,signInActivity&`$top=500" -All)
                        Add-ArgusDataSetNote -Name 'Users' -Text 'signInActivity included.'
                        return Write-Output -InputObject $users -NoEnumerate
                    }
                    catch {
                        if (-not ((Get-ArgusGraphError -ErrorRecord $_).StatusCode -in 400, 403)) { throw }
                        Add-ArgusDataSetNote -Name 'Users' -Text "signInActivity not available ($((Get-ArgusGraphError -ErrorRecord $_).StatusCode)); users loaded without sign-in data."
                    }
                }
                else {
                    Add-ArgusDataSetNote -Name 'Users' -Text 'signInActivity not requested (Entra ID P1 or AuditLog.Read.All missing).'
                }
                Write-Output -InputObject @(Invoke-ArgusGraphRequest -Uri "/users?`$select=$select&`$top=999" -All) -NoEnumerate
            }
        }
        @{
            Name        = 'Groups'
            Service     = 'Graph'
            Endpoint    = 'GET /groups?$expand=owners($select=...)'
            Permissions = @('Group.Read.All')
            Roles       = @('Global Reader', 'Directory Readers')
            Notes       = '$expand returns at most 20 owners per group: OwnerCount is exact for 0-19 and means "20 or more" at 20. Adds IsUnified, IsTeam, IsDynamic.'
            Loader      = {
                $select = 'id,displayName,description,mail,groupTypes,securityEnabled,mailEnabled,visibility,isAssignableToRole,membershipRule,resourceProvisioningOptions,createdDateTime,onPremisesSyncEnabled'
                $groups = @(Invoke-ArgusGraphRequest -Uri "/groups?`$select=$select&`$expand=owners(`$select=id,displayName,userPrincipalName,userType)&`$top=100" -All)
                foreach ($group in $groups) {
                    $owners = @(if ($group.PSObject.Properties['owners']) { $group.owners })
                    $types = @(if ($group.PSObject.Properties['groupTypes']) { $group.groupTypes })
                    $options = @(if ($group.PSObject.Properties['resourceProvisioningOptions']) { $group.resourceProvisioningOptions })
                    $group | Add-Member -NotePropertyName OwnerCount -NotePropertyValue $owners.Count -Force
                    $group | Add-Member -NotePropertyName IsUnified -NotePropertyValue ('Unified' -in $types) -Force
                    $group | Add-Member -NotePropertyName IsDynamic -NotePropertyValue ('DynamicMembership' -in $types) -Force
                    $group | Add-Member -NotePropertyName IsTeam -NotePropertyValue ('Team' -in $options) -Force
                }
                Write-Output -InputObject $groups -NoEnumerate
            }
        }
        @{
            Name        = 'DirectoryRoles'
            Service     = 'Graph'
            Endpoint    = 'GET /roleManagement/directory/roleDefinitions, roleAssignments?$expand=principal, roleEligibilitySchedules?$expand=principal'
            Permissions = @('RoleManagement.Read.Directory', 'RoleEligibilitySchedule.Read.Directory')
            Roles       = @('Global Reader')
            License     = 'AAD_PREMIUM_P2 (eligible assignments only)'
            Notes       = 'Eligible (PIM) assignments exist only with Entra ID P2; without it Eligible is $null and EligibleAvailable is $false.'
            Loader      = {
                $roleDefinitions = @(Invoke-ArgusGraphRequest -Uri '/roleManagement/directory/roleDefinitions?$select=id,displayName,templateId,isBuiltIn' -All)
                $assignments = @(Invoke-ArgusGraphRequest -Uri '/roleManagement/directory/roleAssignments?$expand=principal' -All)
                $eligible = $null
                if (Test-ArgusLicenseAvailable -Plan 'AAD_PREMIUM_P2') {
                    try {
                        $eligible = @(Invoke-ArgusGraphRequest -Uri '/roleManagement/directory/roleEligibilitySchedules?$expand=principal' -All)
                    }
                    catch {
                        if (-not ((Get-ArgusGraphError -ErrorRecord $_).StatusCode -in 400, 403)) { throw }
                        Add-ArgusDataSetNote -Name 'DirectoryRoles' -Text "Eligible assignments not available ($((Get-ArgusGraphError -ErrorRecord $_).StatusCode))."
                    }
                }
                else {
                    Add-ArgusDataSetNote -Name 'DirectoryRoles' -Text 'Eligible assignments not evaluated: Entra ID P2 not detected.'
                }
                [pscustomobject]@{
                    Definitions       = $roleDefinitions
                    Assignments       = $assignments
                    Eligible          = $eligible
                    EligibleAvailable = $null -ne $eligible
                }
            }
        }
        @{
            Name        = 'Applications'
            Service     = 'Graph'
            Endpoint    = 'GET /applications?$expand=owners($select=...)'
            Permissions = @('Application.Read.All')
            Roles       = @('Global Reader', 'Application Administrator')
            Notes       = 'Includes passwordCredentials and keyCredentials metadata (never secret values). OwnerCount capped at 20 like Groups.'
            Loader      = {
                $select = 'id,appId,displayName,createdDateTime,signInAudience,publisherDomain,passwordCredentials,keyCredentials'
                $apps = @(Invoke-ArgusGraphRequest -Uri "/applications?`$select=$select&`$expand=owners(`$select=id,displayName,userPrincipalName)&`$top=100" -All)
                foreach ($app in $apps) {
                    $owners = @(if ($app.PSObject.Properties['owners']) { $app.owners })
                    $app | Add-Member -NotePropertyName OwnerCount -NotePropertyValue $owners.Count -Force
                }
                Write-Output -InputObject $apps -NoEnumerate
            }
        }
        @{
            Name        = 'SubscribedSkus'
            Service     = 'Graph'
            Endpoint    = 'GET /subscribedSkus'
            Permissions = @('LicenseAssignment.Read.All')
            Roles       = @('Global Reader', 'Directory Readers')
            Notes       = 'Also used to detect Entra ID P1/P2.'
            Loader      = { Write-Output -InputObject @(Invoke-ArgusGraphRequest -Uri '/subscribedSkus' -All) -NoEnumerate }
        }
        @{
            Name        = 'Subscriptions'
            Service     = 'Graph'
            Endpoint    = 'GET /directory/subscriptions'
            Permissions = @('Organization.Read.All')
            Roles       = @('Global Reader', 'Directory Readers')
            Notes       = 'Commercial subscriptions with isTrial and status, used to tell trial SKUs from paid ones.'
            Loader      = { Write-Output -InputObject @(Invoke-ArgusGraphRequest -Uri '/directory/subscriptions' -All) -NoEnumerate }
        }
        @{
            Name        = 'Organization'
            Service     = 'Graph'
            Endpoint    = 'GET /organization'
            Permissions = @('Organization.Read.All')
            Roles       = @('Global Reader', 'Directory Readers')
            Notes       = 'Tenant name, verified domains, directory sync status.'
            Loader      = {
                @(Invoke-ArgusGraphRequest -Uri '/organization?$select=id,displayName,verifiedDomains,onPremisesSyncEnabled,onPremisesLastSyncDateTime,countryLetterCode,createdDateTime' -All) |
                    Select-Object -First 1
            }
        }
        @{
            Name        = 'AuthorizationPolicy'
            Service     = 'Graph'
            Endpoint    = 'GET /policies/authorizationPolicy'
            Permissions = @('Policy.Read.All')
            Roles       = @('Global Reader')
            Notes       = 'allowInvitesFrom, defaultUserRolePermissions.'
            Loader      = { Invoke-ArgusGraphRequest -Uri '/policies/authorizationPolicy' }
        }
        @{
            Name        = 'AuthorizationPolicyBeta'
            Service     = 'Graph'
            Endpoint    = 'GET /beta/policies/authorizationPolicy'
            Permissions = @('Policy.Read.All')
            Roles       = @('Global Reader')
            Notes       = 'Beta. defaultUserRolePermissions.allowedToCreateAgentIdentityBlueprints is returned only by the beta endpoint and is not yet documented on Learn.'
            Loader      = {
                try { Invoke-ArgusGraphRequest -Uri '/policies/authorizationPolicy' -Beta }
                catch {
                    $status = (Get-ArgusGraphError -ErrorRecord $_).StatusCode
                    if ($status -notin 401, 403) { throw }
                    [pscustomobject]@{ ArgusUnavailable = "The authorization policy could not be read from the beta endpoint ($status): it needs Policy.Read.All." }
                }
            }
        }
        @{
            Name        = 'GroupSettings'
            Service     = 'Graph'
            Endpoint    = 'GET /groupSettings'
            Permissions = @('GroupSettings.Read.All')
            Roles       = @('Global Reader', 'Directory Readers')
            Notes       = 'Tenant-wide Group.Unified settings (EnableGroupCreation, naming policy). Empty when never configured.'
            Loader      = { Write-Output -InputObject @(Invoke-ArgusGraphRequest -Uri '/groupSettings' -All) -NoEnumerate }
        }
        @{
            Name        = 'GroupLifecyclePolicies'
            Service     = 'Graph'
            Endpoint    = 'GET /groupLifecyclePolicies'
            Permissions = @('Directory.Read.All')
            Roles       = @('Global Reader', 'Directory Readers')
            Notes       = 'The least privileged permission documented is Directory.Read.All.'
            Loader      = { Write-Output -InputObject @(Invoke-ArgusGraphRequest -Uri '/groupLifecyclePolicies' -All) -NoEnumerate }
        }
        @{
            Name        = 'Devices'
            Service     = 'Graph'
            Endpoint    = 'GET /devices'
            Permissions = @('Device.Read.All')
            Roles       = @('Global Reader', 'Directory Readers')
            Notes       = 'approximateLastSignInDateTime per device.'
            Loader      = {
                $select = 'id,deviceId,displayName,operatingSystem,operatingSystemVersion,trustType,accountEnabled,approximateLastSignInDateTime,registrationDateTime'
                Write-Output -InputObject @(Invoke-ArgusGraphRequest -Uri "/devices?`$select=$select&`$top=999" -All) -NoEnumerate
            }
        }
        @{
            Name        = 'ReportSettings'
            Service     = 'Graph'
            Endpoint    = 'GET /admin/reportSettings'
            Permissions = @('ReportSettings.Read.All')
            Roles       = @('Reports Reader', 'Global Reader')
            Notes       = 'displayConcealedNames: when true, usage reports return hashed names.'
            Loader      = { Invoke-ArgusGraphRequest -Uri '/admin/reportSettings' }
        }
        @{
            Name        = 'TeamsActivity'
            Service     = 'Graph'
            Endpoint    = "GET /reports/getTeamsTeamActivityDetail(period='D180') (CSV)"
            Permissions = @('Reports.Read.All')
            Roles       = @('Reports Reader')
            Notes       = 'Delegated: Global Reader only sees tenant-level totals, not per-team rows. Names are hashed when concealed names are on.'
            Loader      = { Write-Output -InputObject @(Invoke-ArgusGraphReport -Name 'getTeamsTeamActivityDetail' -Period D180) -NoEnumerate }
        }
        @{
            Name        = 'SharePointSiteUsage'
            Service     = 'Graph'
            Endpoint    = "GET /reports/getSharePointSiteUsageDetail(period='D180') (CSV)"
            Permissions = @('Reports.Read.All')
            Roles       = @('Reports Reader')
            Notes       = 'Delegated: Global Reader only sees tenant-level totals. URLs are hashed when concealed names are on.'
            Loader      = { Write-Output -InputObject @(Invoke-ArgusGraphReport -Name 'getSharePointSiteUsageDetail' -Period D180) -NoEnumerate }
        }
        @{
            Name        = 'OneDriveUsage'
            Service     = 'Graph'
            Endpoint    = "GET /reports/getOneDriveUsageAccountDetail(period='D180') (CSV)"
            Permissions = @('Reports.Read.All')
            Roles       = @('Reports Reader')
            Notes       = 'Delegated: Global Reader only sees tenant-level totals.'
            Loader      = { Write-Output -InputObject @(Invoke-ArgusGraphReport -Name 'getOneDriveUsageAccountDetail' -Period D180) -NoEnumerate }
        }
        @{
            Name        = 'MailboxUsage'
            Service     = 'Graph'
            Endpoint    = "GET /reports/getMailboxUsageDetail(period='D180') (CSV)"
            Permissions = @('Reports.Read.All')
            Roles       = @('Reports Reader')
            Notes       = 'Delegated: Global Reader only sees tenant-level totals.'
            Loader      = { Write-Output -InputObject @(Invoke-ArgusGraphReport -Name 'getMailboxUsageDetail' -Period D180) -NoEnumerate }
        }
        @{
            Name        = 'SharePointTenantSettings'
            Service     = 'Graph'
            Endpoint    = 'GET /admin/sharepoint/settings'
            Permissions = @('SharePointTenantSettings.Read.All')
            Roles       = @('Global Reader', 'SharePoint Administrator')
            Notes       = 'sharingCapability and other tenant-level SharePoint/OneDrive settings.'
            Loader      = { Invoke-ArgusGraphRequest -Uri '/admin/sharepoint/settings' }
        }
        @{
            Name        = 'Mailboxes'
            Service     = 'Exchange'
            Endpoint    = 'Get-EXOMailbox -ResultSize Unlimited'
            Permissions = @()
            Roles       = @('Global Reader', 'View-Only Organization Management')
            Notes       = 'User, shared, room and equipment mailboxes with RecipientTypeDetails, ExternalDirectoryObjectId (Entra object id), archive and hold status, mailbox forwarding (ForwardingSmtpAddress, ForwardingAddress, DeliverToMailboxAndForward).'
            Loader      = {
                $mailboxes = Get-EXOMailbox -ResultSize Unlimited -RecipientTypeDetails UserMailbox, SharedMailbox, RoomMailbox, EquipmentMailbox `
                    -Properties ExternalDirectoryObjectId, RecipientTypeDetails, ArchiveStatus, LitigationHoldEnabled, InPlaceHolds, ForwardingSmtpAddress, ForwardingAddress, DeliverToMailboxAndForward -ErrorAction Stop |
                    Select-Object DisplayName, UserPrincipalName, PrimarySmtpAddress, RecipientTypeDetails, ExternalDirectoryObjectId, ArchiveStatus, LitigationHoldEnabled, InPlaceHolds,
                    ForwardingSmtpAddress, ForwardingAddress, DeliverToMailboxAndForward
                Write-Output -InputObject @($mailboxes) -NoEnumerate
            }
        }
        @{
            Name        = 'SharePointSites'
            Service     = 'SharePoint'
            Endpoint    = 'Get-PnPTenantSite (PnP.PowerShell)'
            Permissions = @()
            Roles       = @('SharePoint Administrator', 'Global Reader')
            Notes       = 'Site collections without OneDrive: Url, Template, Owner (primary site collection administrator), GroupId (empty GUID for sites without a Microsoft 365 group).'
            Loader      = {
                $sites = Get-PnPTenantSite -ErrorAction Stop |
                    Select-Object Url, Title, Template, Owner, GroupId, LastContentModifiedDate, LockState, SharingCapability, SensitivityLabel
                Write-Output -InputObject @($sites) -NoEnumerate
            }
        }
        @{
            Name        = 'SharePointTenant'
            Service     = 'SharePoint'
            Endpoint    = 'Get-PnPTenant (PnP.PowerShell)'
            Permissions = @()
            Roles       = @('SharePoint Administrator', 'Global Reader')
            Notes       = 'Sharing settings not exposed by Graph sharepointSettings: guest expiration, Anyone link expiration and default sharing link (Set-SPOTenant parameters).'
            Loader      = {
                Get-PnPTenant -ErrorAction Stop |
                    Select-Object ExternalUserExpirationRequired, ExternalUserExpireInDays, RequireAnonymousLinksExpireInDays,
                    DefaultSharingLinkType, DefaultLinkPermission, CoreDefaultShareLinkScope, OneDriveDefaultShareLinkScope
            }
        }
        @{
            Name        = 'SharedMailboxPermissions'
            Service     = 'Exchange'
            Endpoint    = 'Get-EXOMailboxPermission (shared mailboxes only)'
            Permissions = @()
            Roles       = @('Global Reader', 'View-Only Organization Management')
            Notes       = 'Explicit (not inherited, not denied) FullAccess trustees per shared mailbox, keyed by ExternalDirectoryObjectId. NT AUTHORITY\SELF is ignored. One call per shared mailbox.'
            Loader      = {
                $result = @{}
                $mailboxes = Get-ArgusData -Name 'Mailboxes'
                foreach ($mailbox in @($mailboxes | Where-Object { $_.RecipientTypeDetails -eq 'SharedMailbox' })) {
                    $identity = if ($mailbox.ExternalDirectoryObjectId) { [string]$mailbox.ExternalDirectoryObjectId } else { [string]$mailbox.UserPrincipalName }
                    $trustees = @(Get-EXOMailboxPermission -Identity $identity -ErrorAction Stop | Where-Object {
                            -not $_.IsInherited -and -not $_.Deny -and [string]$_.User -ne 'NT AUTHORITY\SELF' -and @($_.AccessRights) -match 'FullAccess'
                        } | ForEach-Object { [string]$_.User })
                    $result[$identity] = $trustees
                }
                $result
            }
        }
        @{
            Name        = 'DistributionGroupMembers'
            Service     = 'Exchange'
            Endpoint    = 'GET /groups/{id}/members?$select=id&$top=1 ($batch, one per distribution group)'
            Permissions = @('GroupMember.Read.All')
            Roles       = @('Global Reader', 'Directory Readers')
            Notes       = 'HasMembers per distribution or mail-enabled security group from DistributionGroups, keyed by ExternalDirectoryObjectId. $null when the group could not be read.'
            Loader      = {
                $distributionGroups = Get-ArgusData -Name 'DistributionGroups'
                $groups = @($distributionGroups | Where-Object { $_.ExternalDirectoryObjectId })
                $requests = @($groups | ForEach-Object { @{ Id = [string]$_.ExternalDirectoryObjectId; Url = "/groups/$($_.ExternalDirectoryObjectId)/members?`$select=id&`$top=1" } })
                $result = @{}
                foreach ($response in @(Invoke-ArgusGraphBatch -Request $requests)) {
                    $result[$response.Id] = if ($response.Status -eq 200) { @($response.Body.value).Count -gt 0 } else { $null }
                }
                $result
            }
        }
        @{
            Name        = 'UserManagers'
            Service     = 'Graph'
            Endpoint    = "GET /users?`$filter=userType eq 'Member'&`$select=id,department&`$expand=manager(`$select=id,displayName)"
            Permissions = @('User.Read.All')
            Roles       = @('Global Reader', 'Directory Readers')
            Notes       = 'Department and manager of member users, keyed by user id (one $expand per request: directory objects expand a single relationship).'
            Loader      = {
                $result = @{}
                foreach ($user in @(Invoke-ArgusGraphRequest -Uri "/users?`$filter=userType eq 'Member'&`$select=id,department&`$expand=manager(`$select=id,displayName)&`$top=999" -All)) {
                    $result[[string]$user.id] = [pscustomobject]@{
                        Department = [string](Get-ArgusProperty $user 'department' '')
                        Manager    = [string](Get-ArgusProperty $user 'manager.displayName' (Get-ArgusProperty $user 'manager.id' ''))
                    }
                }
                $result
            }
        }
        @{
            Name        = 'GuestSponsors'
            Service     = 'Graph'
            Endpoint    = "GET /users?`$filter=userType eq 'Guest'&`$select=id&`$expand=sponsors(`$select=id,displayName)"
            Permissions = @('User.Read.All')
            Roles       = @('Directory Readers', 'Guest Inviter')
            Notes       = 'Sponsors (users or groups responsible for the guest) of each guest, keyed by user id. Delegated reads need a role with microsoft.directory/users/sponsors/read (Directory Readers, Guest Inviter, User Administrator).'
            Loader      = {
                try {
                    $result = @{}
                    foreach ($guest in @(Invoke-ArgusGraphRequest -Uri "/users?`$filter=userType eq 'Guest'&`$select=id&`$expand=sponsors(`$select=id,displayName)&`$top=999" -All)) {
                        $result[[string]$guest.id] = @(Get-ArgusProperty $guest 'sponsors' @() | ForEach-Object { [string](Get-ArgusProperty $_ 'displayName' (Get-ArgusProperty $_ 'id' '')) })
                    }
                    $result
                }
                catch {
                    $status = (Get-ArgusGraphError -ErrorRecord $_).StatusCode
                    if ($status -notin 400, 401, 403) { throw }
                    @{ ArgusUnavailable = "Guest sponsors could not be read ($status): the account needs a role that can read sponsors (Directory Readers, Guest Inviter or User Administrator)." }
                }
            }
        }
        @{
            Name        = 'CopilotUsage'
            Service     = 'Graph'
            Endpoint    = "GET /copilot/reports/getMicrosoft365CopilotUsageUserDetail(period='D180') (CSV)"
            Permissions = @('Reports.Read.All')
            Roles       = @('Reports Reader', 'AI Administrator')
            Notes       = 'One row per user with a Microsoft 365 Copilot licence (unlicensed Copilot Chat usage is not included). Names are hashed when concealed names are on.'
            Loader      = { Write-Output -InputObject @(Invoke-ArgusGraphReport -Root 'copilot/reports' -Name 'getMicrosoft365CopilotUsageUserDetail' -Period D180) -NoEnumerate }
        }
        @{
            Name        = 'CopilotWebSearchPolicy'
            Service     = 'Graph'
            Endpoint    = 'GET /beta/copilot/admin/policySettings/microsoft.copilot.allowwebsearch'
            Permissions = @('CopilotPolicySettings.Read')
            Roles       = @('AI Administrator')
            Notes       = 'Beta, delegated only. Tenant-level Cloud Policy value of "Allow web search in Copilot"; value and policyId are null when not configured. A group-scoped policy returns 422 (GroupScoped). The least-privileged reader role is not documented.'
            Loader      = {
                try {
                    # -Raw: the entity has its own 'value' property, which must not be unwrapped as a collection.
                    Invoke-ArgusGraphRequest -Uri '/copilot/admin/policySettings/microsoft.copilot.allowwebsearch' -Beta -Raw
                }
                catch {
                    $status = (Get-ArgusGraphError -ErrorRecord $_).StatusCode
                    if ($status -eq 422) { return [pscustomobject]@{ GroupScoped = $true; value = $null; policyId = $null } }
                    if ($status -notin 401, 403) { throw }
                    [pscustomobject]@{ ArgusUnavailable = "The Copilot policy setting could not be read ($status): it needs CopilotPolicySettings.Read with delegated sign-in and an admin role that can read Copilot settings." }
                }
            }
        }
        @{
            Name        = 'CopilotPersonalization'
            Service     = 'Graph'
            Endpoint    = 'GET /beta/copilot/settings/people/enhancedpersonalization'
            Permissions = @('PeopleSettings.Read.All')
            Roles       = @('Global Administrator')
            Notes       = 'Beta. isEnabledInOrganization and disabledForGroup of the enhanced personalization control (Copilot memory). Learn names Global Administrator; a lower reader role is not documented.'
            Loader      = {
                try {
                    $response = Invoke-ArgusGraphRequest -Uri '/copilot/settings/people/enhancedpersonalization' -Beta -Raw
                    # The documented response wraps the setting in "value"; accept the bare entity too.
                    $value = Get-ArgusProperty $response 'value'
                    if ($null -ne (Get-ArgusProperty $value 'isEnabledInOrganization')) { $value } else { $response }
                }
                catch {
                    $status = (Get-ArgusGraphError -ErrorRecord $_).StatusCode
                    if ($status -notin 401, 403) { throw }
                    [pscustomobject]@{ ArgusUnavailable = "The enhanced personalization setting could not be read ($status): it needs PeopleSettings.Read.All and an admin role." }
                }
            }
        }
        @{
            Name        = 'CopilotPackages'
            Service     = 'Graph'
            Endpoint    = "GET /copilot/admin/catalog/packages and ?`$filter=requestStatus eq 'pending'"
            Permissions = @('CopilotPackages.Read.All')
            Roles       = @('AI Administrator')
            License     = 'AGENT_365'
            Notes       = 'Agents and apps of the tenant catalogue (Package Management API, v1.0). Requires a Microsoft Agent 365 licence. PendingRequests lists packages with an open publish/activate/access/update request.'
            Loader      = {
                try {
                    [pscustomobject]@{
                        Packages        = @(Invoke-ArgusGraphRequest -Uri '/copilot/admin/catalog/packages' -All)
                        PendingRequests = @(Invoke-ArgusGraphRequest -Uri "/copilot/admin/catalog/packages?`$filter=requestStatus eq 'pending'" -All)
                    }
                }
                catch {
                    $status = (Get-ArgusGraphError -ErrorRecord $_).StatusCode
                    if ($status -notin 401, 403) { throw }
                    [pscustomobject]@{ ArgusUnavailable = "The agent catalogue could not be read ($status): it needs CopilotPackages.Read.All, an admin role and a Microsoft Agent 365 licence." }
                }
            }
        }
        @{
            Name        = 'CommercePolicies'
            Service     = 'Commerce'
            Endpoint    = 'Get-MSCommerceProductPolicies -PolicyId AllowSelfServicePurchase (MSCommerce, separate pwsh process at Connect-Argus)'
            Permissions = @()
            Roles       = @('Global Reader')
            Notes       = 'Self-service purchase and trial policy per Microsoft product: Enabled, OnlyTrialsWithoutPaymentMethod or Disabled. Read once by Connect-Argus -Service Commerce in its own process (MSAL version conflict); Windows only.'
            Loader      = {
                if ($null -eq $script:ArgusCommercePolicies) { throw 'MSCommerce policies were not read; run Connect-Argus -Service Commerce.' }
                Write-Output -InputObject @($script:ArgusCommercePolicies) -NoEnumerate
            }
        }
        @{
            Name        = 'DistributionGroups'
            Service     = 'Exchange'
            Endpoint    = 'Get-DistributionGroup -ResultSize Unlimited'
            Permissions = @()
            Roles       = @('Global Reader', 'View-Only Organization Management')
            Notes       = 'Distribution and mail-enabled security groups with ManagedBy.'
            Loader      = {
                $groups = Get-DistributionGroup -ResultSize Unlimited -ErrorAction Stop |
                    Select-Object DisplayName, PrimarySmtpAddress, RecipientTypeDetails, ManagedBy, ExternalDirectoryObjectId
                Write-Output -InputObject @($groups) -NoEnumerate
            }
        }
    )

    foreach ($definition in $definitions) {
        if ($Name -and $definition.Name -notin $Name) { continue }
        [pscustomobject]@{
            PSTypeName  = 'Argus.DataSetDefinition'
            Name        = $definition.Name
            Service     = $definition.Service
            Endpoint    = $definition.Endpoint
            Permissions = [string[]]@($definition.Permissions)
            Roles       = [string[]]@($definition.Roles)
            License     = if ($definition.ContainsKey('License')) { $definition.License } else { $null }
            Notes       = $definition.Notes
            Loader      = $definition.Loader
        }
    }
}
