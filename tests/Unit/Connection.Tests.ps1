#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.5.0' }

BeforeAll {
    Get-Module ARGUS | Remove-Module -Force
    Import-Module (Join-Path $PSScriptRoot '../../ARGUS/ARGUS.psd1') -Force -ErrorAction Stop
    . (Join-Path $PSScriptRoot 'TestHelpers.ps1')

    # Stubs shadow the real Exchange / PnP cmdlets (functions win over cmdlets), so tests never
    # load those modules and run the same on machines where they are not installed.
    # Parameters mirror the real cmdlets so mocks can filter on them.
    function global:Connect-ExchangeOnline {
        param([string] $UserPrincipalName, [switch] $ShowBanner, [string] $AppId, [string] $CertificateThumbprint,
            [string] $Organization, [switch] $ManagedIdentity, [string] $ManagedIdentityAccountId, [switch] $DisableWAM)
    }
    function global:Disconnect-ExchangeOnline { [CmdletBinding(SupportsShouldProcess)] param() $null = $PSCmdlet.ShouldProcess('stub') }
    function global:Connect-PnPOnline {
        param([string] $Url, [switch] $Interactive, [string] $ClientId, [string] $Tenant, [string] $Thumbprint,
            [switch] $ManagedIdentity, [string] $UserAssignedManagedIdentityClientId)
    }
    function global:Disconnect-PnPOnline { param() }

    $script:allScopes = @((Get-ArgusRequiredPermission -Aggregate).GraphPermissions)
}

AfterAll {
    InModuleScope ARGUS { $script:ArgusConnection = $null }
    foreach ($name in 'Connect-ExchangeOnline', 'Disconnect-ExchangeOnline', 'Connect-PnPOnline', 'Disconnect-PnPOnline') {
        Remove-Item -Path "Function:\$name" -ErrorAction SilentlyContinue
    }
    Get-Module ARGUS | Remove-Module -Force
}

Describe 'Connect-Argus' {
    BeforeEach {
        InModuleScope ARGUS { $script:ArgusConnection = $null }
        Mock Connect-MgGraph -ModuleName ARGUS { }
        Mock Disconnect-MgGraph -ModuleName ARGUS { }
        Mock Get-MgContext -ModuleName ARGUS {
            [pscustomobject]@{ Account = 'auditor@contoso.onmicrosoft.com'; TenantId = '11111111-2222-3333-4444-555555555555'; Scopes = $script:grantedScopes; AppName = 'Microsoft Graph Command Line Tools'; ClientId = 'cli' }
        }
        Mock Invoke-MgGraphRequest -ModuleName ARGUS {
            switch -Wildcard ($Uri) {
                '*/organization*' {
                    [pscustomobject]@{ value = @([pscustomobject]@{ id = 't'; displayName = 'Contoso'; verifiedDomains = @(
                                    [pscustomobject]@{ name = 'contoso.com'; isDefault = $true; isInitial = $false }
                                    [pscustomobject]@{ name = 'contoso.onmicrosoft.com'; isDefault = $false; isInitial = $true }
                                )
                            })
                    }
                }
                '*/subscribedSkus*' {
                    [pscustomobject]@{ value = @([pscustomobject]@{ capabilityStatus = 'Enabled'; servicePlans = @([pscustomobject]@{ servicePlanName = 'AAD_PREMIUM'; provisioningStatus = 'Success' }) }) }
                }
                '*/admin/reportSettings*' { [pscustomobject]@{ displayConcealedNames = $true } }
                default { [pscustomobject]@{ value = @() } }
            }
        }
        Mock Get-ArgusModuleInfo -ModuleName ARGUS { [pscustomobject]@{ Name = $Name[0]; Required = $false; Installed = $true; Version = '1.0'; Purpose = '' } }
        Mock Import-Module -ModuleName ARGUS { } -ParameterFilter { $Name -in 'ExchangeOnlineManagement', 'PnP.PowerShell', 'MSCommerce' }
        Mock Get-ArgusCommercePolicy -ModuleName ARGUS { @() }
        $script:grantedScopes = $script:allScopes
    }

    It 'signs in interactively with the read-only scopes, in process scope only' {
        Connect-Argus -InformationAction SilentlyContinue
        Should -Invoke Connect-MgGraph -ModuleName ARGUS -Times 1 -Exactly -ParameterFilter {
            $ContextScope -eq 'Process' -and $NoWelcome -and 'Organization.Read.All' -in $Scopes -and -not ($Scopes | Where-Object { $_ -match 'ReadWrite' })
        }
    }

    It 'records tenant, licences and concealed names' {
        Connect-Argus -InformationAction SilentlyContinue
        InModuleScope ARGUS {
            $environment = Get-ArgusEnvironment
            $environment.ConnectedServices | Should -Be @('Graph')
            $environment.TenantName | Should -Be 'Contoso'
            $environment.TenantDefaultDomain | Should -Be 'contoso.com'
            $environment.Licenses | Should -Be @('AAD_PREMIUM')
            $environment.ConcealedReportNames | Should -BeTrue
            $environment.AuthMode | Should -Be 'Interactive (delegated)'
            $environment.Account | Should -Be 'auditor@contoso.onmicrosoft.com'
            $environment.GrantedScopes | Should -Contain 'Organization.Read.All'
        }
    }

    It 'warns when consent was not granted for some scopes' {
        $script:grantedScopes = @('Organization.Read.All')
        Connect-Argus -InformationAction SilentlyContinue -WarningVariable warnings -WarningAction SilentlyContinue
        ($warnings | Out-String) | Should -BeLike '*Consent was not granted for*LicenseAssignment.Read.All*'
    }

    It 'treats licences as unknown when they cannot be read' {
        Mock Invoke-MgGraphRequest -ModuleName ARGUS {
            if ($Uri -like '*/subscribedSkus*') { throw [System.Exception]::new('Response status code does not indicate success: Forbidden (Forbidden).') }
            [pscustomobject]@{ value = @() }
        }
        Connect-Argus -InformationAction SilentlyContinue -WarningAction SilentlyContinue
        InModuleScope ARGUS { (Get-ArgusEnvironment).Licenses | Should -BeNullOrEmpty }
        InModuleScope ARGUS { $null -eq (Get-ArgusEnvironment).Licenses | Should -BeTrue }
    }

    It 'uses certificate parameters for app-only sign-in' {
        Connect-Argus -TenantId contoso.onmicrosoft.com -ClientId 'app-id' -CertificateThumbprint 'ABCDEF' -InformationAction SilentlyContinue
        Should -Invoke Connect-MgGraph -ModuleName ARGUS -Times 1 -Exactly -ParameterFilter {
            $ClientId -eq 'app-id' -and $CertificateThumbprint -eq 'ABCDEF' -and $TenantId -eq 'contoso.onmicrosoft.com' -and -not $Scopes
        }
        InModuleScope ARGUS { (Get-ArgusEnvironment).AuthMode | Should -Be 'Certificate (app-only)' }
    }

    It 'uses the managed identity' {
        Connect-Argus -ManagedIdentity -InformationAction SilentlyContinue
        Should -Invoke Connect-MgGraph -ModuleName ARGUS -Times 1 -Exactly -ParameterFilter { $Identity }
    }

    It 'connects Exchange Online when requested, with browser sign-in instead of WAM' {
        Mock Connect-ExchangeOnline -ModuleName ARGUS { }
        Connect-Argus -Service Graph, Exchange -InformationAction SilentlyContinue
        Should -Invoke Connect-ExchangeOnline -ModuleName ARGUS -Times 1 -Exactly -ParameterFilter { $UserPrincipalName -eq 'auditor@contoso.onmicrosoft.com' -and $ShowBanner -eq $false -and $DisableWAM }
        InModuleScope ARGUS { (Get-ArgusEnvironment).ConnectedServices | Should -Be @('Graph', 'Exchange') }
    }

    It 'derives the Exchange organization from the initial domain for app-only sign-in' {
        Mock Connect-ExchangeOnline -ModuleName ARGUS { }
        Connect-Argus -Service Exchange -TenantId t -ClientId 'app-id' -CertificateThumbprint 'ABC' -InformationAction SilentlyContinue
        Should -Invoke Connect-ExchangeOnline -ModuleName ARGUS -Times 1 -Exactly -ParameterFilter { $Organization -eq 'contoso.onmicrosoft.com' -and $AppId -eq 'app-id' -and -not $DisableWAM }
    }

    It 'warns and continues when ExchangeOnlineManagement is missing' {
        Mock Get-ArgusModuleInfo -ModuleName ARGUS { [pscustomobject]@{ Name = $Name[0]; Required = $false; Installed = $false; Version = $null; Purpose = '' } }
        Mock Connect-ExchangeOnline -ModuleName ARGUS { }
        Connect-Argus -Service Exchange -InformationAction SilentlyContinue -WarningVariable warnings -WarningAction SilentlyContinue
        ($warnings | Out-String) | Should -BeLike '*ExchangeOnlineManagement is not installed*'
        Should -Invoke Connect-ExchangeOnline -ModuleName ARGUS -Times 0 -Exactly
        InModuleScope ARGUS { (Get-ArgusEnvironment).ConnectedServices | Should -Be @('Graph') }
    }

    It 'warns and continues when Exchange Online sign-in fails' {
        Mock Connect-ExchangeOnline -ModuleName ARGUS { throw 'denied' }
        Connect-Argus -Service Exchange -InformationAction SilentlyContinue -WarningVariable warnings -WarningAction SilentlyContinue
        ($warnings | Out-String) | Should -BeLike '*Exchange Online connection failed: denied*'
        InModuleScope ARGUS { (Get-ArgusEnvironment).ConnectedServices | Should -Be @('Graph') }
    }

    It 'requires -ClientId for interactive PnP sign-in' {
        Mock Connect-PnPOnline -ModuleName ARGUS { }
        Connect-Argus -Service SharePoint -InformationAction SilentlyContinue -WarningVariable warnings -WarningAction SilentlyContinue
        ($warnings | Out-String) | Should -BeLike '*needs -ClientId*'
        Should -Invoke Connect-PnPOnline -ModuleName ARGUS -Times 0 -Exactly
    }

    It 'connects PnP to the derived admin URL' {
        Mock Connect-PnPOnline -ModuleName ARGUS { }
        Connect-Argus -Service SharePoint -ClientId 'pnp-app' -InformationAction SilentlyContinue
        Should -Invoke Connect-PnPOnline -ModuleName ARGUS -Times 1 -Exactly -ParameterFilter { $Url -eq 'https://contoso-admin.sharepoint.com' -and $Interactive -and $ClientId -eq 'pnp-app' }
    }

    It 'keeps the default Graph app when -ClientId is given for PnP' {
        Mock Connect-PnPOnline -ModuleName ARGUS { }
        Connect-Argus -Service Graph, SharePoint -ClientId 'pnp-app' -InformationAction SilentlyContinue
        Should -Invoke Connect-MgGraph -ModuleName ARGUS -Times 1 -Exactly -ParameterFilter { -not $ClientId -and $Scopes }
    }

    It 'connects every available service with -Service All' {
        Mock Connect-ExchangeOnline -ModuleName ARGUS { }
        Mock Connect-PnPOnline -ModuleName ARGUS { }
        Connect-Argus -Service All -ClientId 'pnp-app' -InformationAction SilentlyContinue -WarningAction SilentlyContinue
        Should -Invoke Connect-PnPOnline -ModuleName ARGUS -Times 1 -Exactly -ParameterFilter { $ClientId -eq 'pnp-app' -and $Interactive }
        $expected = @('Graph', 'Exchange', 'SharePoint') + @(if ($IsWindows) { 'Commerce' })
        InModuleScope ARGUS -Parameters @{ Expected = $expected } { (Get-ArgusEnvironment).ConnectedServices | Should -Be $Expected }
    }

    It 'skips SharePoint with a warning when -Service All has no -ClientId' {
        Mock Connect-ExchangeOnline -ModuleName ARGUS { }
        Mock Connect-PnPOnline -ModuleName ARGUS { }
        Connect-Argus -Service All -InformationAction SilentlyContinue -WarningVariable warnings -WarningAction SilentlyContinue
        ($warnings | Out-String) | Should -BeLike '*needs -ClientId*'
        Should -Invoke Connect-PnPOnline -ModuleName ARGUS -Times 0 -Exactly
        InModuleScope ARGUS { (Get-ArgusEnvironment).ConnectedServices | Should -Contain 'Exchange' }
    }
}

Describe 'Connect-Argus -Service Commerce' {
    BeforeEach {
        InModuleScope ARGUS { $script:ArgusConnection = $null; $script:ArgusCommercePolicies = $null }
        Mock Connect-MgGraph -ModuleName ARGUS { }
        Mock Disconnect-MgGraph -ModuleName ARGUS { }
        Mock Get-MgContext -ModuleName ARGUS { [pscustomobject]@{ Account = 'auditor@contoso.onmicrosoft.com'; TenantId = 't'; Scopes = $script:allScopes; AppName = 'cli'; ClientId = 'cli' } }
        Mock Invoke-MgGraphRequest -ModuleName ARGUS { [pscustomobject]@{ value = @() } }
        Mock Get-ArgusModuleInfo -ModuleName ARGUS { [pscustomobject]@{ Name = $Name[0]; Required = $false; Installed = $true; Version = '3.0.1'; Purpose = '' } }
        Mock Get-ArgusCommercePolicy -ModuleName ARGUS { [pscustomobject]@{ ProductName = 'Microsoft Copilot'; ProductId = 'CFQ7TTC0MM8R'; PolicyValue = 'Enabled' } }
    }

    It 'reads the MSCommerce policies in a separate process on Windows and keeps them in memory' -Skip:(-not $IsWindows) {
        Connect-Argus -Service Graph, Commerce -InformationAction SilentlyContinue
        InModuleScope ARGUS {
            (Get-ArgusEnvironment).ConnectedServices | Should -Be @('Graph', 'Commerce')
            @($script:ArgusCommercePolicies).ProductId | Should -Be @('CFQ7TTC0MM8R')
        }
    }

    It 'warns and skips MSCommerce for app-only sign-in' {
        Connect-Argus -Service Commerce -TenantId t -ClientId 'app-id' -CertificateThumbprint 'ABC' -InformationAction SilentlyContinue -WarningVariable warnings -WarningAction SilentlyContinue
        ($warnings | Out-String) | Should -BeLike '*MSCommerce supports only interactive sign-in on Windows*'
        InModuleScope ARGUS { (Get-ArgusEnvironment).ConnectedServices | Should -Not -Contain 'Commerce' }
    }

    It 'warns and continues when the MSCommerce process fails' -Skip:(-not $IsWindows) {
        Mock Get-ArgusCommercePolicy -ModuleName ARGUS { throw 'the MSCommerce process ended with exit code 1' }
        Connect-Argus -Service Graph, Commerce -InformationAction SilentlyContinue -WarningVariable warnings -WarningAction SilentlyContinue
        ($warnings | Out-String) | Should -BeLike '*MSCommerce connection failed: the MSCommerce process ended*'
        InModuleScope ARGUS { (Get-ArgusEnvironment).ConnectedServices | Should -Be @('Graph') }
    }

    It 'forgets the MSCommerce policies on disconnect' {
        InModuleScope ARGUS {
            $script:ArgusCommercePolicies = @([pscustomobject]@{ ProductId = 'x' })
            $script:ArgusConnection = [pscustomobject]@{ ConnectedServices = [string[]]@('Graph', 'Commerce'); OpenedServices = [string[]]@('Graph', 'Commerce') }
        }
        Disconnect-Argus
        InModuleScope ARGUS { $script:ArgusCommercePolicies | Should -BeNullOrEmpty }
    }
}

Describe 'Disconnect-Argus' {
    It 'closes the sessions ARGUS opened and clears the state' {
        Mock Disconnect-MgGraph -ModuleName ARGUS { }
        Mock Disconnect-ExchangeOnline -ModuleName ARGUS { }
        InModuleScope ARGUS {
            $script:ArgusConnection = [pscustomobject]@{ ConnectedServices = [string[]]@('Graph', 'Exchange'); OpenedServices = [string[]]@('Graph', 'Exchange') }
            $script:ArgusDataCache = @{ Users = @(1) }
        }
        Disconnect-Argus
        Should -Invoke Disconnect-MgGraph -ModuleName ARGUS -Times 1 -Exactly
        Should -Invoke Disconnect-ExchangeOnline -ModuleName ARGUS -Times 1 -Exactly
        InModuleScope ARGUS {
            $script:ArgusConnection | Should -BeNullOrEmpty
            $script:ArgusDataCache.Count | Should -Be 0
        }
    }

    It 'keeps Graph when only Exchange is disconnected' {
        Mock Disconnect-MgGraph -ModuleName ARGUS { }
        Mock Disconnect-ExchangeOnline -ModuleName ARGUS { }
        InModuleScope ARGUS { $script:ArgusConnection = [pscustomobject]@{ ConnectedServices = [string[]]@('Graph', 'Exchange'); OpenedServices = [string[]]@('Graph', 'Exchange') } }
        Disconnect-Argus -Service Exchange
        Should -Invoke Disconnect-MgGraph -ModuleName ARGUS -Times 0 -Exactly
        InModuleScope ARGUS { $script:ArgusConnection.ConnectedServices | Should -Be @('Graph') }
    }

    It 'does nothing when no session is open' {
        Mock Disconnect-MgGraph -ModuleName ARGUS { }
        InModuleScope ARGUS { $script:ArgusConnection = $null }
        { Disconnect-Argus } | Should -Not -Throw
        Should -Invoke Disconnect-MgGraph -ModuleName ARGUS -Times 0 -Exactly
    }
}

Describe 'Get-ArgusRequiredPermission' {
    BeforeAll {
        InModuleScope ARGUS {
            $script:savedChecks = $script:ArgusBuiltInChecks
            $script:ArgusBuiltInChecks = @(
                Get-TestCheck -Override @{ Id = 'ARG.ENT.001'; Requires = @{ Services = @('Graph'); DataSets = @('Users') } }
                Get-TestCheck -Override @{ Id = 'ARG.EXO.001'; Area = 'Exchange'; Requires = @{ Services = @('Graph', 'Exchange'); GraphScopes = @('User.Read.All'); DataSets = @('Mailboxes') } }
            )
        }
    }

    AfterAll {
        InModuleScope ARGUS { $script:ArgusBuiltInChecks = $script:savedChecks }
    }

    It 'adds the data set permissions to each check' {
        $rows = @(Get-ArgusRequiredPermission)
        $rows.Count | Should -Be 2
        $entra = $rows | Where-Object CheckId -EQ 'ARG.ENT.001'
        $entra.GraphPermissions | Should -Be @('AuditLog.Read.All', 'User.Read.All')
        $entra.DirectoryRoles | Should -Contain 'Global Reader'
        $entra.ExchangePermission | Should -BeNullOrEmpty
        ($rows | Where-Object CheckId -EQ 'ARG.EXO.001').ExchangePermission | Should -BeLike '*View-Only Organization Management*'
    }

    It 'aggregates checks and core permissions' {
        $all = Get-ArgusRequiredPermission -Aggregate
        foreach ($permission in 'Organization.Read.All', 'LicenseAssignment.Read.All', 'ReportSettings.Read.All', 'User.Read.All', 'AuditLog.Read.All') {
            $all.GraphPermissions | Should -Contain $permission
        }
        $all.RecommendedRoles | Should -Be @('Global Reader', 'Reports Reader')
        $all.Services | Should -Contain 'Exchange'
    }

    It 'describes application permissions with -AsAppPermission' {
        $all = Get-ArgusRequiredPermission -Aggregate -AsAppPermission
        $all.PermissionType | Should -Be 'Application'
        $all.ExchangePermission | Should -BeLike 'Exchange.ManageAsApp*'
        @($all.DirectoryRoles).Count | Should -Be 0
    }

    It 'filters by area and id' {
        @(Get-ArgusRequiredPermission -Area Exchange).CheckId | Should -Be @('ARG.EXO.001')
        @(Get-ArgusRequiredPermission -Id 'ARG.ENT.001').CheckId | Should -Be @('ARG.ENT.001')
    }
}

Describe 'Test-ArgusPrerequisite' {
    It 'reports missing connection and the checks that would be skipped' {
        InModuleScope ARGUS { $script:ArgusConnection = $null }
        $result = Test-ArgusPrerequisite -CustomCheckPath (Join-Path $PSScriptRoot '../Fixtures/FakeChecks') -WarningVariable warnings -WarningAction SilentlyContinue
        ($warnings | Out-String) | Should -BeLike '*Not connected to Microsoft Graph*'
        $result.Connected.Count | Should -Be 0
        ($result.Checks | Where-Object Id -EQ 'ARG.EXO.905').Ready | Should -BeFalse
        ($result.Checks | Where-Object Id -EQ 'ARG.EXO.905').Reason | Should -Be 'Not connected to Exchange Online.'
        ($result.Checks | Where-Object Id -EQ 'ARG.ENT.901').Ready | Should -BeTrue
        @($result.Modules).Count | Should -Be 4
    }

    It 'lists permissions that were not granted' {
        InModuleScope ARGUS {
            $script:ArgusConnection = [pscustomobject]@{ ConnectedServices = [string[]]@('Graph'); GrantedScopes = [string[]]@('Organization.Read.All'); AuthMode = 'Certificate (app-only)' }
        }
        $result = Test-ArgusPrerequisite -WarningAction SilentlyContinue
        $result.MissingPermissions | Should -Contain 'LicenseAssignment.Read.All'
        $result.MissingPermissions | Should -Not -Contain 'Organization.Read.All'
        InModuleScope ARGUS { $script:ArgusConnection = $null }
    }
}
