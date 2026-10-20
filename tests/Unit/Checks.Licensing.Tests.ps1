#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.5.0' }

BeforeAll {
    Get-Module ARGUS | Remove-Module -Force
    Import-Module (Join-Path $PSScriptRoot '../../ARGUS/ARGUS.psd1') -Force -ErrorAction Stop
    . (Join-Path $PSScriptRoot 'TestHelpers.ps1')

    # Stub for the Exchange Online cmdlet so it can be mocked without the module installed.
    function global:Get-EXOMailboxStatistics {
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'Stub of an Exchange Online cmdlet.')]
        param([string] $Identity)
    }

    $script:e3 = '05e9a617-0261-4cee-bb44-138d3ef5d965'
    $script:e1 = '18181a46-0d4e-45cd-891e-60aabd171b4e'

    function Get-TestSku {
        param([string] $PartNumber, [string] $SkuId, [int] $Enabled, [int] $Consumed, [string] $Status = 'Enabled', [string] $AppliesTo = 'User')
        [pscustomobject]@{
            skuId = $SkuId; skuPartNumber = $PartNumber; capabilityStatus = $Status; appliesTo = $AppliesTo; consumedUnits = $Consumed
            prepaidUnits = [pscustomobject]@{ enabled = $Enabled; suspended = 0; warning = 0 }
        }
    }

    function Get-TestUser {
        param([string] $Name, [string[]] $Skus = @(), [object[]] $States = @())
        [pscustomobject]@{
            id = "id-$Name"; displayName = $Name; userPrincipalName = "$Name@contoso.com"
            assignedLicenses = @($Skus | ForEach-Object { [pscustomobject]@{ skuId = $_; disabledPlans = @() } })
            licenseAssignmentStates = $States
        }
    }

    function Get-TestState {
        param([string] $SkuId, [string] $State = 'Active', [string] $ErrorCode = 'None', [string] $Group)
        [pscustomobject]@{ skuId = $SkuId; state = $State; error = $ErrorCode; assignedByGroup = $Group; disabledPlans = @(); lastUpdatedDateTime = '2026-09-30T10:00:00Z' }
    }

    function Get-TestMailbox {
        param([string] $Name, [string] $Type = 'SharedMailbox', [string] $Archive = 'None', [bool] $Litigation = $false, [string[]] $Holds = @())
        [pscustomobject]@{
            DisplayName = $Name; UserPrincipalName = "$Name@contoso.com"; RecipientTypeDetails = $Type; ExternalDirectoryObjectId = "id-$Name"
            ArchiveStatus = $Archive; LitigationHoldEnabled = $Litigation; InPlaceHolds = $Holds
        }
    }

    # Member account with sign-in activity, for the inactivity / lifecycle checks. -DaysAgo $null = never signed in.
    function Get-ActivityUser {
        param([string] $Name, [object] $DaysAgo = 10, [hashtable] $Set = @{})
        $last = if ($null -eq $DaysAgo) { $null } else { [datetime]::new(2026, 10, 19, 0, 0, 0, [System.DateTimeKind]::Utc).AddDays(-[int]$DaysAgo).ToString('o') }
        $user = [ordered]@{
            id = "id-$Name"; displayName = $Name; userPrincipalName = "$Name@contoso.com"; userType = 'Member'; accountEnabled = $true
            createdDateTime = '2024-01-01T00:00:00Z'; assignedLicenses = @(); onPremisesSyncEnabled = $null
            signInActivity = [pscustomobject]@{ lastSuccessfulSignInDateTime = $last; lastSignInDateTime = $null; lastNonInteractiveSignInDateTime = $null }
        }
        foreach ($key in $Set.Keys) { $user[$key] = $Set[$key] }
        [pscustomobject]$user
    }

    function Invoke-LicCheck {
        param([string] $Id, [hashtable] $Data, [hashtable] $Options = @{})
        # No trial subscriptions unless a test provides them.
        if (-not $Data.ContainsKey('Subscriptions')) { $Data['Subscriptions'] = @() }
        InModuleScope ARGUS -Parameters @{ Id = $Id; Data = $Data; Options = $Options } {
            Invoke-TestCheck -Id $Id -Data $Data @Options
        }
    }
}

AfterAll {
    Get-Module ARGUS | Remove-Module -Force
    Remove-Item -Path Function:\Get-EXOMailboxStatistics -ErrorAction SilentlyContinue
}

Describe 'Licensing catalogue' {
    It 'registers the 8 Licensing checks of the specification' {
        (Get-ArgusCheck -Area Licensing).Id | Should -Be @(1..8 | ForEach-Object { 'ARG.LIC.{0:D3}' -f $_ })
    }
}

Describe 'ARG.LIC.008 Paid licences assigned directly' {
    BeforeAll {
        $script:skus4 = @(
            Get-TestSku 'SPE_E3' $script:e3 10 10
            Get-TestSku 'STANDARDPACK' $script:e1 10 10
            Get-TestSku 'POWER_BI_STANDARD' 'pbi-free' 1000000 50
            Get-TestSku 'Microsoft_365_Copilot' 'copilot' 25 3
        )
        $script:trial = @([pscustomobject]@{ skuId = 'copilot'; isTrial = $true; status = 'Enabled' })
    }

    It 'fails for paid direct licences, flags redundant ones and ignores free and trial SKUs' {
        $users = @(
            Get-TestUser 'direct' -States @(Get-TestState $script:e1)
            Get-TestUser 'both' -States @((Get-TestState $script:e3), (Get-TestState $script:e3 -Group 'grp-1'), (Get-TestState $script:e1 -Group 'grp-2'))
            Get-TestUser 'group' -States @(Get-TestState $script:e3 -Group 'grp-1')
            Get-TestUser 'freeonly' -States @((Get-TestState 'pbi-free'), (Get-TestState 'copilot'), (Get-TestState $script:e3 -Group 'grp-1'))
            Get-TestUser 'nolicence'
        )
        $result = Invoke-LicCheck 'ARG.LIC.008' @{ Users = $users; SubscribedSkus = $script:skus4; Subscriptions = $script:trial }
        $result.Status | Should -Be 'Failed'
        $result.EvaluatedCount | Should -Be 4
        $result.Findings.UserPrincipalName | Should -Be @('both@contoso.com', 'direct@contoso.com')
        $result.Findings[0].DirectLicences | Should -Be @('Microsoft 365 E3')
        $result.Findings[0].AlsoFromGroup | Should -Be @('Microsoft 365 E3')
        $result.Findings[1].DirectLicences | Should -Be @('Office 365 E1')
        @($result.Findings[1].AlsoFromGroup).Count | Should -Be 0
        $result.Summary | Should -Be '2 of 4 licensed users have paid licences assigned directly; 1 of them also receive the same licence from a group. 1 more have only free or trial licences assigned directly (not counted).'
    }

    It 'treats a SKU as paid when it has at least one non-trial subscription' {
        $users = @(Get-TestUser 'u' -States @(Get-TestState 'copilot'))
        $subscriptions = @($script:trial[0], [pscustomobject]@{ skuId = 'copilot'; isTrial = $false; status = 'Enabled' })
        (Invoke-LicCheck 'ARG.LIC.008' @{ Users = $users; SubscribedSkus = $script:skus4; Subscriptions = $subscriptions }).Status | Should -Be 'Failed'
    }

    It 'passes when every paid licence comes from a group' {
        $users = @(Get-TestUser 'group' -States @(Get-TestState $script:e3 -Group 'grp-1'))
        $result = Invoke-LicCheck 'ARG.LIC.008' @{ Users = $users; SubscribedSkus = $script:skus4 }
        $result.Status | Should -Be 'Passed'
        $result.Summary | Should -Be 'No paid licence is assigned directly (1 licensed users evaluated).'
    }
}

Describe 'ARG.LIC.001 Disabled users with licences' {
    BeforeAll {
        $script:skus5 = @(Get-TestSku 'SPE_E3' $script:e3 10 10)
        $script:licensed = @([pscustomobject]@{ skuId = $script:e3 })
        $script:disabledUsers = @(
            Get-ActivityUser 'leaver' -Set @{ accountEnabled = $false; assignedLicenses = $script:licensed }
            Get-ActivityUser 'shared' -Set @{ accountEnabled = $false; assignedLicenses = $script:licensed }
            Get-ActivityUser 'unlicensed' -Set @{ accountEnabled = $false }
        )
        $script:sharedMailboxes = @([pscustomobject]@{ RecipientTypeDetails = 'SharedMailbox'; ExternalDirectoryObjectId = 'id-shared' })
    }

    It 'fails and excludes shared mailboxes when Exchange Online is connected' {
        $result = Invoke-LicCheck 'ARG.LIC.001' @{ Users = $script:disabledUsers; SubscribedSkus = $script:skus5; Mailboxes = $script:sharedMailboxes } @{ Services = @('Graph', 'Exchange') }
        $result.Status | Should -Be 'Failed'
        $result.Findings.DisplayName | Should -Be @('leaver')
        $result.Findings[0].Licences | Should -Be @('Microsoft 365 E3')
        $result.Summary | Should -BeLike '1 of 3 disabled accounts*(1 shared, room or equipment mailboxes excluded).'
    }

    It 'returns Investigate without Exchange Online' {
        $result = Invoke-LicCheck 'ARG.LIC.001' @{ Users = $script:disabledUsers; SubscribedSkus = $script:skus5 }
        $result.Status | Should -Be 'Investigate'
        @($result.Findings).Count | Should -Be 2
        $result.Summary | Should -BeLike '*Exchange Online is not connected*'
    }

    It 'passes when no disabled account has a licence' {
        $result = Invoke-LicCheck 'ARG.LIC.001' @{ Users = @(Get-ActivityUser 'x' -Set @{ accountEnabled = $false }); SubscribedSkus = $script:skus5 }
        $result.Status | Should -Be 'Passed'
    }
}

Describe 'ARG.LIC.002 Licensed users inactive' {
    It 'lists only licensed inactive members, with licence names' {
        $licence = @([pscustomobject]@{ skuId = $script:e3 })
        $users = @(
            Get-ActivityUser 'licensed' -DaysAgo 120 -Set @{ assignedLicenses = $licence }
            Get-ActivityUser 'never' -DaysAgo $null -Set @{ assignedLicenses = $licence }
            Get-ActivityUser 'unlicensed' -DaysAgo 120
            Get-ActivityUser 'active' -DaysAgo 5 -Set @{ assignedLicenses = $licence }
        )
        $result = Invoke-LicCheck 'ARG.LIC.002' @{ Users = $users; SubscribedSkus = @(Get-TestSku 'SPE_E3' $script:e3 10 10) }
        $result.Status | Should -Be 'Failed'
        $result.EvaluatedCount | Should -Be 3
        $result.Findings.DisplayName | Should -Be @('never', 'licensed')
        $result.Findings[1].Licences | Should -Be @('Microsoft 365 E3')
        $result.Findings[0].LastSignIn | Should -Be 'Never'
        $result.Title | Should -Be 'Enabled licensed users inactive for more than 90 days'
    }

    It 'passes when licensed users are active' {
        $users = @(Get-ActivityUser 'active' -DaysAgo 5 -Set @{ assignedLicenses = @([pscustomobject]@{ skuId = $script:e3 }) })
        (Invoke-LicCheck 'ARG.LIC.002' @{ Users = $users; SubscribedSkus = @() }).Status | Should -Be 'Passed'
    }

    It 'is skipped without Entra ID P1' {
        $result = Invoke-LicCheck 'ARG.LIC.002' @{ Users = @(); SubscribedSkus = @() } @{ Licenses = @() }
        $result.Status | Should -Be 'Skipped'
    }
}

Describe 'ARG.LIC.006 Unused licences per SKU' {
    It 'fails for SKUs above the percentage or seat threshold and ignores free, disabled and tenant SKUs' {
        $skus = @(
            Get-TestSku 'SPE_E3' $script:e3 450 391                # 59 unused: fails
            Get-TestSku 'STANDARDPACK' $script:e1 200 196          # 4 unused, 2%: passes
            Get-TestSku 'VISIOCLIENT' 'visio' 3 2                  # 1 unused, 33%: fails on percentage
            Get-TestSku 'FLOW_FREE' 'flow' 10000 12                # ignored by name
            Get-TestSku 'SOME_VIRAL' 'viral' 1000000 40            # ignored by quantity
            Get-TestSku 'PROJECTPREMIUM' 'project' 50 1 -Status 'Suspended'
            Get-TestSku 'TENANT_ADDON' 'addon' 1 0 -AppliesTo 'Company'
        )
        $result = Invoke-LicCheck 'ARG.LIC.006' @{ SubscribedSkus = $skus }
        $result.Status | Should -Be 'Failed'
        $result.EvaluatedCount | Should -Be 3
        $result.Findings.SkuPartNumber | Should -Be @('SPE_E3', 'VISIOCLIENT')
        $result.Findings[0].Sku | Should -Be 'Microsoft 365 E3'
        $result.Findings[0].Unused | Should -Be 59
        $result.Findings[0].UnusedPercent | Should -Be 13.1
        $result.Summary | Should -Be '2 of 3 paid SKUs have more than 10% or more than 5 seats unused (60 unused seats in total).'
    }

    It 'passes when every SKU is within the thresholds, including over-assigned SKUs' {
        $skus = @((Get-TestSku 'SPE_E3' $script:e3 100 98), (Get-TestSku 'STANDARDPACK' $script:e1 10 12))
        $result = Invoke-LicCheck 'ARG.LIC.006' @{ SubscribedSkus = $skus }
        $result.Status | Should -Be 'Passed'
        $result.Summary | Should -Be 'All 2 paid SKUs are within 10% / 5 unused seats.'
    }

    It 'ignores trial SKUs' {
        $skus = @(Get-TestSku 'Microsoft_365_Copilot' 'copilot' 25 3)
        $trial = @([pscustomobject]@{ skuId = 'copilot'; isTrial = $true; status = 'Enabled' })
        $result = Invoke-LicCheck 'ARG.LIC.006' @{ SubscribedSkus = $skus; Subscriptions = $trial }
        $result.Status | Should -Be 'Passed'
        $result.EvaluatedCount | Should -Be 0
    }

    It 'honours IgnoredSkus overrides' {
        $skus = @(Get-TestSku 'SPE_E3' $script:e3 450 391)
        $result = Invoke-LicCheck 'ARG.LIC.006' @{ SubscribedSkus = $skus } @{ Setting = @{ Parameters = @{ IgnoredSkus = @('SPE_E3') } } }
        $result.Status | Should -Be 'Passed'
        $result.EvaluatedCount | Should -Be 0
    }
}

Describe 'ARG.LIC.005 Licence assignment errors' {
    It 'lists Error and ActiveWithError assignments with the group name' {
        $users = @(
            Get-TestUser 'anna' -States @((Get-TestState $script:e3 'Error' 'CountViolation' 'grp-1'), (Get-TestState $script:e1))
            Get-TestUser 'bob' -States @(Get-TestState $script:e1 'ActiveWithError' 'MutuallyExclusiveViolation')
            Get-TestUser 'carl' -States @(Get-TestState $script:e1)
            Get-TestUser 'nolicence'
        )
        $data = @{
            Users          = $users
            SubscribedSkus = @((Get-TestSku 'SPE_E3' $script:e3 10 10), (Get-TestSku 'STANDARDPACK' $script:e1 10 10))
            Groups         = @([pscustomobject]@{ id = 'grp-1'; displayName = 'LIC-M365-E3' })
        }
        $result = Invoke-LicCheck 'ARG.LIC.005' $data
        $result.Status | Should -Be 'Failed'
        $result.EvaluatedCount | Should -Be 3
        $result.Findings.UserPrincipalName | Should -Be @('bob@contoso.com', 'anna@contoso.com')
        $anna = $result.Findings | Where-Object UserPrincipalName -EQ 'anna@contoso.com'
        $anna.Licence | Should -Be 'Microsoft 365 E3'
        $anna.Error | Should -Be 'CountViolation'
        $anna.AssignedBy | Should -Be 'Group: LIC-M365-E3'
        $anna.LastUpdated | Should -Be '2026-09-30'
        ($result.Findings | Where-Object UserPrincipalName -EQ 'bob@contoso.com').AssignedBy | Should -Be 'Direct'
        $result.Summary | Should -Be '2 licence assignments in error on 2 of 3 licensed users.'
    }

    It 'shows the group id when groups are not available' {
        $users = @(Get-TestUser 'anna' -States @(Get-TestState $script:e3 'Error' 'CountViolation' 'grp-1'))
        $result = Invoke-LicCheck 'ARG.LIC.005' @{ Users = $users; SubscribedSkus = @() }
        $result.Findings[0].AssignedBy | Should -Be 'Group: grp-1'
    }

    It 'passes without errors' {
        $users = @(Get-TestUser 'carl' -States @(Get-TestState $script:e1))
        $result = Invoke-LicCheck 'ARG.LIC.005' @{ Users = $users; SubscribedSkus = @() }
        $result.Status | Should -Be 'Passed'
        $result.Summary | Should -Be 'No licence assignment errors (1 licensed users evaluated).'
    }
}

Describe 'ARG.LIC.007 Shared mailboxes with a licence' {
    BeforeAll {
        $script:skus = @(Get-TestSku 'STANDARDPACK' $script:e1 10 5)
        $script:users = @(
            Get-TestUser 'info' -Skus $script:e1
            Get-TestUser 'archive' -Skus $script:e1
            Get-TestUser 'hold' -Skus $script:e1
            Get-TestUser 'big' -Skus $script:e1
            Get-TestUser 'unlicensed'
            Get-TestUser 'person' -Skus $script:e1
        )
        $script:mailboxes = @(
            Get-TestMailbox 'info'
            Get-TestMailbox 'archive' -Archive 'Active'
            Get-TestMailbox 'hold' -Holds @('mbx1234')
            Get-TestMailbox 'big'
            Get-TestMailbox 'unlicensed'
            Get-TestMailbox 'person' -Type 'UserMailbox'
        )
    }

    It 'returns Investigate for licensed shared mailboxes with no size, archive or hold reason' {
        Mock -ModuleName ARGUS Get-ArgusMailboxSize { 63.4 } -ParameterFilter { $Identity -eq 'id-big' }
        Mock -ModuleName ARGUS Get-ArgusMailboxSize { 4.1 }
        $data = @{ Users = $script:users; Mailboxes = $script:mailboxes; SubscribedSkus = $script:skus }
        $result = Invoke-LicCheck 'ARG.LIC.007' $data @{ Services = @('Graph', 'Exchange') }
        $result.Status | Should -Be 'Investigate'
        $result.EvaluatedCount | Should -Be 5
        $result.Findings.DisplayName | Should -Be @('info')
        $result.Findings[0].MailboxSizeGB | Should -Be 4.1
        $result.Findings[0].Licences | Should -Be @('Office 365 E1')
        $result.Summary | Should -Be '1 of 5 shared mailboxes have a licence with no size, archive or hold that requires it (3 more are justified by size, archive or hold).'
        Should -Invoke -ModuleName ARGUS Get-ArgusMailboxSize -Times 2 -Exactly
    }

    It 'passes when every licensed shared mailbox needs its licence' {
        Mock -ModuleName ARGUS Get-ArgusMailboxSize { 80 }
        $data = @{ Users = $script:users; Mailboxes = @($script:mailboxes | Where-Object DisplayName -NE 'info'); SubscribedSkus = $script:skus }
        $result = Invoke-LicCheck 'ARG.LIC.007' $data @{ Services = @('Graph', 'Exchange') }
        $result.Status | Should -Be 'Passed'
        $result.Summary | Should -Be 'All 3 licensed shared mailboxes need their licence (size, archive or hold); 4 shared mailboxes evaluated.'
    }

    It 'is Skipped without Exchange Online' {
        $data = @{ Users = $script:users; Mailboxes = $script:mailboxes; SubscribedSkus = $script:skus }
        (Invoke-LicCheck 'ARG.LIC.007' $data).Status | Should -Be 'Skipped'
    }
}

Describe 'Get-ArgusMailboxSize' {
    It 'parses the byte count of TotalItemSize' {
        Mock -ModuleName ARGUS Get-EXOMailboxStatistics { [pscustomobject]@{ TotalItemSize = '52.37 GB (56,233,016,115 bytes)' } }
        InModuleScope ARGUS { Get-ArgusMailboxSize -Identity 'id-1' } | Should -Be 52.4
    }

    It 'returns $null when the statistics cannot be read' {
        Mock -ModuleName ARGUS Get-EXOMailboxStatistics { throw 'not found' }
        InModuleScope ARGUS { Get-ArgusMailboxSize -Identity 'id-1' } | Should -BeNullOrEmpty
    }
}

Describe 'ARG.LIC.003 Paid licences assigned to guest users' {
    BeforeAll {
        $script:free = '11111111-1111-1111-1111-111111111111'
        $script:guestSkus = @((Get-TestSku 'SPE_E3' $script:e3 100 90), (Get-TestSku 'FLOW_FREE' $script:free 10000 50))
        $guest = { param($Name, $Skus) $u = Get-TestUser $Name $Skus; $u | Add-Member userType 'Guest'; $u | Add-Member accountEnabled $true; $u }
        $script:guestUsers = @((& $guest 'paid' @($script:e3)), (& $guest 'freeonly' @($script:free)), (& $guest 'none' @()))
        $member = Get-TestUser 'member' @($script:e3); $member | Add-Member userType 'Member'
        $script:guestUsers += $member
    }

    It 'lists guests with a paid licence and ignores free SKUs' {
        $result = Invoke-LicCheck 'ARG.LIC.003' @{ Users = $script:guestUsers; SubscribedSkus = $script:guestSkus }
        $result.Status | Should -Be 'Failed'
        $result.EvaluatedCount | Should -Be 3
        $result.Findings.UserPrincipalName | Should -Be @('paid@contoso.com')
    }

    It 'passes when no guest has a paid licence' {
        (Invoke-LicCheck 'ARG.LIC.003' @{ Users = @($script:guestUsers[1], $script:guestUsers[2]); SubscribedSkus = $script:guestSkus }).Status | Should -Be 'Passed'
    }
}

Describe 'ARG.LIC.004 Users with overlapping licences' {
    BeforeAll {
        $plan = { param($Id) [pscustomobject]@{ servicePlanId = $Id; servicePlanName = "PLAN_$Id"; provisioningStatus = 'Success' } }
        $suite = Get-TestSku 'SPE_E3' $script:e3 100 50; $suite | Add-Member servicePlans @((& $plan 'p-mail'), (& $plan 'p-office'), (& $plan 'p-intune'))
        $mail = Get-TestSku 'EXCHANGESTANDARD' $script:e1 50 20; $mail | Add-Member servicePlans @((& $plan 'p-mail'))
        $other = Get-TestSku 'VISIOCLIENT' '22222222-2222-2222-2222-222222222222' 10 5; $other | Add-Member servicePlans @((& $plan 'p-visio'))
        $script:overlapSkus = @($suite, $mail, $other)
        $script:overlapUsers = @(
            (Get-TestUser 'double' @($script:e3, $script:e1))
            (Get-TestUser 'addon' @($script:e3, '22222222-2222-2222-2222-222222222222'))
            (Get-TestUser 'single' @($script:e3))
        )
    }

    It 'flags a SKU whose service plans are all included in another assigned SKU' {
        $result = Invoke-LicCheck 'ARG.LIC.004' @{ Users = $script:overlapUsers; SubscribedSkus = $script:overlapSkus }
        $result.Status | Should -Be 'Failed'
        $result.EvaluatedCount | Should -Be 2
        $result.AffectedCount | Should -Be 1
        $result.Findings.UserPrincipalName | Should -Be @('double@contoso.com')
        $result.Findings[0].RedundantLicence | Should -Match 'Exchange|EXCHANGESTANDARD'
    }

    It 'passes when add-ons are not contained in the suite' {
        (Invoke-LicCheck 'ARG.LIC.004' @{ Users = @($script:overlapUsers[1], $script:overlapUsers[2]); SubscribedSkus = $script:overlapSkus }).Status | Should -Be 'Passed'
    }
}
