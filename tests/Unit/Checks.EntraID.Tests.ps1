#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.5.0' }

BeforeAll {
    Get-Module ARGUS | Remove-Module -Force
    Import-Module (Join-Path $PSScriptRoot '../../ARGUS/ARGUS.psd1') -Force -ErrorAction Stop
    . (Join-Path $PSScriptRoot 'TestHelpers.ps1')

    $script:now = [datetime]::new(2026, 10, 19, 0, 0, 0, [System.DateTimeKind]::Utc)
    $script:e3 = '05e9a617-0261-4cee-bb44-138d3ef5d965'
    $script:skus = @([pscustomobject]@{ skuId = $script:e3; skuPartNumber = 'SPE_E3' })

    # Fake Graph user. -DaysAgo $null = never signed in.
    function Get-TestUser {
        param([string] $Name, [object] $DaysAgo = 10, [hashtable] $Set = @{}, [switch] $NoSignInActivity)
        $user = [ordered]@{
            id = "id-$Name"; displayName = $Name; userPrincipalName = "$Name@contoso.com"; mail = "$Name@contoso.com"
            userType = 'Member'; accountEnabled = $true; createdDateTime = '2024-01-01T00:00:00Z'
            externalUserState = $null; externalUserStateChangeDateTime = $null; assignedLicenses = @(); onPremisesSyncEnabled = $null
        }
        if (-not $NoSignInActivity) {
            $last = if ($null -eq $DaysAgo) { $null } else { $script:now.AddDays(-[int]$DaysAgo).ToString('o') }
            $user.signInActivity = [pscustomobject]@{ lastSuccessfulSignInDateTime = $last; lastSignInDateTime = $null; lastNonInteractiveSignInDateTime = $null }
        }
        foreach ($key in $Set.Keys) { $user[$key] = $Set[$key] }
        [pscustomobject]$user
    }

    function Invoke-EntraCheck {
        param([string] $Id, [hashtable] $Data, [hashtable] $Options = @{})
        InModuleScope ARGUS -Parameters @{ Id = $Id; Data = $Data; Options = $Options } {
            Invoke-TestCheck -Id $Id -Data $Data @Options
        }
    }
}

AfterAll {
    Get-Module ARGUS | Remove-Module -Force
}

Describe 'Entra ID catalogue' {
    It 'registers the 15 Entra ID checks of the specification' {
        (Get-ArgusCheck -Area EntraID).Id | Should -Be @(1..15 | ForEach-Object { 'ARG.ENT.{0:D3}' -f $_ })
    }
}

Describe 'ARG.ENT.001 Enabled members inactive' {
    It 'fails for inactive and never-signed-in members, ignoring new, disabled and guest accounts' {
        $users = @(
            Get-TestUser 'inactive' -DaysAgo 200
            Get-TestUser 'active' -DaysAgo 10
            Get-TestUser 'never' -DaysAgo $null -Set @{ createdDateTime = '2025-01-01T00:00:00Z' }
            Get-TestUser 'newbie' -DaysAgo $null -Set @{ createdDateTime = '2026-10-10T00:00:00Z' }
            Get-TestUser 'disabled' -DaysAgo 300 -Set @{ accountEnabled = $false }
            Get-TestUser 'guest' -DaysAgo 300 -Set @{ userType = 'Guest' }
        )
        $result = Invoke-EntraCheck 'ARG.ENT.001' @{ Users = $users }
        $result.Status | Should -Be 'Failed'
        $result.EvaluatedCount | Should -Be 4
        $result.Findings.DisplayName | Should -Be @('never', 'inactive')
        ($result.Findings | Where-Object DisplayName -EQ 'never').LastSignIn | Should -Be 'Never'
        $result.Summary | Should -Be '2 of 4 enabled members have not signed in for 90+ days.'
        $result.Title | Should -Be 'Enabled members inactive for more than 90 days'
    }

    It 'falls back to the most recent sign-in attempt when lastSuccessfulSignInDateTime is empty' {
        $user = Get-TestUser 'legacy' -DaysAgo $null
        $user.signInActivity = [pscustomobject]@{ lastSuccessfulSignInDateTime = $null; lastSignInDateTime = '2023-01-01T00:00:00Z'; lastNonInteractiveSignInDateTime = '2026-10-01T00:00:00Z' }
        (Invoke-EntraCheck 'ARG.ENT.001' @{ Users = @($user) }).Status | Should -Be 'Passed'
    }

    It 'passes when every member is active' {
        (Invoke-EntraCheck 'ARG.ENT.001' @{ Users = @((Get-TestUser 'a'), (Get-TestUser 'b')) }).Status | Should -Be 'Passed'
    }

    It 'honours the InactiveDays override' {
        $result = Invoke-EntraCheck 'ARG.ENT.001' @{ Users = @(Get-TestUser 'a' -DaysAgo 40) } @{ Setting = @{ Parameters = @{ InactiveDays = 30 } } }
        $result.Status | Should -Be 'Failed'
        $result.Title | Should -Be 'Enabled members inactive for more than 30 days'
    }

    It 'applies global exclusions (break-glass accounts)' {
        $users = @((Get-TestUser 'breakglass' -DaysAgo 400), (Get-TestUser 'old' -DaysAgo 400))
        $result = Invoke-EntraCheck 'ARG.ENT.001' @{ Users = $users } @{ Exclusions = @{ UserPrincipalNames = @('breakglass@contoso.com') } }
        $result.Findings.DisplayName | Should -Be @('old')
        $result.ExcludedCount | Should -Be 1
    }

    It 'is skipped when sign-in activity was not loaded' {
        $result = Invoke-EntraCheck 'ARG.ENT.001' @{ Users = @(Get-TestUser 'a' -NoSignInActivity) }
        $result.Status | Should -Be 'Skipped'
        $result.SkipReason | Should -BeLike '*Sign-in activity is not available*'
    }

    It 'is skipped without Entra ID P1' {
        $result = Invoke-EntraCheck 'ARG.ENT.001' @{ Users = @() } @{ Licenses = @() }
        $result.Status | Should -Be 'Skipped'
        $result.SkipReason | Should -Be 'Entra ID P1 licence (AAD_PREMIUM) not detected.'
    }
}


Describe 'ARG.ENT.005 Inactive guests' {
    It 'lists accepted guests that are inactive, not pending ones' {
        $users = @(
            Get-TestUser 'old-guest' -DaysAgo 200 -Set @{ userType = 'Guest'; externalUserState = 'Accepted' }
            Get-TestUser 'legacy-guest' -DaysAgo $null -Set @{ userType = 'Guest'; externalUserState = $null }
            Get-TestUser 'pending-guest' -DaysAgo $null -Set @{ userType = 'Guest'; externalUserState = 'PendingAcceptance' }
            Get-TestUser 'active-guest' -DaysAgo 3 -Set @{ userType = 'Guest'; externalUserState = 'Accepted' }
            Get-TestUser 'member' -DaysAgo 300
        )
        $result = Invoke-EntraCheck 'ARG.ENT.005' @{ Users = $users }
        $result.Status | Should -Be 'Failed'
        $result.EvaluatedCount | Should -Be 3
        ($result.Findings.DisplayName | Sort-Object) | Should -Be @('legacy-guest', 'old-guest')
    }

    It 'passes when guests are active' {
        $users = @(Get-TestUser 'g' -DaysAgo 3 -Set @{ userType = 'Guest'; externalUserState = 'Accepted' })
        (Invoke-EntraCheck 'ARG.ENT.005' @{ Users = $users }).Status | Should -Be 'Passed'
    }
}

Describe 'ARG.ENT.004 Pending guest invitations' {
    It 'lists invitations pending for more than 30 days' {
        $users = @(
            Get-TestUser 'old' -Set @{ userType = 'Guest'; externalUserState = 'PendingAcceptance'; externalUserStateChangeDateTime = '2026-08-01T00:00:00Z' }
            Get-TestUser 'created-fallback' -Set @{ userType = 'Guest'; externalUserState = 'PendingAcceptance'; createdDateTime = '2026-01-01T00:00:00Z' }
            Get-TestUser 'recent' -Set @{ userType = 'Guest'; externalUserState = 'PendingAcceptance'; externalUserStateChangeDateTime = '2026-10-10T00:00:00Z' }
            Get-TestUser 'accepted' -Set @{ userType = 'Guest'; externalUserState = 'Accepted' }
        )
        $result = Invoke-EntraCheck 'ARG.ENT.004' @{ Users = $users } @{ Licenses = @() }
        $result.Status | Should -Be 'Failed'
        $result.Findings.DisplayName | Should -Be @('created-fallback', 'old')
        $result.Findings[1].DaysPending | Should -Be 79
        $result.Summary | Should -Be '2 of 4 guests have not accepted their invitation for 30+ days.'
    }

    It 'passes with no old pending invitations' {
        (Invoke-EntraCheck 'ARG.ENT.004' @{ Users = @(Get-TestUser 'm') }).Status | Should -Be 'Passed'
    }
}
Describe 'ARG.ENT.007 Emergency access accounts' {
    BeforeAll {
        $script:ga = '62e90394-69f5-4237-9190-012177145e10'
        function Get-GaRow {
            param([string] $Name)
            [pscustomobject]@{
                roleDefinitionId = $script:ga; principalId = "id-$Name"
                principal        = [pscustomobject]@{ '@odata.type' = '#microsoft.graph.user'; id = "id-$Name"; displayName = $Name; userPrincipalName = "$Name@contoso.onmicrosoft.com"; userType = 'Member' }
            }
        }
        $script:gaDefinitions = @([pscustomobject]@{ id = $script:ga; templateId = $script:ga; displayName = 'Global Administrator' })
        $script:bgUsers = @(
            Get-TestUser 'breakglass01' -Set @{ userPrincipalName = 'breakglass01@contoso.onmicrosoft.com' }
            Get-TestUser 'breakglass02' -Set @{ userPrincipalName = 'breakglass02@contoso.onmicrosoft.com' }
            Get-TestUser 'emergency-synced' -Set @{ userPrincipalName = 'emergency@contoso.com'; onPremisesSyncEnabled = $true }
            Get-TestUser 'alice'
        )
    }

    It 'passes with two compliant accounts found by name and reports the non-compliant one' {
        $roles = [pscustomobject]@{
            Definitions = $script:gaDefinitions; Assignments = @((Get-GaRow 'breakglass01'), (Get-GaRow 'breakglass02')); Eligible = @(Get-GaRow 'emergency-synced'); EligibleAvailable = $true
        }
        $result = Invoke-EntraCheck 'ARG.ENT.007' @{ Users = $script:bgUsers; DirectoryRoles = $roles } @{ Exclusions = @{ UserPrincipalNames = @('breakglass01@contoso.onmicrosoft.com') } }
        $result.Status | Should -Be 'Passed'
        @($result.Findings).Count | Should -Be 3 -Because 'global exclusions are not applied'
        $result.AffectedCount | Should -Be 1
        $synced = $result.Findings | Where-Object DisplayName -EQ 'emergency-synced'
        $synced.Compliant | Should -Be 'No'
        $synced.GlobalAdmin | Should -Be 'Eligible only'
        $synced.Issues | Should -Be 'synchronised from on-premises; UPN not on *.onmicrosoft.com; no direct active Global Administrator assignment'
        $result.Summary | Should -BeLike '2 of 3 emergency access accounts (matching NamePatterns*) meet the requirements; at least 2 are needed.'
    }

    It 'fails when only one account is compliant and uses the Accounts parameter instead of names' {
        $roles = [pscustomobject]@{ Definitions = $script:gaDefinitions; Assignments = @((Get-GaRow 'breakglass01'), (Get-GaRow 'alice')); Eligible = @(); EligibleAvailable = $true }
        $users = @($script:bgUsers | Where-Object displayName -NE 'alice') + @(Get-TestUser 'alice' -Set @{ userPrincipalName = 'alice@contoso.onmicrosoft.com' })
        $result = Invoke-EntraCheck 'ARG.ENT.007' @{ Users = $users; DirectoryRoles = $roles } @{ Setting = @{ Parameters = @{ Accounts = @('alice@contoso.onmicrosoft.com', 'id-breakglass02') } } }
        $result.Status | Should -Be 'Failed'
        $result.Findings.DisplayName | Should -Be @('breakglass02', 'alice')
        ($result.Findings | Where-Object DisplayName -EQ 'breakglass02').GlobalAdmin | Should -Be 'No'
    }

    It 'fails when no emergency access account can be found' {
        $roles = [pscustomobject]@{ Definitions = $script:gaDefinitions; Assignments = @(); Eligible = @(); EligibleAvailable = $false }
        $result = Invoke-EntraCheck 'ARG.ENT.007' @{ Users = @(Get-TestUser 'alice'); DirectoryRoles = $roles }
        $result.Status | Should -Be 'Failed'
        $result.Summary | Should -BeLike 'No emergency access account found*'
    }
}

Describe 'ARG.ENT.012 LinkedIn account connections' {
    It 'always asks for manual verification, without reading tenant data' {
        $result = Invoke-EntraCheck 'ARG.ENT.012' @{}
        $result.Status | Should -Be 'Investigate'
        $result.Summary | Should -BeLike 'Manual verification required*'
        @($result.Findings).Count | Should -Be 0
    }
}

Describe 'ARG.ENT.008 Global Administrator count' {
    BeforeAll {
        $script:gaId = '62e90394-69f5-4237-9190-012177145e10'
        function Get-TestAssignment {
            param([string] $Name, [string] $Type = 'user', [string] $UserType = 'Member')
            [pscustomobject]@{
                roleDefinitionId = $script:gaId; principalId = "id-$Name"
                principal        = [pscustomobject]@{ '@odata.type' = "#microsoft.graph.$Type"; id = "id-$Name"; displayName = $Name; userPrincipalName = "$Name@contoso.com"; userType = $UserType }
            }
        }
        $script:definitions = @([pscustomobject]@{ id = $script:gaId; templateId = $script:gaId; displayName = 'Global Administrator' })
    }

    It 'counts group members and eligible assignments once per person and fails above the maximum' {
        Mock Invoke-ArgusGraphBatch -ModuleName ARGUS {
            [pscustomobject]@{ Id = 'id-Tier0'; Status = 200; Body = [pscustomobject]@{ value = @(
                        [pscustomobject]@{ '@odata.type' = '#microsoft.graph.user'; id = 'id-d'; displayName = 'd'; userPrincipalName = 'd@contoso.com'; userType = 'Member' }
                        [pscustomobject]@{ '@odata.type' = '#microsoft.graph.user'; id = 'id-e'; displayName = 'e'; userPrincipalName = 'e@contoso.com'; userType = 'Member' }
                    )
                }
            }
        }
        $roles = [pscustomobject]@{
            Definitions       = $script:definitions
            Assignments       = @((Get-TestAssignment 'a'), (Get-TestAssignment 'b'), (Get-TestAssignment 'c'), (Get-TestAssignment 'Tier0' -Type group))
            Eligible          = @(Get-TestAssignment 'a')
            EligibleAvailable = $true
        }
        $result = Invoke-EntraCheck 'ARG.ENT.008' @{ DirectoryRoles = $roles } @{ Exclusions = @{ UserPrincipalNames = @('a@contoso.com') } }
        $result.Status | Should -Be 'Failed'
        $result.AffectedCount | Should -Be 5
        ($result.Findings | Where-Object DisplayName -EQ 'a').Assignment | Should -Be 'Active, Eligible'
        ($result.Findings | Where-Object DisplayName -EQ 'd').Via | Should -Be 'Group: Tier0'
        $result.ExcludedCount | Should -Be 0 -Because 'emergency-access accounts must be counted'
        $result.Summary | Should -BeLike '5 Global Administrators (active and eligible assignments)*2 to 4.'
    }

    It 'passes within the range and notes when eligible assignments were not evaluated' {
        $roles = [pscustomobject]@{ Definitions = $script:definitions; Assignments = @((Get-TestAssignment 'a'), (Get-TestAssignment 'b')); Eligible = $null; EligibleAvailable = $false }
        $result = Invoke-EntraCheck 'ARG.ENT.008' @{ DirectoryRoles = $roles }
        $result.Status | Should -Be 'Passed'
        $result.Summary | Should -BeLike '2 Global Administrators (active assignments; eligible PIM assignments not evaluated*'
    }

    It 'fails with a single Global Administrator' {
        $roles = [pscustomobject]@{ Definitions = $script:definitions; Assignments = @(Get-TestAssignment 'a'); Eligible = $null; EligibleAvailable = $false }
        (Invoke-EntraCheck 'ARG.ENT.008' @{ DirectoryRoles = $roles }).Status | Should -Be 'Failed'
    }
}

Describe 'ARG.ENT.009 Directory roles assigned to guests' {
    It 'fails when a guest holds a role' {
        $roles = [pscustomobject]@{
            Definitions = @([pscustomobject]@{ id = 'r1'; templateId = 'r1'; displayName = 'User Administrator' })
            Assignments = @(
                [pscustomobject]@{ roleDefinitionId = 'r1'; principalId = 'id-g'; principal = [pscustomobject]@{ '@odata.type' = '#microsoft.graph.user'; displayName = 'Vendor'; userPrincipalName = 'vendor_x.com#EXT#@contoso.com'; userType = 'Guest' } }
                [pscustomobject]@{ roleDefinitionId = 'r1'; principalId = 'id-m'; principal = [pscustomobject]@{ '@odata.type' = '#microsoft.graph.user'; displayName = 'Admin'; userPrincipalName = 'admin@contoso.com'; userType = 'Member' } }
            )
            Eligible    = $null; EligibleAvailable = $false
        }
        $result = Invoke-EntraCheck 'ARG.ENT.009' @{ DirectoryRoles = $roles }
        $result.Status | Should -Be 'Failed'
        $result.Findings.DisplayName | Should -Be @('Vendor')
        $result.Findings[0].Role | Should -Be 'User Administrator'
    }

    It 'passes when no guest holds a role' {
        $roles = [pscustomobject]@{ Definitions = @(); Assignments = @(); Eligible = $null; EligibleAvailable = $false }
        (Invoke-EntraCheck 'ARG.ENT.009' @{ DirectoryRoles = $roles }).Status | Should -Be 'Passed'
    }
}

Describe 'ARG.ENT.013 Security groups without owners' {
    It 'evaluates only cloud, assigned, non-mail-enabled security groups' {
        $base = @{ securityEnabled = $true; mailEnabled = $false; IsUnified = $false; IsDynamic = $false; isAssignableToRole = $false; onPremisesSyncEnabled = $null; OwnerCount = 0; createdDateTime = '2025-01-01T00:00:00Z'; description = '' }
        $group = { param($Name, $Overrides) $g = $base.Clone(); $g.id = "g-$Name"; $g.displayName = $Name; foreach ($k in $Overrides.Keys) { $g[$k] = $Overrides[$k] }; [pscustomobject]$g }
        $groups = @(
            & $group 'ownerless' @{}
            & $group 'owned' @{ OwnerCount = 1 }
            & $group 'm365' @{ IsUnified = $true }
            & $group 'dynamic' @{ IsDynamic = $true }
            & $group 'synced' @{ onPremisesSyncEnabled = $true }
            & $group 'mailsec' @{ mailEnabled = $true }
        )
        $result = Invoke-EntraCheck 'ARG.ENT.013' @{ Groups = $groups }
        $result.Status | Should -Be 'Failed'
        $result.EvaluatedCount | Should -Be 2
        $result.Findings.DisplayName | Should -Be @('ownerless')
        $result.Findings[0].GroupId | Should -Be 'g-ownerless'
    }

    It 'passes when every evaluated group has an owner' {
        $groups = @([pscustomobject]@{ id = 'g'; displayName = 'g'; securityEnabled = $true; mailEnabled = $false; IsUnified = $false; IsDynamic = $false; isAssignableToRole = $false; OwnerCount = 2 })
        (Invoke-EntraCheck 'ARG.ENT.013' @{ Groups = $groups }).Status | Should -Be 'Passed'
    }
}

Describe 'ARG.ENT.014 Stale devices' {
    It 'lists devices not seen for 180 days, including old devices that never signed in' {
        $devices = @(
            [pscustomobject]@{ id = 'd1'; displayName = 'OLD-PC'; operatingSystem = 'Windows'; operatingSystemVersion = '10.0'; trustType = 'AzureAd'; accountEnabled = $true; approximateLastSignInDateTime = '2025-12-01T00:00:00Z'; registrationDateTime = '2024-01-01T00:00:00Z' }
            [pscustomobject]@{ id = 'd2'; displayName = 'NEVER'; operatingSystem = 'iOS'; trustType = 'Workplace'; accountEnabled = $false; approximateLastSignInDateTime = $null; registrationDateTime = '2025-01-01T00:00:00Z' }
            [pscustomobject]@{ id = 'd3'; displayName = 'ACTIVE'; operatingSystem = 'Windows'; trustType = 'AzureAd'; accountEnabled = $true; approximateLastSignInDateTime = '2026-10-01T00:00:00Z'; registrationDateTime = '2024-01-01T00:00:00Z' }
        )
        $result = Invoke-EntraCheck 'ARG.ENT.014' @{ Devices = $devices }
        $result.Status | Should -Be 'Failed'
        $result.Findings.DeviceName | Should -Be @('NEVER', 'OLD-PC')
        ($result.Findings | Where-Object DeviceName -EQ 'NEVER').LastSignIn | Should -Be 'Never'
        ($result.Findings | Where-Object DeviceName -EQ 'OLD-PC').OperatingSystem | Should -Be 'Windows 10.0'
    }

    It 'passes when all devices are recent' {
        $devices = @([pscustomobject]@{ id = 'd'; displayName = 'PC'; approximateLastSignInDateTime = '2026-10-18T00:00:00Z' })
        (Invoke-EntraCheck 'ARG.ENT.014' @{ Devices = $devices }).Status | Should -Be 'Passed'
    }
}

Describe 'ARG.ENT.003 Guest invitations' {
    It 'returns <Expected> for allowInvitesFrom = <Value>' -ForEach @(
        @{ Value = 'none'; Expected = 'Passed' }
        @{ Value = 'adminsAndGuestInviters'; Expected = 'Passed' }
        @{ Value = 'adminsGuestInvitersAndAllMembers'; Expected = 'Investigate' }
        @{ Value = 'everyone'; Expected = 'Failed' }
        @{ Value = 'somethingNew'; Expected = 'Investigate' }
    ) {
        (Invoke-EntraCheck 'ARG.ENT.003' @{ AuthorizationPolicy = [pscustomobject]@{ allowInvitesFrom = $Value } }).Status | Should -Be $Expected
    }
}

Describe 'ARG.ENT.010 / ARG.ENT.011 default user permissions' {
    It '<Id> returns <Expected> when <Property> = <Value>' -ForEach @(
        @{ Id = 'ARG.ENT.010'; Property = 'allowedToCreateApps'; Value = $true; Expected = 'Failed' }
        @{ Id = 'ARG.ENT.010'; Property = 'allowedToCreateApps'; Value = $false; Expected = 'Passed' }
        @{ Id = 'ARG.ENT.010'; Property = 'allowedToCreateApps'; Value = $null; Expected = 'Investigate' }
        @{ Id = 'ARG.ENT.011'; Property = 'allowedToCreateTenants'; Value = $true; Expected = 'Failed' }
        @{ Id = 'ARG.ENT.011'; Property = 'allowedToCreateTenants'; Value = $false; Expected = 'Passed' }
    ) {
        $policy = [pscustomobject]@{ defaultUserRolePermissions = [pscustomobject]@{ $Property = $Value } }
        (Invoke-EntraCheck $Id @{ AuthorizationPolicy = $policy }).Status | Should -Be $Expected
    }
}

Describe 'ARG.ENT.015 Directory synchronisation' {
    It 'returns <Expected> for <Name>' -ForEach @(
        @{ Name = 'a cloud-only tenant'; Org = @{ onPremisesSyncEnabled = $null; onPremisesLastSyncDateTime = $null }; Expected = 'Skipped' }
        @{ Name = 'a recent sync'; Org = @{ onPremisesSyncEnabled = $true; onPremisesLastSyncDateTime = '2026-10-18T22:00:00Z' }; Expected = 'Passed' }
        @{ Name = 'a stale sync'; Org = @{ onPremisesSyncEnabled = $true; onPremisesLastSyncDateTime = '2026-10-17T00:00:00Z' }; Expected = 'Failed' }
        @{ Name = 'a sync that never ran'; Org = @{ onPremisesSyncEnabled = $true; onPremisesLastSyncDateTime = $null }; Expected = 'Failed' }
    ) {
        $result = Invoke-EntraCheck 'ARG.ENT.015' @{ Organization = [pscustomobject]$Org }
        $result.Status | Should -Be $Expected
        if ($Expected -eq 'Skipped') { $result.SkipReason | Should -BeLike 'Cloud-only tenant*' }
    }
}

Describe 'ARG.ENT.002 Licensed users without manager or department' {
    BeforeAll {
        $lic = @([pscustomobject]@{ skuId = $script:e3 })
        $script:mgrUsers = @(
            (Get-TestUser 'complete' -Set @{ assignedLicenses = $lic })
            (Get-TestUser 'nomanager' -Set @{ assignedLicenses = $lic })
            (Get-TestUser 'nothing' -Set @{ assignedLicenses = $lic })
            (Get-TestUser 'service')
            (Get-TestUser 'disabled' -Set @{ assignedLicenses = $lic; accountEnabled = $false })
            (Get-TestUser 'guest' -Set @{ assignedLicenses = $lic; userType = 'Guest' })
        )
        $script:relations = @{
            'id-complete'  = [pscustomobject]@{ Department = 'Finance'; Manager = 'Anna' }
            'id-nomanager' = [pscustomobject]@{ Department = 'Sales'; Manager = '' }
            'id-nothing'   = [pscustomobject]@{ Department = ''; Manager = '' }
        }
    }

    It 'lists enabled licensed members with missing manager or department' {
        $result = Invoke-EntraCheck 'ARG.ENT.002' @{ Users = $script:mgrUsers; UserManagers = $script:relations }
        $result.Status | Should -Be 'Failed'
        $result.EvaluatedCount | Should -Be 3
        $result.Findings.UserPrincipalName | Should -Be @('nomanager@contoso.com', 'nothing@contoso.com')
        ($result.Findings | Where-Object UserPrincipalName -Like 'nothing*').Missing | Should -Be 'Manager, Department'
    }

    It 'passes when every licensed user has both' {
        (Invoke-EntraCheck 'ARG.ENT.002' @{ Users = @($script:mgrUsers[0]); UserManagers = $script:relations }).Status | Should -Be 'Passed'
    }
}

Describe 'ARG.ENT.006 Guests without a sponsor' {
    BeforeAll {
        $script:sponsorUsers = @(
            (Get-TestUser 'sponsored' -Set @{ userType = 'Guest' })
            (Get-TestUser 'orphan' -Set @{ userType = 'Guest' })
            (Get-TestUser 'blocked' -Set @{ userType = 'Guest'; accountEnabled = $false })
            (Get-TestUser 'member')
        )
    }

    It 'lists enabled guests without sponsors' {
        $result = Invoke-EntraCheck 'ARG.ENT.006' @{ Users = $script:sponsorUsers; GuestSponsors = @{ 'id-sponsored' = @('Anna'); 'id-orphan' = @() } }
        $result.Status | Should -Be 'Failed'
        $result.EvaluatedCount | Should -Be 2
        $result.Findings.ObjectId | Should -Be @('id-orphan')
    }

    It 'passes when every guest has a sponsor' {
        (Invoke-EntraCheck 'ARG.ENT.006' @{ Users = @($script:sponsorUsers[0]); GuestSponsors = @{ 'id-sponsored' = @('Anna') } }).Status | Should -Be 'Passed'
    }

    It 'is skipped when sponsors cannot be read' {
        $result = Invoke-EntraCheck 'ARG.ENT.006' @{ Users = $script:sponsorUsers; GuestSponsors = @{ ArgusUnavailable = 'No role (403).' } }
        $result.Status | Should -Be 'Skipped'
        $result.SkipReason | Should -Be 'No role (403).'
    }
}
