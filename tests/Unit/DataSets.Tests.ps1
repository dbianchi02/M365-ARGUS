#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.5.0' }

BeforeAll {
    Get-Module ARGUS | Remove-Module -Force
    Import-Module (Join-Path $PSScriptRoot '../../ARGUS/ARGUS.psd1') -Force -ErrorAction Stop

    # Sets the module connection state used by Get-ArgusEnvironment.
    function Initialize-TestConnection {
        param([string[]] $Scopes, [string[]] $Licenses, [switch] $UnknownLicenses)
        InModuleScope ARGUS -Parameters @{ Scopes = $Scopes; Licenses = $Licenses; Unknown = [bool]$UnknownLicenses } {
            # Assign outside 'if' expressions: an 'if' returning @() would collapse to $null ("unknown").
            [string[]] $licenseList = @($Licenses | Where-Object { $_ })
            if ($Unknown) { $licenseList = $null }
            $script:ArgusConnection = [pscustomobject]@{
                ConnectedServices = [string[]]@('Graph')
                GrantedScopes     = $Scopes
                Licenses          = $licenseList
            }
            $script:ArgusDataCache = @{}
            $script:ArgusDataSetNotes = @{}
        }
    }
}

AfterAll {
    InModuleScope ARGUS { $script:ArgusConnection = $null }
    Get-Module ARGUS | Remove-Module -Force
}

Describe 'Data set catalogue' {
    BeforeAll {
        $script:catalog = InModuleScope ARGUS { @(Get-ArgusDataSetDefinition) }
    }

    It 'contains the data sets of the specification' {
        $names = $script:catalog.Name
        foreach ($expected in 'Users', 'Groups', 'DirectoryRoles', 'Applications', 'SubscribedSkus', 'Organization', 'AuthorizationPolicy',
            'GroupSettings', 'GroupLifecyclePolicies', 'Devices', 'ReportSettings', 'TeamsActivity', 'SharePointSiteUsage',
            'SharePointTenantSettings', 'Mailboxes', 'DistributionGroups', 'Subscriptions', 'SharePointSites', 'OneDriveUsage', 'MailboxUsage',
            'SharePointTenant', 'SharedMailboxPermissions', 'DistributionGroupMembers', 'CopilotUsage', 'CopilotWebSearchPolicy',
            'CopilotPersonalization', 'CopilotPackages', 'CommercePolicies', 'UserManagers', 'GuestSponsors') {
            $names | Should -Contain $expected
        }
        ($names | Sort-Object -Unique).Count | Should -Be $names.Count
    }

    It 'describes every data set completely' {
        foreach ($dataSet in $script:catalog) {
            $dataSet.Endpoint | Should -Not -BeNullOrEmpty -Because $dataSet.Name
            $dataSet.Service | Should -BeIn @('Graph', 'Exchange', 'SharePoint', 'Commerce') -Because $dataSet.Name
            $dataSet.Loader | Should -BeOfType [scriptblock] -Because $dataSet.Name
            @($dataSet.Roles).Count | Should -BeGreaterThan 0 -Because $dataSet.Name
            if ($dataSet.Service -eq 'Graph') { @($dataSet.Permissions).Count | Should -BeGreaterThan 0 -Because $dataSet.Name }
        }
    }

    It 'requests only read permissions' {
        foreach ($permission in $script:catalog.Permissions) {
            $permission | Should -Match '\.Read(Basic)?(\.|$)' -Because 'ARGUS is read-only'
            $permission | Should -Not -Match '\.ReadWrite|\.Manage|FullControl'
        }
    }

    It 'registers a loader for every data set at import' {
        InModuleScope ARGUS {
            foreach ($dataSet in Get-ArgusDataSetDefinition) {
                $script:ArgusDataSetLoaders.ContainsKey($dataSet.Name) | Should -BeTrue
            }
        }
    }
}

Describe 'Users loader' {
    It 'includes signInActivity when Entra ID P1 and AuditLog.Read.All are available' {
        Initialize-TestConnection -Scopes 'User.Read.All', 'AuditLog.Read.All' -Licenses 'AAD_PREMIUM'
        Mock Invoke-MgGraphRequest -ModuleName ARGUS { [pscustomobject]@{ value = @([pscustomobject]@{ id = 'u1' }) } }
        $users = InModuleScope ARGUS { Get-ArgusData -Name Users }
        @($users).Count | Should -Be 1
        Should -Invoke Invoke-MgGraphRequest -ModuleName ARGUS -Times 1 -Exactly -ParameterFilter { $Uri -like '*signInActivity*' -and $Uri -like '*$top=500*' }
        InModuleScope ARGUS { $script:ArgusDataSetNotes['Users'] | Should -Be 'signInActivity included.' }
    }

    It 'falls back to users without sign-in data when signInActivity is denied' {
        Initialize-TestConnection -Scopes 'User.Read.All', 'AuditLog.Read.All' -UnknownLicenses
        Mock Invoke-MgGraphRequest -ModuleName ARGUS {
            if ($Uri -like '*signInActivity*') { throw [System.Exception]::new('Response status code does not indicate success: Forbidden (Forbidden).') }
            [pscustomobject]@{ value = @([pscustomobject]@{ id = 'u1' }, [pscustomobject]@{ id = 'u2' }) }
        }
        $users = InModuleScope ARGUS { Get-ArgusData -Name Users }
        @($users).Count | Should -Be 2
        InModuleScope ARGUS { $script:ArgusDataSetNotes['Users'] | Should -BeLike 'signInActivity not available (403)*' }
    }

    It 'does not request signInActivity without Entra ID P1' {
        Initialize-TestConnection -Scopes 'User.Read.All', 'AuditLog.Read.All' -Licenses @()
        Mock Invoke-MgGraphRequest -ModuleName ARGUS { [pscustomobject]@{ value = @() } }
        $null = InModuleScope ARGUS { Get-ArgusData -Name Users }
        Should -Invoke Invoke-MgGraphRequest -ModuleName ARGUS -Times 0 -Exactly -ParameterFilter { $Uri -like '*signInActivity*' }
        Should -Invoke Invoke-MgGraphRequest -ModuleName ARGUS -Times 1 -Exactly -ParameterFilter { $Uri -like '*$top=999*' }
    }

    It 'treats Entra ID P2 as including P1' {
        Initialize-TestConnection -Scopes 'User.Read.All', 'AuditLog.Read.All' -Licenses 'AAD_PREMIUM_P2'
        Mock Invoke-MgGraphRequest -ModuleName ARGUS { [pscustomobject]@{ value = @() } }
        $null = InModuleScope ARGUS { Get-ArgusData -Name Users }
        Should -Invoke Invoke-MgGraphRequest -ModuleName ARGUS -Times 1 -Exactly -ParameterFilter { $Uri -like '*signInActivity*' }
    }

    It 'is fetched once per run (cache)' {
        Initialize-TestConnection -Scopes 'User.Read.All' -Licenses @()
        Mock Invoke-MgGraphRequest -ModuleName ARGUS { [pscustomobject]@{ value = @() } }
        $null = InModuleScope ARGUS { Get-ArgusData -Name Users; Get-ArgusData -Name Users }
        Should -Invoke Invoke-MgGraphRequest -ModuleName ARGUS -Times 1 -Exactly
    }
}

Describe 'Groups and Applications loaders' {
    It 'expands owners and adds OwnerCount, IsUnified, IsTeam and IsDynamic' {
        Initialize-TestConnection -Scopes 'Group.Read.All' -Licenses @()
        Mock Invoke-MgGraphRequest -ModuleName ARGUS {
            [pscustomobject]@{ value = @(
                    [pscustomobject]@{ id = 'g1'; groupTypes = @('Unified'); resourceProvisioningOptions = @('Team'); owners = @([pscustomobject]@{ id = 'o1' }) }
                    [pscustomobject]@{ id = 'g2'; groupTypes = @('DynamicMembership'); resourceProvisioningOptions = @(); owners = @() }
                )
            }
        }
        $groups = InModuleScope ARGUS { @(Get-ArgusData -Name Groups) }
        $groups[0].OwnerCount | Should -Be 1
        $groups[0].IsUnified | Should -BeTrue
        $groups[0].IsTeam | Should -BeTrue
        $groups[1].OwnerCount | Should -Be 0
        $groups[1].IsDynamic | Should -BeTrue
        Should -Invoke Invoke-MgGraphRequest -ModuleName ARGUS -Times 1 -Exactly -ParameterFilter { $Uri -like '*$expand=owners($select=*' }
    }

    It 'adds OwnerCount to applications' {
        Initialize-TestConnection -Scopes 'Application.Read.All' -Licenses @()
        Mock Invoke-MgGraphRequest -ModuleName ARGUS { [pscustomobject]@{ value = @([pscustomobject]@{ id = 'a1'; passwordCredentials = @(); keyCredentials = @() }) } }
        $apps = InModuleScope ARGUS { @(Get-ArgusData -Name Applications) }
        $apps[0].OwnerCount | Should -Be 0
    }
}

Describe 'DirectoryRoles loader' {
    It 'skips eligible assignments without Entra ID P2' {
        Initialize-TestConnection -Scopes 'RoleManagement.Read.Directory' -Licenses 'AAD_PREMIUM'
        Mock Invoke-MgGraphRequest -ModuleName ARGUS { [pscustomobject]@{ value = @([pscustomobject]@{ id = 'x' }) } }
        $roles = InModuleScope ARGUS { Get-ArgusData -Name DirectoryRoles }
        $roles.EligibleAvailable | Should -BeFalse
        $roles.Eligible | Should -BeNullOrEmpty
        @($roles.Assignments).Count | Should -Be 1
        Should -Invoke Invoke-MgGraphRequest -ModuleName ARGUS -Times 0 -Exactly -ParameterFilter { $Uri -like '*roleEligibilitySchedules*' }
    }

    It 'reads eligible assignments with Entra ID P2' {
        Initialize-TestConnection -Scopes 'RoleManagement.Read.Directory' -Licenses 'AAD_PREMIUM_P2'
        Mock Invoke-MgGraphRequest -ModuleName ARGUS { [pscustomobject]@{ value = @([pscustomobject]@{ id = 'x' }) } }
        $roles = InModuleScope ARGUS { Get-ArgusData -Name DirectoryRoles }
        $roles.EligibleAvailable | Should -BeTrue
        Should -Invoke Invoke-MgGraphRequest -ModuleName ARGUS -Times 1 -Exactly -ParameterFilter { $Uri -like '*roleEligibilitySchedules?$expand=principal' }
    }
}

Describe 'Get-ArgusLicenseInfo' {
    It 'returns <Expected> for <Name>' -ForEach @(
        @{ Name = 'an enabled P1 plan'; Skus = @(@{ capabilityStatus = 'Enabled'; servicePlans = @(@{ servicePlanName = 'AAD_PREMIUM'; provisioningStatus = 'Success' }) }); Expected = @('AAD_PREMIUM') }
        @{ Name = 'P1 and P2 plans'; Skus = @(@{ capabilityStatus = 'Enabled'; servicePlans = @(@{ servicePlanName = 'AAD_PREMIUM'; provisioningStatus = 'Success' }, @{ servicePlanName = 'AAD_PREMIUM_P2'; provisioningStatus = 'Success' }) }); Expected = @('AAD_PREMIUM', 'AAD_PREMIUM_P2') }
        @{ Name = 'a suspended SKU'; Skus = @(@{ capabilityStatus = 'Suspended'; servicePlans = @(@{ servicePlanName = 'AAD_PREMIUM'; provisioningStatus = 'Success' }) }); Expected = @() }
        @{ Name = 'a disabled plan'; Skus = @(@{ capabilityStatus = 'Enabled'; servicePlans = @(@{ servicePlanName = 'AAD_PREMIUM'; provisioningStatus = 'Disabled' }) }); Expected = @() }
        @{ Name = 'unrelated plans'; Skus = @(@{ capabilityStatus = 'Enabled'; servicePlans = @(@{ servicePlanName = 'EXCHANGE_S_STANDARD'; provisioningStatus = 'Success' }) }); Expected = @() }
    ) {
        InModuleScope ARGUS -Parameters @{ Skus = $Skus; Expected = $Expected } {
            $objects = @($Skus | ForEach-Object { [pscustomobject]@{ capabilityStatus = $_.capabilityStatus; servicePlans = @($_.servicePlans | ForEach-Object { [pscustomobject]$_ }) } })
            $result = @(Get-ArgusLicenseInfo -Sku $objects)
            $result | Should -Be $Expected
        }
    }
}

Describe 'Copilot loaders' {
    BeforeEach {
        Initialize-TestConnection -Scopes 'CopilotPolicySettings.Read' -Licenses @()
    }

    It 'reads the web search policy from the beta endpoint' {
        Mock Invoke-MgGraphRequest -ModuleName ARGUS { [pscustomobject]@{ id = 'microsoft.copilot.allowwebsearch'; value = $null; policyId = $null } }
        $setting = InModuleScope ARGUS { Get-ArgusData -Name CopilotWebSearchPolicy }
        $setting.id | Should -Be 'microsoft.copilot.allowwebsearch'
        Should -Invoke Invoke-MgGraphRequest -ModuleName ARGUS -Times 1 -Exactly -ParameterFilter { $Uri -eq 'https://graph.microsoft.com/beta/copilot/admin/policySettings/microsoft.copilot.allowwebsearch' -and $Method -eq 'GET' }
    }

    It 'marks the web search policy as unavailable on 403 and group-scoped on 422' {
        Mock Invoke-MgGraphRequest -ModuleName ARGUS { throw [System.Exception]::new('Response status code does not indicate success: Forbidden (Forbidden).') }
        (InModuleScope ARGUS { Get-ArgusData -Name CopilotWebSearchPolicy -Force }).ArgusUnavailable | Should -BeLike '*(403)*'
        Mock Invoke-MgGraphRequest -ModuleName ARGUS { throw [System.Exception]::new('Response status code does not indicate success: UnprocessableEntity (Unprocessable Content).') }
        (InModuleScope ARGUS { Get-ArgusData -Name CopilotWebSearchPolicy -Force }).GroupScoped | Should -BeTrue
    }

    It 'unwraps the enhanced personalization setting from value' {
        Mock Invoke-MgGraphRequest -ModuleName ARGUS { [pscustomobject]@{ value = [pscustomobject]@{ isEnabledInOrganization = $true; disabledForGroup = $null } } }
        (InModuleScope ARGUS { Get-ArgusData -Name CopilotPersonalization }).isEnabledInOrganization | Should -BeTrue
    }

    It 'reads the agent catalogue and the pending request queue' {
        Mock Invoke-MgGraphRequest -ModuleName ARGUS {
            if ($Uri -like "*requestStatus eq 'pending'*") { return [pscustomobject]@{ value = @([pscustomobject]@{ id = 'P2'; requestStatus = 'pending' }) } }
            [pscustomobject]@{ value = @([pscustomobject]@{ id = 'P1' }, [pscustomobject]@{ id = 'P2' }) }
        }
        $catalog = InModuleScope ARGUS { Get-ArgusData -Name CopilotPackages }
        @($catalog.Packages).Count | Should -Be 2
        @($catalog.PendingRequests).id | Should -Be @('P2')
    }

    It 'reads the Copilot usage report from copilot/reports' {
        Mock Invoke-MgGraphRequest -ModuleName ARGUS { Set-Content -LiteralPath $OutputFilePath -Value "User Principal Name,Last Activity Date`nanna@contoso.com,2026-10-01" }
        $rows = InModuleScope ARGUS { @(Get-ArgusData -Name CopilotUsage) }
        $rows[0].'User Principal Name' | Should -Be 'anna@contoso.com'
        Should -Invoke Invoke-MgGraphRequest -ModuleName ARGUS -Times 1 -Exactly -ParameterFilter { $Uri -like "*/v1.0/copilot/reports/getMicrosoft365CopilotUsageUserDetail(period='D180')" }
    }
}

Describe 'Exchange, PnP and commerce loaders' {
    BeforeAll {
        function global:Get-EXOMailboxPermission { param([string] $Identity) }
        function global:Get-PnPTenant { param() }
    }

    AfterAll {
        foreach ($name in 'Get-EXOMailboxPermission', 'Get-PnPTenant') { Remove-Item -Path "Function:\$name" -ErrorAction SilentlyContinue }
    }

    BeforeEach {
        Initialize-TestConnection -Scopes 'GroupMember.Read.All' -Licenses @()
    }

    It 'keeps explicit FullAccess delegates of shared mailboxes only' {
        InModuleScope ARGUS {
            $script:ArgusDataCache['Mailboxes'] = @(
                [pscustomobject]@{ UserPrincipalName = 'info@contoso.com'; RecipientTypeDetails = 'SharedMailbox'; ExternalDirectoryObjectId = 'sm1' }
                [pscustomobject]@{ UserPrincipalName = 'anna@contoso.com'; RecipientTypeDetails = 'UserMailbox'; ExternalDirectoryObjectId = 'u1' }
            )
        }
        Mock Get-EXOMailboxPermission -ModuleName ARGUS {
            @(
                [pscustomobject]@{ User = 'NT AUTHORITY\SELF'; AccessRights = @('FullAccess', 'ReadPermission'); IsInherited = $false; Deny = $false }
                [pscustomobject]@{ User = 'anna@contoso.com'; AccessRights = @('FullAccess'); IsInherited = $false; Deny = $false }
                [pscustomobject]@{ User = 'admins'; AccessRights = @('FullAccess'); IsInherited = $true; Deny = $false }
                [pscustomobject]@{ User = 'bob@contoso.com'; AccessRights = @('FullAccess'); IsInherited = $false; Deny = $true }
            )
        }
        $permissions = InModuleScope ARGUS { Get-ArgusData -Name SharedMailboxPermissions }
        $permissions['sm1'] | Should -Be @('anna@contoso.com')
        $permissions.ContainsKey('u1') | Should -BeFalse
        Should -Invoke Get-EXOMailboxPermission -ModuleName ARGUS -Times 1 -Exactly -ParameterFilter { $Identity -eq 'sm1' }
    }

    It 'reads distribution group members through Graph batching' {
        InModuleScope ARGUS {
            $script:ArgusDataCache['DistributionGroups'] = @(
                [pscustomobject]@{ DisplayName = 'Full'; ExternalDirectoryObjectId = 'g1' }
                [pscustomobject]@{ DisplayName = 'Empty'; ExternalDirectoryObjectId = 'g2' }
                [pscustomobject]@{ DisplayName = 'Denied'; ExternalDirectoryObjectId = 'g3' }
            )
        }
        Mock Invoke-ArgusGraphBatch -ModuleName ARGUS {
            @(
                [pscustomobject]@{ Id = 'g1'; Status = 200; Body = [pscustomobject]@{ value = @([pscustomobject]@{ id = 'm1' }) } }
                [pscustomobject]@{ Id = 'g2'; Status = 200; Body = [pscustomobject]@{ value = @() } }
                [pscustomobject]@{ Id = 'g3'; Status = 403; Body = $null }
            )
        }
        $members = InModuleScope ARGUS { Get-ArgusData -Name DistributionGroupMembers }
        $members['g1'] | Should -BeTrue
        $members['g2'] | Should -BeFalse
        $members['g3'] | Should -BeNullOrEmpty
        Should -Invoke Invoke-ArgusGraphBatch -ModuleName ARGUS -Times 1 -Exactly -ParameterFilter { @($Request).Count -eq 3 -and $Request[0].Url -eq '/groups/g1/members?$select=id&$top=1' }
    }

    It 'returns the MSCommerce policies read at connection' {
        InModuleScope ARGUS { $script:ArgusCommercePolicies = @([pscustomobject]@{ ProductName = 'Microsoft Copilot'; ProductId = 'CFQ7TTC0MM8R'; PolicyValue = 'Disabled' }) }
        $policies = InModuleScope ARGUS { @(Get-ArgusData -Name CommercePolicies) }
        $policies[0].PolicyValue | Should -Be 'Disabled'
        InModuleScope ARGUS { $script:ArgusCommercePolicies = $null }
    }

    It 'fails clearly when the MSCommerce policies were not read' {
        InModuleScope ARGUS { $script:ArgusCommercePolicies = $null }
        { InModuleScope ARGUS { Get-ArgusData -Name CommercePolicies -Force } } | Should -Throw '*Connect-Argus -Service Commerce*'
    }

    It 'selects the sharing settings from Get-PnPTenant' {
        Mock Get-PnPTenant -ModuleName ARGUS { [pscustomobject]@{ ExternalUserExpirationRequired = $true; ExternalUserExpireInDays = 60; RequireAnonymousLinksExpireInDays = 30; DefaultSharingLinkType = 'Direct'; Unrelated = 'x' } }
        $tenant = InModuleScope ARGUS { Get-ArgusData -Name SharePointTenant }
        $tenant.ExternalUserExpireInDays | Should -Be 60
        $tenant.PSObject.Properties.Name | Should -Not -Contain 'Unrelated'
    }
}

Describe 'Get-ArgusCommercePolicy (separate process)' {
    BeforeAll {
        # A fake MSCommerce module on PSModulePath, inherited by the child pwsh process.
        $fakeRoot = Join-Path $TestDrive 'modules'
        $moduleDir = New-Item -ItemType Directory -Path (Join-Path $fakeRoot 'MSCommerce') -Force
        $fake = @(
            'function Connect-MSCommerce { if ($env:ARGUS_FAKE_COMMERCE_FAIL) { throw ''sign-in cancelled'' }; Write-Host ''Connection established successfully'' }'
            'function Get-MSCommerceProductPolicies { param([string] $PolicyId) [pscustomobject]@{ PolicyId = $PolicyId; ProductName = ''Microsoft Copilot''; ProductId = ''CFQ7TTC0MM8R''; PolicyValue = ''Enabled'' } }'
        )
        Set-Content -LiteralPath (Join-Path $moduleDir 'MSCommerce.psm1') -Value $fake
        $script:savedModulePath = $env:PSModulePath
        $env:PSModulePath = $fakeRoot + [System.IO.Path]::PathSeparator + $env:PSModulePath
    }

    AfterAll {
        $env:PSModulePath = $script:savedModulePath
        $env:ARGUS_FAKE_COMMERCE_FAIL = $null
    }

    It 'returns the product policies written by the child process' {
        $policies = InModuleScope ARGUS { @(Get-ArgusCommercePolicy) }
        $policies.Count | Should -Be 1
        $policies[0].ProductId | Should -Be 'CFQ7TTC0MM8R'
        $policies[0].PolicyValue | Should -Be 'Enabled'
        $policies[0].PSObject.Properties.Name | Should -Not -Contain 'PolicyId'
    }

    It 'throws when the child process fails' {
        $env:ARGUS_FAKE_COMMERCE_FAIL = '1'
        try { { InModuleScope ARGUS { Get-ArgusCommercePolicy } } | Should -Throw '*exit code*' }
        finally { $env:ARGUS_FAKE_COMMERCE_FAIL = $null }
    }
}
