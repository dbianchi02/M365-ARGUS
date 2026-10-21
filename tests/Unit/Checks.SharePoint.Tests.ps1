#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.5.0' }

BeforeAll {
    Get-Module ARGUS | Remove-Module -Force
    Import-Module (Join-Path $PSScriptRoot '../../ARGUS/ARGUS.psd1') -Force -ErrorAction Stop
    . (Join-Path $PSScriptRoot 'TestHelpers.ps1')

    $script:visible = [pscustomobject]@{ displayConcealedNames = $false }
    $script:org = [pscustomobject]@{ verifiedDomains = @([pscustomobject]@{ name = 'contoso.onmicrosoft.com'; isInitial = $true }, [pscustomobject]@{ name = 'contoso.com'; isInitial = $false }) }

    function Get-SiteRow {
        param([string] $Name, [string] $LastActivity = '2026-10-01', [double] $UsedGB = 1, [double] $AllocatedGB = 25, [string] $Deleted = 'False')
        [pscustomobject]@{
            'Site URL' = "https://contoso.sharepoint.com/sites/$Name"; 'Is Deleted' = $Deleted; 'Last Activity Date' = $LastActivity; 'File Count' = '10'
            'Storage Used (Byte)' = [string]($UsedGB * 1GB); 'Storage Allocated (Byte)' = [string]($AllocatedGB * 1GB); 'Root Web Template' = 'Team Site'
            'Owner Principal Name' = "owner-$Name@contoso.com"
        }
    }

    function Invoke-SiteCheck {
        param([string] $Id, [hashtable] $Data, [hashtable] $Options = @{})
        InModuleScope ARGUS -Parameters @{ Id = $Id; Data = $Data; Options = $Options } {
            Invoke-TestCheck -Id $Id -Data $Data @Options
        }
    }
}

AfterAll {
    Get-Module ARGUS | Remove-Module -Force
}

Describe 'SharePoint catalogue' {
    It 'registers the 13 SharePoint checks of the specification' {
        (Get-ArgusCheck -Area SharePoint).Id | Should -Be @(1..13 | ForEach-Object { 'ARG.SPO.{0:D3}' -f $_ })
    }
}

Describe 'ARG.SPO.008 Orphaned sites' {
    BeforeAll {
        $script:spoGroups = @(
            [pscustomobject]@{ id = 'grp-orphan'; displayName = 'Orphan'; IsUnified = $true; IsTeam = $true; OwnerCount = 0 }
            [pscustomobject]@{ id = 'grp-nosite'; displayName = 'No site'; IsUnified = $true; IsTeam = $false; OwnerCount = 0 }
            [pscustomobject]@{ id = 'grp-owned'; displayName = 'Owned'; IsUnified = $true; IsTeam = $false; OwnerCount = 2 }
        )
        $script:pnpSites = @(
            [pscustomobject]@{ Url = 'https://contoso.sharepoint.com/sites/intranet'; Title = 'Intranet'; Template = 'SITEPAGEPUBLISHING#0'; Owner = 'left@contoso.com'; GroupId = [guid]::Empty }
            [pscustomobject]@{ Url = 'https://contoso.sharepoint.com/sites/legacy'; Title = 'Legacy'; Template = 'STS#0'; Owner = ''; GroupId = [guid]::Empty }
            [pscustomobject]@{ Url = 'https://contoso.sharepoint.com/sites/hr'; Title = 'HR'; Template = 'STS#3'; Owner = 'alice@contoso.com'; GroupId = [guid]::Empty }
            [pscustomobject]@{ Url = 'https://contoso.sharepoint.com/sites/old'; Title = 'Old'; Template = 'STS#3'; Owner = 'gone@contoso.com'; GroupId = [guid]::Empty }
            [pscustomobject]@{ Url = 'https://contoso.sharepoint.com/sites/orphan'; Title = 'Orphan'; Template = 'GROUP#0'; Owner = ''; GroupId = [guid]::NewGuid() }
            [pscustomobject]@{ Url = 'https://contoso-my.sharepoint.com'; Title = 'My'; Template = 'SPSMSITEHOST#0'; Owner = ''; GroupId = [guid]::Empty }
        )
        $script:spoUsers = @(
            [pscustomobject]@{ id = 'id-alice'; userPrincipalName = 'alice@contoso.com'; accountEnabled = $true }
            [pscustomobject]@{ id = 'id-left'; userPrincipalName = 'left@contoso.com'; accountEnabled = $false }
        )
    }

    BeforeEach {
        Mock Invoke-ArgusGraphBatch -ModuleName ARGUS {
            @(
                [pscustomobject]@{ Id = 'grp-orphan'; Status = 200; Body = [pscustomobject]@{ webUrl = 'https://contoso.sharepoint.com/sites/orphan'; displayName = 'Orphan' } }
                [pscustomobject]@{ Id = 'grp-nosite'; Status = 404; Body = $null }
            )
        }
    }

    It 'reports group sites of ownerless groups and classic sites without a valid administrator' {
        $result = Invoke-SiteCheck 'ARG.SPO.008' @{ Groups = $script:spoGroups; SharePointSites = $script:pnpSites; Users = $script:spoUsers } @{ Services = @('Graph', 'SharePoint') }
        $result.Status | Should -Be 'Failed'
        $result.EvaluatedCount | Should -Be 7
        # Sorted by Type ("Site without group (<template>)" before "Team site (Teams)"), then URL.
        $result.Findings.SiteUrl | Should -Be @(
            'https://contoso.sharepoint.com/sites/intranet'
            'https://contoso.sharepoint.com/sites/legacy'
            'https://contoso.sharepoint.com/sites/old'
            'https://contoso.sharepoint.com/sites/orphan'
        )
        ($result.Findings | Where-Object SiteUrl -Like '*legacy').Reason | Should -Be 'No primary site collection administrator'
        ($result.Findings | Where-Object SiteUrl -Like '*old').Reason | Should -Be 'Primary administrator no longer exists'
        ($result.Findings | Where-Object SiteUrl -Like '*intranet').Reason | Should -Be 'Primary administrator is disabled'
        $result.Summary | Should -Be '4 of 7 sites have no responsible owner.'
    }

    It 'notes that sites without a group were not evaluated when PnP is not connected' {
        $result = Invoke-SiteCheck 'ARG.SPO.008' @{ Groups = $script:spoGroups; SharePointSites = $script:pnpSites }
        $result.Findings.SiteUrl | Should -Be @('https://contoso.sharepoint.com/sites/orphan')
        $result.Summary | Should -BeLike '*Sites without a Microsoft 365 group were not evaluated*'
    }

    It 'honours SiteUrls exclusions' {
        $result = Invoke-SiteCheck 'ARG.SPO.008' @{ Groups = $script:spoGroups } @{ Exclusions = @{ SiteUrls = @('https://contoso.sharepoint.com/sites/orphan') } }
        @($result.Findings).Count | Should -Be 0
        $result.ExcludedCount | Should -Be 1
    }
}

Describe 'ARG.SPO.009 Inactive sites' {
    It 'lists sites without activity in the threshold, ignoring deleted sites' {
        $rows = @(
            Get-SiteRow 'busy' -LastActivity '2026-10-10'
            Get-SiteRow 'old' -LastActivity '2025-12-01'
            Get-SiteRow 'never' -LastActivity ''
            Get-SiteRow 'gone' -LastActivity '' -Deleted 'True'
        )
        $result = Invoke-SiteCheck 'ARG.SPO.009' @{ SharePointSiteUsage = $rows; ReportSettings = $script:visible }
        $result.Status | Should -Be 'Failed'
        $result.EvaluatedCount | Should -Be 3
        $result.Findings.SiteUrl | Should -Be @('https://contoso.sharepoint.com/sites/never', 'https://contoso.sharepoint.com/sites/old')
        $result.Findings[1].DaysInactive | Should -Be 322
    }

    It 'is Investigate with concealed names' {
        (Invoke-SiteCheck 'ARG.SPO.009' @{ SharePointSiteUsage = @(Get-SiteRow 'a'); ReportSettings = [pscustomobject]@{ displayConcealedNames = $true } }).Status | Should -Be 'Investigate'
    }
}

Describe 'ARG.SPO.002 External sharing level' {
    It 'is Investigate for Anyone links and passes for guest sharing' {
        $anyone = Invoke-SiteCheck 'ARG.SPO.002' @{ SharePointTenantSettings = [pscustomobject]@{ sharingCapability = 'externalUserAndGuestSharing'; sharingDomainRestrictionMode = 'none' } }
        $anyone.Status | Should -Be 'Investigate'
        $anyone.Findings[0].Level | Should -Be 'Anyone (links without sign-in)'
        $guests = Invoke-SiteCheck 'ARG.SPO.002' @{ SharePointTenantSettings = [pscustomobject]@{ sharingCapability = 'externalUserSharingOnly' } }
        $guests.Status | Should -Be 'Passed'
        $guests.Summary | Should -Be 'External sharing at organisation level: New and existing guests.'
    }
}

Describe 'ARG.SPO.010 Sites near quota' {
    It 'lists sites above 90 percent of their quota' {
        $rows = @((Get-SiteRow 'full' -UsedGB 24 -AllocatedGB 25), (Get-SiteRow 'ok' -UsedGB 5 -AllocatedGB 25), (Get-SiteRow 'noquota' -UsedGB 5 -AllocatedGB 0))
        $result = Invoke-SiteCheck 'ARG.SPO.010' @{ SharePointSiteUsage = $rows; ReportSettings = $script:visible }
        $result.Status | Should -Be 'Failed'
        $result.EvaluatedCount | Should -Be 2
        $result.Findings[0].UsedPercent | Should -Be 96
    }

    It 'passes when every site has room' {
        (Invoke-SiteCheck 'ARG.SPO.010' @{ SharePointSiteUsage = @(Get-SiteRow 'ok'); ReportSettings = $script:visible }).Status | Should -Be 'Passed'
    }
}

Describe 'ARG.SPO.012 OneDrive of disabled or deleted users' {
    It 'lists OneDrives with content whose owner is disabled or deleted' {
        $row = { param($Upn, $Bytes) [pscustomobject]@{ 'Owner Principal Name' = $Upn; 'Owner Display Name' = $Upn; 'Storage Used (Byte)' = $Bytes; 'Is Deleted' = 'False'; 'File Count' = '3'; 'Last Activity Date' = '2026-01-01'; 'Site URL' = "https://contoso-my.sharepoint.com/personal/$Upn" } }
        $rows = @((& $row 'active@contoso.com' '100'), (& $row 'disabled@contoso.com' '2147483648'), (& $row 'deleted@contoso.com' '100'), (& $row 'empty@contoso.com' '0'))
        $users = @(
            [pscustomobject]@{ userPrincipalName = 'active@contoso.com'; accountEnabled = $true }
            [pscustomobject]@{ userPrincipalName = 'disabled@contoso.com'; accountEnabled = $false }
        )
        $result = Invoke-SiteCheck 'ARG.SPO.012' @{ OneDriveUsage = $rows; ReportSettings = $script:visible; Users = $users; Organization = $script:org }
        $result.Status | Should -Be 'Failed'
        $result.Findings.UserPrincipalName | Should -Be @('disabled@contoso.com', 'deleted@contoso.com')
        $result.Findings[0].OwnerState | Should -Be 'Disabled'
        $result.Findings[0].StorageUsedGB | Should -Be 2
        $result.Findings[1].OwnerState | Should -Be 'Deleted or not found'
    }
}

Describe 'SharePoint tenant settings checks (ARG.SPO.001, ARG.SPO.011)' {
    It 'asks for review when users can create sites' {
        $result = Invoke-SiteCheck 'ARG.SPO.001' @{ SharePointTenantSettings = [pscustomobject]@{ isSiteCreationEnabled = $true; isSiteCreationUIEnabled = $true } }
        $result.Status | Should -Be 'Investigate'
        $result.Findings[0].CreateCommandsShown | Should -Be $true
    }

    It 'passes when site creation is restricted' {
        (Invoke-SiteCheck 'ARG.SPO.001' @{ SharePointTenantSettings = [pscustomobject]@{ isSiteCreationEnabled = $false } }).Status | Should -Be 'Passed'
    }

    It 'fails when deleted OneDrives are kept for less than the minimum' {
        $result = Invoke-SiteCheck 'ARG.SPO.011' @{ SharePointTenantSettings = [pscustomobject]@{ deletedUserPersonalSiteRetentionPeriodInDays = 30 } }
        $result.Status | Should -Be 'Failed'
        $result.Summary | Should -Be 'The OneDrive of a deleted user is kept for 30 days, less than 90.'
    }

    It 'passes with a long enough OneDrive retention' {
        (Invoke-SiteCheck 'ARG.SPO.011' @{ SharePointTenantSettings = [pscustomobject]@{ deletedUserPersonalSiteRetentionPeriodInDays = 365 } }).Status | Should -Be 'Passed'
    }
}

Describe 'PnP sharing checks (ARG.SPO.003-006)' {
    BeforeAll {
        $script:anyone = [pscustomobject]@{ sharingCapability = 'externalUserAndGuestSharing' }
        $script:guests = [pscustomobject]@{ sharingCapability = 'externalUserSharingOnly' }
        $script:pnp = @{ Services = @('Graph', 'SharePoint') }
    }

    It 'fails when guest access never expires' {
        $tenant = [pscustomobject]@{ ExternalUserExpirationRequired = $false; ExternalUserExpireInDays = 60 }
        (Invoke-SiteCheck 'ARG.SPO.005' @{ SharePointTenantSettings = $script:guests; SharePointTenant = $tenant } $script:pnp).Status | Should -Be 'Failed'
    }

    It 'passes when guest access expires, or when external sharing is off' {
        $tenant = [pscustomobject]@{ ExternalUserExpirationRequired = $true; ExternalUserExpireInDays = 90 }
        (Invoke-SiteCheck 'ARG.SPO.005' @{ SharePointTenantSettings = $script:guests; SharePointTenant = $tenant } $script:pnp).Summary | Should -BeLike '*90 days*'
        $off = [pscustomobject]@{ sharingCapability = 'disabled' }
        (Invoke-SiteCheck 'ARG.SPO.005' @{ SharePointTenantSettings = $off; SharePointTenant = $null } $script:pnp).Status | Should -Be 'Passed'
    }

    It 'is skipped without PnP.PowerShell' {
        (Invoke-SiteCheck 'ARG.SPO.005' @{ SharePointTenantSettings = $script:guests; SharePointTenant = $null }).Status | Should -Be 'Skipped'
    }

    It 'fails for Anyone links that never expire or expire too late' {
        foreach ($days in 0, 365) {
            $tenant = [pscustomobject]@{ RequireAnonymousLinksExpireInDays = $days }
            (Invoke-SiteCheck 'ARG.SPO.004' @{ SharePointTenantSettings = $script:anyone; SharePointTenant = $tenant } $script:pnp).Status | Should -Be 'Failed'
        }
    }

    It 'passes for short-lived Anyone links, or when Anyone links are not allowed' {
        $tenant = [pscustomobject]@{ RequireAnonymousLinksExpireInDays = 14 }
        (Invoke-SiteCheck 'ARG.SPO.004' @{ SharePointTenantSettings = $script:anyone; SharePointTenant = $tenant } $script:pnp).Status | Should -Be 'Passed'
        (Invoke-SiteCheck 'ARG.SPO.004' @{ SharePointTenantSettings = $script:guests; SharePointTenant = $tenant } $script:pnp).Status | Should -Be 'Passed'
    }

    It 'rates the default sharing link: <Expected> for <Core>/<OneDrive>/<Legacy>' -ForEach @(
        @{ Core = 'Anyone'; OneDrive = 'SpecificPeople'; Legacy = 'Direct'; Expected = 'Failed' }
        @{ Core = 'Uninitialized'; OneDrive = 'Uninitialized'; Legacy = 'Internal'; Expected = 'Investigate' }
        @{ Core = 'Uninitialized'; OneDrive = 'Uninitialized'; Legacy = 'None'; Expected = 'Investigate' }
        @{ Core = 'SpecificPeople'; OneDrive = 'Uninitialized'; Legacy = 'Direct'; Expected = 'Passed' }
    ) {
        $tenant = [pscustomobject]@{ CoreDefaultShareLinkScope = $Core; OneDriveDefaultShareLinkScope = $OneDrive; DefaultSharingLinkType = $Legacy; DefaultLinkPermission = 'Edit' }
        (Invoke-SiteCheck 'ARG.SPO.003' @{ SharePointTenant = $tenant } $script:pnp).Status | Should -Be $Expected
    }

    It 'lists sites that allow Anyone links' {
        $sites = @(
            [pscustomobject]@{ Url = 'https://contoso.sharepoint.com/sites/press'; Title = 'Press'; Template = 'SITEPAGEPUBLISHING#0'; Owner = 'anna@contoso.com'; SharingCapability = 'ExternalUserAndGuestSharing'; LastContentModifiedDate = '2026-10-01' }
            [pscustomobject]@{ Url = 'https://contoso.sharepoint.com/sites/hr'; Title = 'HR'; Template = 'STS#3'; Owner = 'bob@contoso.com'; SharingCapability = 'Disabled'; LastContentModifiedDate = '2026-10-01' }
        )
        $result = Invoke-SiteCheck 'ARG.SPO.006' @{ SharePointTenantSettings = $script:anyone; SharePointSites = $sites } $script:pnp
        $result.Status | Should -Be 'Investigate'
        $result.Findings.SiteUrl | Should -Be @('https://contoso.sharepoint.com/sites/press')
        (Invoke-SiteCheck 'ARG.SPO.006' @{ SharePointTenantSettings = $script:anyone; SharePointSites = @($sites[1]) } $script:pnp).Status | Should -Be 'Passed'
    }
}

Describe 'ARG.SPO.013 OneDrives near their quota' {
    BeforeAll {
        $row = { param($Upn, [double] $UsedGB, [double] $AllocatedGB) [pscustomobject]@{ 'Owner Principal Name' = $Upn; 'Owner Display Name' = $Upn; 'Is Deleted' = 'False'; 'Storage Used (Byte)' = [string]($UsedGB * 1GB); 'Storage Allocated (Byte)' = [string]($AllocatedGB * 1GB); 'Site URL' = "https://contoso-my.sharepoint.com/personal/$Upn" } }
        $script:odRows = @((& $row 'full' 990 1024), (& $row 'light' 10 1024))
    }

    It 'lists OneDrives above the quota threshold' {
        $result = Invoke-SiteCheck 'ARG.SPO.013' @{ OneDriveUsage = $script:odRows; ReportSettings = $script:visible; Users = @(); Organization = $script:org }
        $result.Status | Should -Be 'Failed'
        $result.Findings.UserPrincipalName | Should -Be @('full')
    }

    It 'passes when every OneDrive is below the threshold' {
        (Invoke-SiteCheck 'ARG.SPO.013' @{ OneDriveUsage = @($script:odRows[1]); ReportSettings = $script:visible; Users = @(); Organization = $script:org }).Status | Should -Be 'Passed'
    }
}

Describe 'ARG.SPO.007 Sites without a sensitivity label' {
    BeforeAll {
        $site = { param($Name, $Label = '', $Template = 'STS#3') [pscustomobject]@{ Url = "https://contoso.sharepoint.com/sites/$Name"; Title = $Name; Template = $Template; Owner = 'anna@contoso.com'; SensitivityLabel = $Label; LastContentModifiedDate = '2026-10-01' } }
        $script:labelSites = @((& $site 'hr' 'a1b2c3d4-0000-4000-8000-000000000001'), (& $site 'project'), (& $site 'my' '' 'SPSPERS#10'))
        $script:pnpOnly = @{ Services = @('Graph', 'SharePoint') }
    }

    It 'fails for unlabelled sites when labels are in use' {
        $result = Invoke-SiteCheck 'ARG.SPO.007' @{ SharePointSites = $script:labelSites } $script:pnpOnly
        $result.Status | Should -Be 'Failed'
        $result.EvaluatedCount | Should -Be 2
        $result.Findings.SiteUrl | Should -Be @('https://contoso.sharepoint.com/sites/project')
    }

    It 'asks for review when no site has a label' {
        (Invoke-SiteCheck 'ARG.SPO.007' @{ SharePointSites = @($script:labelSites[1]) } $script:pnpOnly).Status | Should -Be 'Investigate'
    }

    It 'passes when every site is labelled' {
        (Invoke-SiteCheck 'ARG.SPO.007' @{ SharePointSites = @($script:labelSites[0]) } $script:pnpOnly).Status | Should -Be 'Passed'
    }
}

Describe 'Site URL resolution when the usage reports leave it empty' {
    It 'reads site URLs from the Site Id, skips system sites and reports missing owners (ARG.SPO.009)' {
        Mock Invoke-ArgusGraphBatch -ModuleName ARGUS { @([pscustomobject]@{ Id = 'aaaa1111-0000-4000-8000-000000000001'; Status = 200; Body = [pscustomobject]@{ webUrl = 'https://contoso.sharepoint.com/sites/old' } }) }
        $row = { param($Id, $Template, $Owner) [pscustomobject]@{ 'Site Id' = $Id; 'Site URL' = ''; 'Is Deleted' = 'False'; 'Last Activity Date' = '2025-01-01'; 'File Count' = '1'; 'Storage Used (Byte)' = '0'; 'Root Web Template' = $Template; 'Owner Principal Name' = $Owner; 'Owner Display Name' = '' } }
        $rows = @((& $row 'AAAA1111-0000-4000-8000-000000000001' 'Team Site' ''), (& $row 'bbbb2222-0000-4000-8000-000000000002' 'Basic Search Center' ''))
        $result = Invoke-SiteCheck 'ARG.SPO.009' @{ SharePointSiteUsage = $rows; ReportSettings = $script:visible }
        $result.EvaluatedCount | Should -Be 1
        $result.Findings.SiteUrl | Should -Be @('https://contoso.sharepoint.com/sites/old')
        $result.Findings[0].Owner | Should -Be 'Not reported'
        Should -Invoke Invoke-ArgusGraphBatch -ModuleName ARGUS -Times 1 -Exactly -ParameterFilter { @($Request).Count -eq 1 -and $Request[0].Url -eq '/sites/aaaa1111-0000-4000-8000-000000000001?$select=webUrl' }
    }

    It 'reads private group site URLs from the PnP tenant site list before Graph (ARG.SPO.009)' {
        Mock Invoke-ArgusGraphBatch -ModuleName ARGUS { @([pscustomobject]@{ Id = 'cccc3333-0000-4000-8000-000000000003'; Status = 200; Body = [pscustomobject]@{ webUrl = 'https://contoso.sharepoint.com/sites/public' } }) }
        $row = { param($Id) [pscustomobject]@{ 'Site Id' = $Id; 'Site URL' = ''; 'Is Deleted' = 'False'; 'Last Activity Date' = '2025-01-01'; 'File Count' = '1'; 'Storage Used (Byte)' = '0'; 'Root Web Template' = 'Group'; 'Owner Principal Name' = 'team@contoso.com' } }
        $rows = @((& $row 'aaaa1111-0000-4000-8000-000000000001'), (& $row 'cccc3333-0000-4000-8000-000000000003'))
        $pnp = @([pscustomobject]@{ Url = 'https://contoso.sharepoint.com/sites/private'; SiteId = [guid]'AAAA1111-0000-4000-8000-000000000001'; Template = 'GROUP#0' })
        $result = Invoke-SiteCheck 'ARG.SPO.009' @{ SharePointSiteUsage = $rows; ReportSettings = $script:visible; SharePointSites = $pnp } @{ Services = @('Graph', 'SharePoint') }
        ($result.Findings | Where-Object SiteId -EQ 'aaaa1111-0000-4000-8000-000000000001').SiteUrl | Should -Be 'https://contoso.sharepoint.com/sites/private'
        ($result.Findings | Where-Object SiteId -EQ 'cccc3333-0000-4000-8000-000000000003').SiteUrl | Should -Be 'https://contoso.sharepoint.com/sites/public'
        Should -Invoke Invoke-ArgusGraphBatch -ModuleName ARGUS -Times 1 -Exactly -ParameterFilter { @($Request).Count -eq 1 -and $Request[0].Id -eq 'cccc3333-0000-4000-8000-000000000003' }
        $result.Summary | Should -Not -BeLike '*could not be read*'
    }

    It 'notes the sites whose URL Graph cannot read when PnP is not connected (ARG.SPO.009, ARG.SPO.010)' {
        Mock Invoke-ArgusGraphBatch -ModuleName ARGUS { @([pscustomobject]@{ Id = 'aaaa1111-0000-4000-8000-000000000001'; Status = 403; Body = $null }) }
        $row = [pscustomobject]@{ 'Site Id' = 'aaaa1111-0000-4000-8000-000000000001'; 'Site URL' = ''; 'Is Deleted' = 'False'; 'Last Activity Date' = '2025-01-01'; 'File Count' = '1'; 'Storage Used (Byte)' = [string](24GB); 'Storage Allocated (Byte)' = [string](25GB); 'Root Web Template' = 'Group'; 'Owner Principal Name' = 'team@contoso.com' }
        foreach ($id in 'ARG.SPO.009', 'ARG.SPO.010') {
            $result = Invoke-SiteCheck $id @{ SharePointSiteUsage = @($row); ReportSettings = $script:visible }
            $result.Status | Should -Be 'Failed'
            $result.Findings[0].SiteUrl | Should -BeNullOrEmpty
            $result.Summary | Should -BeLike '*The URL of 1 site(s) could not be read: private group and channel sites need the SharePoint (PnP) connection.'
        }
    }

    It 'reads OneDrive URLs from mySite and derives them for deleted users (ARG.SPO.012)' {
        Mock Invoke-ArgusGraphBatch -ModuleName ARGUS { @([pscustomobject]@{ Id = 'id-left'; Status = 200; Body = [pscustomobject]@{ mySite = 'https://contoso-my.sharepoint.com/personal/left_contoso_com/' } }) }
        $row = { param($Upn) [pscustomobject]@{ 'Owner Principal Name' = $Upn; 'Owner Display Name' = $Upn; 'Storage Used (Byte)' = '100'; 'Is Deleted' = 'False'; 'File Count' = '3'; 'Last Activity Date' = '2026-01-01'; 'Site URL' = '' } }
        $users = @([pscustomobject]@{ id = 'id-left'; userPrincipalName = 'left@contoso.com'; accountEnabled = $false })
        $result = Invoke-SiteCheck 'ARG.SPO.012' @{ OneDriveUsage = @((& $row 'left@contoso.com'), (& $row 'Mario.Rossi@contoso.com')); ReportSettings = $script:visible; Users = $users; Organization = $script:org }
        ($result.Findings | Where-Object UserPrincipalName -EQ 'left@contoso.com').SiteUrl | Should -Be 'https://contoso-my.sharepoint.com/personal/left_contoso_com'
        ($result.Findings | Where-Object UserPrincipalName -EQ 'left@contoso.com').UrlSource | Should -Be 'User mySite'
        $deleted = $result.Findings | Where-Object UserPrincipalName -EQ 'Mario.Rossi@contoso.com'
        $deleted.SiteUrl | Should -Be 'https://contoso-my.sharepoint.com/personal/mario_rossi_contoso_com'
        $deleted.UrlSource | Should -Be 'Derived from the UPN'
    }
}