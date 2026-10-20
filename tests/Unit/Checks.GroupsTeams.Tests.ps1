#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.5.0' }

BeforeAll {
    Get-Module ARGUS | Remove-Module -Force
    Import-Module (Join-Path $PSScriptRoot '../../ARGUS/ARGUS.psd1') -Force -ErrorAction Stop
    . (Join-Path $PSScriptRoot 'TestHelpers.ps1')

    # Group as returned by the Groups data set (owners expanded, flags added by the loader).
    function Get-TestGroup {
        param([string] $Name, [string] $Visibility = 'Private', [object[]] $Owners = @('owner1'), [switch] $Team, [switch] $Security, [string] $Created = '2024-01-01T00:00:00Z')
        $ownerObjects = @($Owners | ForEach-Object { [pscustomobject]@{ id = "id-$_"; displayName = $_; userPrincipalName = "$_@contoso.com"; userType = 'Member' } })
        [pscustomobject]@{
            id = "grp-$Name"; displayName = $Name; mail = "$Name@contoso.com"; visibility = $Visibility; createdDateTime = $Created
            owners = $ownerObjects; OwnerCount = $ownerObjects.Count; IsUnified = -not $Security; IsTeam = [bool]$Team; IsDynamic = $false
        }
    }

    function Get-TestSetting {
        param([hashtable] $Values)
        [pscustomobject]@{
            displayName = 'Group.Unified'; templateId = '62375ab9-6b52-47ed-826b-58e47e0e304b'
            values      = @($Values.Keys | ForEach-Object { [pscustomobject]@{ name = $_; value = $Values[$_] } })
        }
    }

    function Invoke-GroupCheck {
        param([string] $Id, [hashtable] $Data, [hashtable] $Options = @{})
        InModuleScope ARGUS -Parameters @{ Id = $Id; Data = $Data; Options = $Options } {
            Invoke-TestCheck -Id $Id -Data $Data @Options
        }
    }
}

AfterAll {
    Get-Module ARGUS | Remove-Module -Force
}

Describe 'Groups & Teams catalogue' {
    It 'registers the 8 Groups & Teams checks of the specification' {
        (Get-ArgusCheck -Area GroupsTeams).Id | Should -Be @(1..8 | ForEach-Object { 'ARG.GRP.{0:D3}' -f $_ })
    }
}

Describe 'ARG.GRP.007 Public Microsoft 365 groups' {
    It 'lists public Microsoft 365 groups only' {
        $groups = @(
            Get-TestGroup 'All Company' -Visibility Public -Team
            Get-TestGroup 'Project' -Visibility Private -Team
            Get-TestGroup 'Security' -Visibility Public -Security
            Get-TestGroup '<script>alert(1)</script>' -Visibility Public
        )
        $result = Invoke-GroupCheck 'ARG.GRP.007' @{ Groups = $groups }
        $result.Status | Should -Be 'Failed'
        $result.EvaluatedCount | Should -Be 3
        $result.Findings.DisplayName | Should -Be @('<script>alert(1)</script>', 'All Company')
        $result.Summary | Should -Be '2 of 3 Microsoft 365 groups are public (1 are Teams).'
    }

    It 'passes without public groups and honours GroupIds exclusions' {
        (Invoke-GroupCheck 'ARG.GRP.007' @{ Groups = @(Get-TestGroup 'p') }).Status | Should -Be 'Passed'
        $result = Invoke-GroupCheck 'ARG.GRP.007' @{ Groups = @(Get-TestGroup 'All' -Visibility Public) } @{ Exclusions = @{ GroupIds = @('grp-All') } }
        $result.ExcludedCount | Should -Be 1
    }
}

Describe 'ARG.GRP.004 and ARG.GRP.005 group owners' {
    BeforeAll {
        $script:ownerGroups = @(
            Get-TestGroup 'none' -Owners @() -Team
            Get-TestGroup 'single' -Owners @('alice')
            Get-TestGroup 'single-left' -Owners @('bob') -Team
            Get-TestGroup 'two' -Owners @('alice', 'carol')
            Get-TestGroup 'secgroup' -Owners @() -Security
        )
        $script:ownerUsers = @(
            [pscustomobject]@{ id = 'id-alice'; accountEnabled = $true }
            [pscustomobject]@{ id = 'id-bob'; accountEnabled = $false }
        )
    }

    It 'ARG.GRP.004 lists Microsoft 365 groups without owners' {
        $result = Invoke-GroupCheck 'ARG.GRP.004' @{ Groups = $script:ownerGroups }
        $result.Status | Should -Be 'Failed'
        $result.Findings.DisplayName | Should -Be @('none')
        $result.Summary | Should -Be '1 of 4 Microsoft 365 groups have no owner (1 are Teams).'
    }

    It 'ARG.GRP.005 lists single-owner groups, disabled owners first' {
        $result = Invoke-GroupCheck 'ARG.GRP.005' @{ Groups = $script:ownerGroups; Users = $script:ownerUsers }
        $result.Status | Should -Be 'Failed'
        $result.Findings.DisplayName | Should -Be @('single-left', 'single')
        $result.Findings[0].Owner | Should -Be 'bob@contoso.com'
        $result.Findings[0].OwnerEnabled | Should -Be 'No'
        $result.Summary | Should -Be '2 of 4 Microsoft 365 groups have exactly one owner (1 with a disabled owner).'
    }

    It 'pass when every group has two owners' {
        $groups = @(Get-TestGroup 'two' -Owners @('alice', 'carol'))
        (Invoke-GroupCheck 'ARG.GRP.004' @{ Groups = $groups }).Status | Should -Be 'Passed'
        (Invoke-GroupCheck 'ARG.GRP.005' @{ Groups = $groups; Users = @() }).Status | Should -Be 'Passed'
    }
}

Describe 'ARG.GRP.003 Group expiration policy' {
    It 'fails without a policy' {
        (Invoke-GroupCheck 'ARG.GRP.003' @{ GroupLifecyclePolicies = @() }).Status | Should -Be 'Failed'
    }

    It 'passes for All, is Investigate for Selected and fails for None' {
        $policy = { param($Scope) @([pscustomobject]@{ id = 'p'; groupLifetimeInDays = 365; managedGroupTypes = $Scope; alternateNotificationEmails = 'it@contoso.com' }) }
        $all = Invoke-GroupCheck 'ARG.GRP.003' @{ GroupLifecyclePolicies = (& $policy 'All') }
        $all.Status | Should -Be 'Passed'
        $all.Summary | Should -Be 'An expiration policy applies to all Microsoft 365 groups (lifetime 365 days).'
        (Invoke-GroupCheck 'ARG.GRP.003' @{ GroupLifecyclePolicies = (& $policy 'Selected') }).Status | Should -Be 'Investigate'
        (Invoke-GroupCheck 'ARG.GRP.003' @{ GroupLifecyclePolicies = (& $policy 'None') }).Status | Should -Be 'Failed'
    }
}

Describe 'ARG.GRP.001 Group creation' {
    It 'is Investigate when the setting was never created' {
        $result = Invoke-GroupCheck 'ARG.GRP.001' @{ GroupSettings = @() }
        $result.Status | Should -Be 'Investigate'
        $result.Summary | Should -BeLike '*not configured, so the default applies*'
    }

    It 'is Investigate when EnableGroupCreation is true and passes when false' {
        (Invoke-GroupCheck 'ARG.GRP.001' @{ GroupSettings = @(Get-TestSetting @{ EnableGroupCreation = 'true' }) }).Status | Should -Be 'Investigate'
        $result = Invoke-GroupCheck 'ARG.GRP.001' @{ GroupSettings = @(Get-TestSetting @{ EnableGroupCreation = 'false'; GroupCreationAllowedGroupId = 'grp-creators' }) }
        $result.Status | Should -Be 'Passed'
        $result.Summary | Should -BeLike '*only members of group grp-creators*'
    }
}

Describe 'ARG.GRP.002 Group naming policy' {
    It 'passes with a prefix rule or blocked words' {
        $result = Invoke-GroupCheck 'ARG.GRP.002' @{ GroupSettings = @(Get-TestSetting @{ PrefixSuffixNamingRequirement = 'GRP-[GroupName]'; CustomBlockedWordsList = 'CEO,Payroll' }) }
        $result.Status | Should -Be 'Passed'
        $result.Summary | Should -Be "A Microsoft 365 group naming policy is configured: naming rule 'GRP-[GroupName]', 2 blocked words."
    }

    It 'fails without a policy and is skipped without Entra ID P1' {
        (Invoke-GroupCheck 'ARG.GRP.002' @{ GroupSettings = @(Get-TestSetting @{ PrefixSuffixNamingRequirement = '' }) }).Status | Should -Be 'Failed'
        (Invoke-GroupCheck 'ARG.GRP.002' @{ GroupSettings = @() } @{ Licenses = @() }).Status | Should -Be 'Skipped'
    }
}

Describe 'ARG.GRP.008 Inactive Teams' {
    BeforeAll {
        $script:teamRows = @(
            [pscustomobject]@{ 'Team Name' = 'Old'; 'Team Id' = 'grp-Old'; 'Team Type' = 'Private'; 'Last Activity Date' = '2026-01-10'; Guests = '2' }
            [pscustomobject]@{ 'Team Name' = 'Silent'; 'Team Id' = 'grp-Silent'; 'Team Type' = 'Public'; 'Last Activity Date' = ''; Guests = '0' }
            [pscustomobject]@{ 'Team Name' = 'Busy'; 'Team Id' = 'grp-Busy'; 'Team Type' = 'Private'; 'Last Activity Date' = '2026-10-15'; Guests = '0' }
            [pscustomobject]@{ 'Team Name' = 'New'; 'Team Id' = 'grp-New'; 'Team Type' = 'Private'; 'Last Activity Date' = ''; Guests = '0' }
            [pscustomobject]@{ 'Team Name' = 'Deleted'; 'Team Id' = 'grp-Deleted'; 'Team Type' = 'Private'; 'Last Activity Date' = ''; Guests = '0' }
        )
        $script:teamGroups = @(
            Get-TestGroup 'Old' -Team; Get-TestGroup 'Silent' -Team; Get-TestGroup 'Busy' -Team
            Get-TestGroup 'New' -Team -Created '2026-09-01T00:00:00Z'
        )
    }

    It 'lists Teams without recent activity, ignoring new and deleted teams' {
        $result = Invoke-GroupCheck 'ARG.GRP.008' @{ TeamsActivity = $script:teamRows; ReportSettings = [pscustomobject]@{ displayConcealedNames = $false }; Groups = $script:teamGroups }
        $result.Status | Should -Be 'Failed'
        $result.EvaluatedCount | Should -Be 3
        $result.Findings.TeamName | Should -Be @('Silent', 'Old')
        $result.Findings[1].DaysInactive | Should -Be 282
        $result.Findings[1].GroupId | Should -Be 'grp-Old'
    }

    It 'is Investigate with concealed names or an empty report' {
        $concealed = Invoke-GroupCheck 'ARG.GRP.008' @{ TeamsActivity = $script:teamRows; ReportSettings = [pscustomobject]@{ displayConcealedNames = $true } }
        $concealed.Status | Should -Be 'Investigate'
        $concealed.Summary | Should -BeLike 'Usage reports return concealed names*'
        $empty = Invoke-GroupCheck 'ARG.GRP.008' @{ TeamsActivity = @(); ReportSettings = [pscustomobject]@{ displayConcealedNames = $false } }
        $empty.Status | Should -Be 'Investigate'
        $empty.Summary | Should -BeLike '*Reports Reader*'
    }
}

Describe 'ARG.GRP.006 Teams with guests and no owner' {
    It 'reads members of ownerless Teams and lists the ones with guests' {
        Mock Invoke-ArgusGraphBatch -ModuleName ARGUS {
            @(
                [pscustomobject]@{ Id = 'grp-guests'; Status = 200; Body = [pscustomobject]@{ value = @(
                            [pscustomobject]@{ id = 'u1'; userType = 'Member'; userPrincipalName = 'm@contoso.com' }
                            [pscustomobject]@{ id = 'u2'; userType = 'Guest'; userPrincipalName = 'g_fabrikam.com#EXT#@contoso.com' }
                        )
                    }
                }
                [pscustomobject]@{ Id = 'grp-members'; Status = 200; Body = [pscustomobject]@{ value = @([pscustomobject]@{ id = 'u1'; userType = 'Member'; userPrincipalName = 'm@contoso.com' }) } }
                [pscustomobject]@{ Id = 'grp-denied'; Status = 403; Body = $null }
            )
        }
        $groups = @(
            Get-TestGroup 'guests' -Owners @() -Team
            Get-TestGroup 'members' -Owners @() -Team
            Get-TestGroup 'denied' -Owners @() -Team
            Get-TestGroup 'owned' -Team
        )
        $result = Invoke-GroupCheck 'ARG.GRP.006' @{ Groups = $groups }
        $result.Status | Should -Be 'Failed'
        $result.Findings.DisplayName | Should -Be @('guests')
        $result.Findings[0].Guests | Should -Be 1
        $result.Findings[0].Members | Should -Be 2
        $result.Summary | Should -Be '1 of 4 Teams have guest members and no owner. Members of 1 ownerless Teams could not be read.'
        Should -Invoke Invoke-ArgusGraphBatch -ModuleName ARGUS -Times 1 -Exactly
    }

    It 'passes without ownerless Teams and makes no extra request' {
        Mock Invoke-ArgusGraphBatch -ModuleName ARGUS { }
        (Invoke-GroupCheck 'ARG.GRP.006' @{ Groups = @(Get-TestGroup 'owned' -Team) }).Status | Should -Be 'Passed'
        Should -Invoke Invoke-ArgusGraphBatch -ModuleName ARGUS -Times 0 -Exactly
    }
}
