#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.5.0' }

BeforeAll {
    Get-Module ARGUS | Remove-Module -Force
    Import-Module (Join-Path $PSScriptRoot '../../ARGUS/ARGUS.psd1') -Force -ErrorAction Stop
    . (Join-Path $PSScriptRoot 'TestHelpers.ps1')

    function Invoke-ExoCheck {
        param([string] $Id, [hashtable] $Data, [hashtable] $Options = @{ Services = @('Graph', 'Exchange') })
        InModuleScope ARGUS -Parameters @{ Id = $Id; Data = $Data; Options = $Options } {
            Invoke-TestCheck -Id $Id -Data $Data @Options
        }
    }
}

AfterAll {
    Get-Module ARGUS | Remove-Module -Force
}

Describe 'Exchange catalogue' {
    It 'registers the 10 Exchange checks of the specification' {
        (Get-ArgusCheck -Area Exchange).Id | Should -Be @(1..10 | ForEach-Object { 'ARG.EXO.{0:D3}' -f $_ })
    }
}

Describe 'ARG.EXO.001 Shared mailboxes with sign-in enabled' {
    BeforeAll {
        $script:exoUsers = @(
            [pscustomobject]@{ id = 'id-info'; userPrincipalName = 'info@contoso.com'; accountEnabled = $true; assignedLicenses = @() }
            [pscustomobject]@{ id = 'id-sales'; userPrincipalName = 'sales@contoso.com'; accountEnabled = $false; assignedLicenses = @() }
            [pscustomobject]@{ id = 'id-anna'; userPrincipalName = 'anna@contoso.com'; accountEnabled = $true; assignedLicenses = @() }
        )
        $script:exoMailboxes = @(
            [pscustomobject]@{ DisplayName = 'Info'; PrimarySmtpAddress = 'info@contoso.com'; RecipientTypeDetails = 'SharedMailbox'; ExternalDirectoryObjectId = 'id-info' }
            [pscustomobject]@{ DisplayName = 'Sales'; PrimarySmtpAddress = 'sales@contoso.com'; RecipientTypeDetails = 'SharedMailbox'; ExternalDirectoryObjectId = 'id-sales' }
            [pscustomobject]@{ DisplayName = 'Anna'; PrimarySmtpAddress = 'anna@contoso.com'; RecipientTypeDetails = 'UserMailbox'; ExternalDirectoryObjectId = 'id-anna'; UserPrincipalName = 'anna@contoso.com' }
        )
    }

    It 'lists shared mailboxes whose account is enabled' {
        $result = Invoke-ExoCheck 'ARG.EXO.001' @{ Users = $script:exoUsers; Mailboxes = $script:exoMailboxes }
        $result.Status | Should -Be 'Failed'
        $result.Findings.DisplayName | Should -Be @('Info')
        $result.Summary | Should -Be '1 of 2 shared mailboxes have sign-in enabled.'
    }

    It 'is Skipped without Exchange Online' {
        (Invoke-ExoCheck 'ARG.EXO.001' @{ Users = $script:exoUsers; Mailboxes = $script:exoMailboxes } @{ Services = @('Graph') }).Status | Should -Be 'Skipped'
    }
}

Describe 'ARG.EXO.009 Distribution groups without owner' {
    It 'lists groups with an empty ManagedBy' {
        $groups = @(
            [pscustomobject]@{ DisplayName = 'All Staff'; PrimarySmtpAddress = 'all@contoso.com'; RecipientTypeDetails = 'MailUniversalDistributionGroup'; ManagedBy = @(); ExternalDirectoryObjectId = 'g1' }
            [pscustomobject]@{ DisplayName = 'Finance'; PrimarySmtpAddress = 'fin@contoso.com'; RecipientTypeDetails = 'MailUniversalSecurityGroup'; ManagedBy = @('Anna'); ExternalDirectoryObjectId = 'g2' }
            [pscustomobject]@{ DisplayName = 'Events'; PrimarySmtpAddress = 'ev@contoso.com'; RecipientTypeDetails = 'MailUniversalDistributionGroup'; ManagedBy = $null; ExternalDirectoryObjectId = 'g3' }
        )
        $result = Invoke-ExoCheck 'ARG.EXO.009' @{ DistributionGroups = $groups }
        $result.Status | Should -Be 'Failed'
        $result.Findings.DisplayName | Should -Be @('All Staff', 'Events')
        $result.Findings[0].GroupId | Should -Be 'g1'
    }

    It 'passes when every group has an owner' {
        $groups = @([pscustomobject]@{ DisplayName = 'Finance'; PrimarySmtpAddress = 'fin@contoso.com'; RecipientTypeDetails = 'MailUniversalSecurityGroup'; ManagedBy = @('Anna'); ExternalDirectoryObjectId = 'g2' })
        (Invoke-ExoCheck 'ARG.EXO.009' @{ DistributionGroups = $groups }).Status | Should -Be 'Passed'
    }
}

Describe 'ARG.EXO.004 Inactive mailboxes' {
    BeforeAll {
        $row = { param($Upn, $Last, $Created = '2024-01-01') [pscustomobject]@{ 'User Principal Name' = $Upn; 'Display Name' = $Upn; 'Is Deleted' = 'False'; 'Last Activity Date' = $Last; 'Created Date' = $Created; 'Storage Used (Byte)' = '1073741824' } }
        $script:mailRows = @(
            (& $row 'anna@contoso.com' '2026-10-15')
            (& $row 'old@contoso.com' '2026-03-01')
            (& $row 'never@contoso.com' '')
            (& $row 'new@contoso.com' '' '2026-10-01')
            (& $row 'info@contoso.com' '')
        )
        $script:mailMailboxes = @('anna', 'old', 'never', 'new' | ForEach-Object { [pscustomobject]@{ UserPrincipalName = "$_@contoso.com"; RecipientTypeDetails = 'UserMailbox' } }) +
        @([pscustomobject]@{ UserPrincipalName = 'info@contoso.com'; RecipientTypeDetails = 'SharedMailbox' })
        $script:visible = [pscustomobject]@{ displayConcealedNames = $false }
    }

    It 'lists inactive user mailboxes when Exchange Online is connected' {
        $result = Invoke-ExoCheck 'ARG.EXO.004' @{ MailboxUsage = $script:mailRows; ReportSettings = $script:visible; Mailboxes = $script:mailMailboxes }
        $result.Status | Should -Be 'Failed'
        $result.EvaluatedCount | Should -Be 3
        $result.Findings.UserPrincipalName | Should -Be @('never@contoso.com', 'old@contoso.com')
        $result.Findings[1].DaysInactive | Should -Be 232
        $result.Summary | Should -Be '2 of 3 mailboxes have had no activity for 90+ days.'
    }

    It 'includes all mailboxes with a note without Exchange Online' {
        $result = Invoke-ExoCheck 'ARG.EXO.004' @{ MailboxUsage = $script:mailRows; ReportSettings = $script:visible } @{ Services = @('Graph') }
        $result.Findings.UserPrincipalName | Should -Be @('info@contoso.com', 'never@contoso.com', 'old@contoso.com')
        $result.Summary | Should -BeLike '*shared mailboxes could not be excluded.'
    }
}

Describe 'ARG.EXO.006 Mailboxes near their quota' {
    BeforeAll {
        $row = { param($Upn, [double] $UsedGB, [double] $QuotaGB, $Deleted = 'False') [pscustomobject]@{ 'User Principal Name' = $Upn; 'Display Name' = $Upn; 'Is Deleted' = $Deleted; 'Storage Used (Byte)' = [string]($UsedGB * 1GB); 'Prohibit Send Quota (Byte)' = [string]($QuotaGB * 1GB); 'Has Archive' = 'False' } }
        $script:quotaRows = @(
            (& $row 'full@contoso.com' 48 49.5)
            (& $row 'half@contoso.com' 20 49.5)
            (& $row 'gone@contoso.com' 49 49.5 'True')
            (& $row 'noquota@contoso.com' 10 0)
        )
        $script:visible = [pscustomobject]@{ displayConcealedNames = $false }
    }

    It 'lists mailboxes above the quota threshold' {
        $result = Invoke-ExoCheck 'ARG.EXO.006' @{ MailboxUsage = $script:quotaRows; ReportSettings = $script:visible } @{ Services = @('Graph') }
        $result.Status | Should -Be 'Failed'
        $result.EvaluatedCount | Should -Be 2
        $result.Findings.UserPrincipalName | Should -Be @('full@contoso.com')
        $result.Findings[0].PercentOfWarning | Should -Be 97
    }

    It 'passes when every mailbox is below the threshold' {
        (Invoke-ExoCheck 'ARG.EXO.006' @{ MailboxUsage = @($script:quotaRows[1]); ReportSettings = $script:visible } @{ Services = @('Graph') }).Status | Should -Be 'Passed'
    }
}

Describe 'ARG.EXO.005 User mailboxes of disabled accounts' {
    BeforeAll {
        $script:leaverUsers = @(
            [pscustomobject]@{ id = 'u-active'; accountEnabled = $true; assignedLicenses = @() }
            [pscustomobject]@{ id = 'u-left'; accountEnabled = $false; assignedLicenses = @([pscustomobject]@{ skuId = 's1' }) }
            [pscustomobject]@{ id = 'u-held'; accountEnabled = $false; assignedLicenses = @() }
            [pscustomobject]@{ id = 'u-shared'; accountEnabled = $false; assignedLicenses = @() }
        )
        $mailbox = { param($Id, $Type = 'UserMailbox', [bool] $Hold = $false) [pscustomobject]@{ DisplayName = $Id; UserPrincipalName = "$Id@contoso.com"; PrimarySmtpAddress = "$Id@contoso.com"; RecipientTypeDetails = $Type; ExternalDirectoryObjectId = $Id; ArchiveStatus = 'None'; LitigationHoldEnabled = $Hold; InPlaceHolds = @() } }
        $script:leaverMailboxes = @((& $mailbox 'u-active'), (& $mailbox 'u-left'), (& $mailbox 'u-held' 'UserMailbox' $true), (& $mailbox 'u-shared' 'SharedMailbox'))
    }

    It 'lists user mailboxes of disabled accounts that are not on hold' {
        $result = Invoke-ExoCheck 'ARG.EXO.005' @{ Users = $script:leaverUsers; Mailboxes = $script:leaverMailboxes }
        $result.Status | Should -Be 'Failed'
        $result.EvaluatedCount | Should -Be 3
        $result.Findings.ObjectId | Should -Be @('u-left')
        $result.Findings[0].Licensed | Should -Be 'Yes'
        $result.Summary | Should -BeLike '*1 more on hold are kept on purpose.'
    }

    It 'passes when every disabled account with a user mailbox is on hold' {
        $mailboxes = @($script:leaverMailboxes[0], $script:leaverMailboxes[2])
        (Invoke-ExoCheck 'ARG.EXO.005' @{ Users = $script:leaverUsers; Mailboxes = $mailboxes }).Status | Should -Be 'Passed'
    }
}

Describe 'ARG.EXO.002 Shared mailboxes without delegates' {
    BeforeAll {
        $script:sharedBoxes = @('sm-info', 'sm-orphan' | ForEach-Object { [pscustomobject]@{ DisplayName = $_; UserPrincipalName = "$_@contoso.com"; PrimarySmtpAddress = "$_@contoso.com"; RecipientTypeDetails = 'SharedMailbox'; ExternalDirectoryObjectId = $_ } }) +
        @([pscustomobject]@{ DisplayName = 'anna'; UserPrincipalName = 'anna@contoso.com'; PrimarySmtpAddress = 'anna@contoso.com'; RecipientTypeDetails = 'UserMailbox'; ExternalDirectoryObjectId = 'u-anna' })
    }

    It 'lists shared mailboxes without FullAccess delegates' {
        $result = Invoke-ExoCheck 'ARG.EXO.002' @{ Mailboxes = $script:sharedBoxes; SharedMailboxPermissions = @{ 'sm-info' = @('anna@contoso.com'); 'sm-orphan' = @() } }
        $result.Status | Should -Be 'Failed'
        $result.EvaluatedCount | Should -Be 2
        $result.Findings.ObjectId | Should -Be @('sm-orphan')
    }

    It 'passes when every shared mailbox has a delegate' {
        $permissions = @{ 'sm-info' = @('anna@contoso.com'); 'sm-orphan' = @('bob@contoso.com') }
        (Invoke-ExoCheck 'ARG.EXO.002' @{ Mailboxes = $script:sharedBoxes; SharedMailboxPermissions = $permissions }).Status | Should -Be 'Passed'
    }
}

Describe 'ARG.EXO.010 Empty distribution groups' {
    BeforeAll {
        $script:dlGroups = @('dl-full', 'dl-empty', 'dl-unknown' | ForEach-Object { [pscustomobject]@{ DisplayName = $_; PrimarySmtpAddress = "$_@contoso.com"; RecipientTypeDetails = 'MailUniversalDistributionGroup'; ManagedBy = @('Anna'); ExternalDirectoryObjectId = $_ } })
    }

    It 'lists groups without members and leaves unreadable groups out' {
        $result = Invoke-ExoCheck 'ARG.EXO.010' @{ DistributionGroups = $script:dlGroups; DistributionGroupMembers = @{ 'dl-full' = $true; 'dl-empty' = $false; 'dl-unknown' = $null } }
        $result.Status | Should -Be 'Failed'
        $result.EvaluatedCount | Should -Be 2
        $result.Findings.GroupId | Should -Be @('dl-empty')
        $result.Findings[0].ManagedBy | Should -Be 'Anna'
    }

    It 'passes when every group has members' {
        (Invoke-ExoCheck 'ARG.EXO.010' @{ DistributionGroups = @($script:dlGroups[0]); DistributionGroupMembers = @{ 'dl-full' = $true } }).Status | Should -Be 'Passed'
    }
}

Describe 'ARG.EXO.003 Inactive shared mailboxes' {
    BeforeAll {
        $row = { param($Upn, $Last, $Created = '2024-01-01') [pscustomobject]@{ 'User Principal Name' = $Upn; 'Display Name' = $Upn; 'Is Deleted' = 'False'; 'Last Activity Date' = $Last; 'Created Date' = $Created; 'Storage Used (Byte)' = '1073741824' } }
        $script:sharedRows = @(
            (& $row 'info@contoso.com' '2026-10-10')
            (& $row 'project@contoso.com' '2026-02-01')
            (& $row 'fresh@contoso.com' '' '2026-10-01')
            (& $row 'anna@contoso.com' '')
        )
        $script:sharedList = @('info', 'project', 'fresh' | ForEach-Object { [pscustomobject]@{ UserPrincipalName = "$_@contoso.com"; PrimarySmtpAddress = "$_@contoso.com"; RecipientTypeDetails = 'SharedMailbox'; ExternalDirectoryObjectId = "id-$_" } }) +
        @([pscustomobject]@{ UserPrincipalName = 'anna@contoso.com'; PrimarySmtpAddress = 'anna@contoso.com'; RecipientTypeDetails = 'UserMailbox'; ExternalDirectoryObjectId = 'id-anna' })
        $script:visible = [pscustomobject]@{ displayConcealedNames = $false }
    }

    It 'lists inactive shared mailboxes only' {
        $result = Invoke-ExoCheck 'ARG.EXO.003' @{ MailboxUsage = $script:sharedRows; ReportSettings = $script:visible; Mailboxes = $script:sharedList }
        $result.Status | Should -Be 'Failed'
        $result.EvaluatedCount | Should -Be 2
        $result.Findings.ObjectId | Should -Be @('id-project')
    }

    It 'passes when every shared mailbox is active' {
        (Invoke-ExoCheck 'ARG.EXO.003' @{ MailboxUsage = @($script:sharedRows[0]); ReportSettings = $script:visible; Mailboxes = $script:sharedList }).Status | Should -Be 'Passed'
    }

    It 'is skipped without Exchange Online' {
        (Invoke-ExoCheck 'ARG.EXO.003' @{ MailboxUsage = $script:sharedRows; ReportSettings = $script:visible } @{ Services = @('Graph') }).Status | Should -Be 'Skipped'
    }
}

Describe 'ARG.EXO.006 warning quota and mailbox type' {
    It 'uses the warning quota and shows the mailbox type' {
        $rows = @(
            [pscustomobject]@{ 'User Principal Name' = 'info@contoso.com'; 'Display Name' = 'Info'; 'Is Deleted' = 'False'; 'Storage Used (Byte)' = [string](46GB); 'Issue Warning Quota (Byte)' = [string](49GB); 'Prohibit Send Quota (Byte)' = [string](49.5GB); 'Has Archive' = 'False' }
            [pscustomobject]@{ 'User Principal Name' = 'anna@contoso.com'; 'Display Name' = 'Anna'; 'Is Deleted' = 'False'; 'Storage Used (Byte)' = [string](40GB); 'Issue Warning Quota (Byte)' = [string](49GB); 'Prohibit Send Quota (Byte)' = [string](49.5GB); 'Has Archive' = 'True' }
        )
        $mailboxes = @([pscustomobject]@{ UserPrincipalName = 'info@contoso.com'; RecipientTypeDetails = 'SharedMailbox' }, [pscustomobject]@{ UserPrincipalName = 'anna@contoso.com'; RecipientTypeDetails = 'UserMailbox' })
        $result = Invoke-ExoCheck 'ARG.EXO.006' @{ MailboxUsage = $rows; ReportSettings = [pscustomobject]@{ displayConcealedNames = $false }; Mailboxes = $mailboxes }
        $result.Status | Should -Be 'Failed'
        $result.Findings.UserPrincipalName | Should -Be @('info@contoso.com')
        $result.Findings[0].MailboxType | Should -Be 'SharedMailbox'
        $result.Findings[0].PercentOfWarning | Should -Be 93.9
        $result.Summary | Should -BeLike '*(1 shared).'
    }
}

Describe 'ARG.EXO.007 Mailboxes with forwarding configured' {
    BeforeAll {
        $mbx = { param($Name, $Smtp = $null, $Address = $null, [bool] $Keep = $false) [pscustomobject]@{ DisplayName = $Name; PrimarySmtpAddress = "$Name@contoso.com"; RecipientTypeDetails = 'UserMailbox'; ExternalDirectoryObjectId = "id-$Name"; ForwardingSmtpAddress = $Smtp; ForwardingAddress = $Address; DeliverToMailboxAndForward = $Keep } }
        $script:fwdMailboxes = @(
            (& $mbx 'leaver' 'smtp:leaver@gmail.example' $null $true)
            (& $mbx 'sales' 'smtp:team@contoso.com')
            (& $mbx 'desk' $null 'Helpdesk Contact')
            (& $mbx 'plain')
        )
        $script:org = [pscustomobject]@{ verifiedDomains = @([pscustomobject]@{ name = 'contoso.com' }, [pscustomobject]@{ name = 'contoso.onmicrosoft.com' }) }
    }

    It 'lists forwarding with external targets first' {
        $result = Invoke-ExoCheck 'ARG.EXO.007' @{ Mailboxes = $script:fwdMailboxes; Organization = $script:org }
        $result.Status | Should -Be 'Investigate'
        $result.EvaluatedCount | Should -Be 4
        $result.Findings.DisplayName | Should -Be @('leaver', 'desk', 'sales')
        $result.Findings[0].Target | Should -Be 'External'
        $result.Findings[0].KeepsCopy | Should -BeTrue
        ($result.Findings | Where-Object DisplayName -EQ 'desk').Target | Should -Be 'Directory recipient'
        $result.Summary | Should -BeLike '*(1 to external addresses)*'
    }

    It 'passes without forwarding' {
        (Invoke-ExoCheck 'ARG.EXO.007' @{ Mailboxes = @($script:fwdMailboxes[3]); Organization = $script:org }).Status | Should -Be 'Passed'
    }
}

Describe 'ARG.EXO.008 User mailboxes without a mailbox hold' {
    BeforeAll {
        $mbx = { param($Name, [bool] $Lit = $false, $Holds = @(), $Type = 'UserMailbox') [pscustomobject]@{ DisplayName = $Name; UserPrincipalName = "$Name@contoso.com"; PrimarySmtpAddress = "$Name@contoso.com"; RecipientTypeDetails = $Type; ExternalDirectoryObjectId = "id-$Name"; ArchiveStatus = 'None'; LitigationHoldEnabled = $Lit; InPlaceHolds = $Holds } }
        $script:holdMailboxes = @((& $mbx 'held' $true), (& $mbx 'policy' $false @('mbx1234')), (& $mbx 'open'), (& $mbx 'shared' $false @() 'SharedMailbox'))
    }

    It 'asks for review of user mailboxes without any hold' {
        $result = Invoke-ExoCheck 'ARG.EXO.008' @{ Mailboxes = $script:holdMailboxes }
        $result.Status | Should -Be 'Investigate'
        $result.EvaluatedCount | Should -Be 3
        $result.Findings.UserPrincipalName | Should -Be @('open@contoso.com')
        $result.Summary | Should -BeLike '2 of 3 user mailboxes have a mailbox hold; 1 have none*'
    }

    It 'passes when every user mailbox has a hold' {
        (Invoke-ExoCheck 'ARG.EXO.008' @{ Mailboxes = @($script:holdMailboxes[0], $script:holdMailboxes[1]) }).Status | Should -Be 'Passed'
    }

    It 'does not change the score (Info)' {
        (Get-ArgusCheck -Id 'ARG.EXO.008').Severity | Should -Be 'Info'
    }
}
