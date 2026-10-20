#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.5.0' }

BeforeAll {
    Get-Module ARGUS | Remove-Module -Force
    Import-Module (Join-Path $PSScriptRoot '../../ARGUS/ARGUS.psd1') -Force -ErrorAction Stop
    . (Join-Path $PSScriptRoot 'TestHelpers.ps1')

    function Invoke-CopilotCheck {
        param([string] $Id, [hashtable] $Data = @{}, [hashtable] $Options = @{})
        InModuleScope ARGUS -Parameters @{ Id = $Id; Data = $Data; Options = $Options } {
            Invoke-TestCheck -Id $Id -Data $Data @Options
        }
    }

    $script:visible = [pscustomobject]@{ displayConcealedNames = $false }
}

AfterAll {
    Get-Module ARGUS | Remove-Module -Force
}

Describe 'Copilot catalogue' {
    It 'registers the 12 Copilot checks of the specification' {
        (Get-ArgusCheck -Area Copilot).Id | Should -Be @(1..12 | ForEach-Object { 'ARG.COP.{0:D3}' -f $_ })
    }

    It 'keeps the manual-review checks at Info severity so they never change the score' {
        (Get-ArgusCheck -Area Copilot | Where-Object Tags -Contains 'Manual').Id | Should -Be @('ARG.COP.004', 'ARG.COP.005', 'ARG.COP.008', 'ARG.COP.010')
        Get-ArgusCheck -Area Copilot | Where-Object Tags -Contains 'Manual' | ForEach-Object { $_.Severity | Should -Be 'Info' }
    }

    It 'marks the checks that use beta endpoints' {
        (Get-ArgusCheck -Area Copilot | Where-Object UsesBeta).Id | Should -Be @('ARG.COP.006', 'ARG.COP.007', 'ARG.COP.009')
    }
}

Describe 'ARG.COP.009 Users can register agent identity blueprints' {
    It 'fails when every user can register blueprints' {
        $policy = [pscustomobject]@{ defaultUserRolePermissions = [pscustomobject]@{ allowedToCreateApps = $false; allowedToCreateAgentIdentityBlueprints = $true } }
        $result = Invoke-CopilotCheck 'ARG.COP.009' @{ AuthorizationPolicyBeta = $policy }
        $result.Status | Should -Be 'Failed'
        $result.Summary | Should -Match 'allowedToCreateAgentIdentityBlueprints = true'
    }

    It 'passes when blueprint registration is restricted' {
        $policy = [pscustomobject]@{ defaultUserRolePermissions = [pscustomobject]@{ allowedToCreateAgentIdentityBlueprints = $false } }
        (Invoke-CopilotCheck 'ARG.COP.009' @{ AuthorizationPolicyBeta = $policy }).Status | Should -Be 'Passed'
    }

    It 'is skipped when the tenant does not return the property yet' {
        $policy = [pscustomobject]@{ defaultUserRolePermissions = [pscustomobject]@{ allowedToCreateApps = $true } }
        $result = Invoke-CopilotCheck 'ARG.COP.009' @{ AuthorizationPolicyBeta = $policy }
        $result.Status | Should -Be 'Skipped'
        $result.SkipReason | Should -Match 'November 2026'
    }

    It 'is skipped when the beta policy cannot be read' {
        $result = Invoke-CopilotCheck 'ARG.COP.009' @{ AuthorizationPolicyBeta = [pscustomobject]@{ ArgusUnavailable = 'No access (403).' } }
        $result.Status | Should -Be 'Skipped'
        $result.SkipReason | Should -Be 'No access (403).'
    }
}

Describe 'ARG.COP.001 Self-service purchase of Copilot products' {
    It 'fails for Copilot products that allow purchases or trials' {
        $policies = @(
            [pscustomobject]@{ ProductName = 'Microsoft Copilot'; ProductId = 'CFQ7TTC0MM8R'; PolicyValue = 'Enabled' }
            [pscustomobject]@{ ProductName = 'Copilot Studio'; ProductId = 'CFQ7TTC0AAAA'; PolicyValue = 'OnlyTrialsWithoutPaymentMethod' }
            [pscustomobject]@{ ProductName = 'Microsoft 365 Copilot Business'; ProductId = 'CFQ7TTC0BBBB'; PolicyValue = 'Disabled' }
            [pscustomobject]@{ ProductName = 'Power BI Pro'; ProductId = 'CFQ7TTC0H9MP'; PolicyValue = 'Enabled' }
        )
        $result = Invoke-CopilotCheck 'ARG.COP.001' @{ CommercePolicies = $policies } @{ Services = @('Graph', 'Commerce') }
        $result.Status | Should -Be 'Failed'
        $result.EvaluatedCount | Should -Be 3
        $result.Findings.ProductName | Should -Be @('Copilot Studio', 'Microsoft Copilot')
        $result.Findings[0].Allows | Should -Be 'Trials without payment method'
        $result.Summary | Should -Be '2 of 3 Copilot products allow self-service purchases or trials.'
    }

    It 'passes when every Copilot product is disabled' {
        $policies = @([pscustomobject]@{ ProductName = 'Microsoft Copilot'; ProductId = 'CFQ7TTC0MM8R'; PolicyValue = 'Disabled' })
        (Invoke-CopilotCheck 'ARG.COP.001' @{ CommercePolicies = $policies } @{ Services = @('Graph', 'Commerce') }).Status | Should -Be 'Passed'
    }

    It 'is skipped without the MSCommerce connection' {
        $result = Invoke-CopilotCheck 'ARG.COP.001' @{ CommercePolicies = @() }
        $result.Status | Should -Be 'Skipped'
        $result.SkipReason | Should -BeLike '*MSCommerce*'
    }

    It 'asks for review when no Copilot product is listed' {
        $policies = @([pscustomobject]@{ ProductName = 'Power BI Pro'; ProductId = 'X'; PolicyValue = 'Enabled' })
        (Invoke-CopilotCheck 'ARG.COP.001' @{ CommercePolicies = $policies } @{ Services = @('Graph', 'Commerce') }).Status | Should -Be 'Investigate'
    }
}

Describe 'ARG.COP.002 Self-service trial sign-up' {
    It 'fails when users can sign up for email-based subscriptions' {
        $policy = [pscustomobject]@{ allowedToSignUpEmailBasedSubscriptions = $true; allowEmailVerifiedUsersToJoinOrganization = $false }
        $result = Invoke-CopilotCheck 'ARG.COP.002' @{ AuthorizationPolicy = $policy }
        $result.Status | Should -Be 'Failed'
        $result.Findings[0].Value | Should -Be 'True'
    }

    It 'passes when self-service sign-up is off' {
        $policy = [pscustomobject]@{ allowedToSignUpEmailBasedSubscriptions = $false }
        (Invoke-CopilotCheck 'ARG.COP.002' @{ AuthorizationPolicy = $policy }).Status | Should -Be 'Passed'
    }
}

Describe 'Manual Copilot reviews (ARG.COP.004, 005, 008, 010)' {
    It 'states the opt-in default for an EU tenant' {
        $result = Invoke-CopilotCheck 'ARG.COP.004' @{ Organization = [pscustomobject]@{ countryLetterCode = 'IT' } }
        $result.Status | Should -Be 'Investigate'
        $result.Findings[0].Default | Should -BeLike 'Off (No users)*IT*'
    }

    It 'states the on-by-default for a tenant outside the EU, EFTA and UK' {
        $result = Invoke-CopilotCheck 'ARG.COP.004' @{ Organization = [pscustomobject]@{ countryLetterCode = 'US' } }
        $result.Findings[0].Default | Should -BeLike 'On for all users*US*'
        $result.Summary | Should -BeLike '*On for all users*'
    }

    It 'treats the UK and EFTA as opt-in regions' {
        foreach ($country in 'GB', 'CH', 'NO') {
            (Invoke-CopilotCheck 'ARG.COP.004' @{ Organization = [pscustomobject]@{ countryLetterCode = $country } }).Findings[0].Default | Should -BeLike 'Off*'
        }
    }

    It 'returns To review with the settings to verify: <Id>' -ForEach @(
        @{ Id = 'ARG.COP.005'; Rows = 1 }
        @{ Id = 'ARG.COP.008'; Rows = 3 }
        @{ Id = 'ARG.COP.010'; Rows = 1 }
    ) {
        $result = Invoke-CopilotCheck $Id
        $result.Status | Should -Be 'Investigate'
        @($result.Findings).Count | Should -Be $Rows
        $result.Findings | ForEach-Object { $_.Location | Should -Not -BeNullOrEmpty; $_.Recommended | Should -Not -BeNullOrEmpty }
    }

    It 'does not change the score' {
        InModuleScope ARGUS {
            $results = @(
                [pscustomobject]@{ Area = 'Copilot'; Severity = 'Info'; Status = 'Investigate' }
                [pscustomobject]@{ Area = 'Copilot'; Severity = 'Medium'; Status = 'Passed' }
            )
            (Get-ArgusScore -Result $results -Scoring (Get-ArgusConfig).Scoring).Score | Should -Be 100
        }
    }
}

Describe 'ARG.COP.006 Web search in Copilot' {
    It 'asks for review when the policy is not configured' {
        $result = Invoke-CopilotCheck 'ARG.COP.006' @{ CopilotWebSearchPolicy = [pscustomobject]@{ id = 'microsoft.copilot.allowwebsearch'; value = $null; policyId = $null } }
        $result.Status | Should -Be 'Investigate'
        $result.Findings[0].Value | Should -Be 'Not configured'
        $result.Summary | Should -BeLike '*EU Data Boundary*'
    }

    It 'asks for review of a configured value that was not declared as disabled' {
        $result = Invoke-CopilotCheck 'ARG.COP.006' @{ CopilotWebSearchPolicy = [pscustomobject]@{ value = '1'; policyId = 'p1' } }
        $result.Status | Should -Be 'Investigate'
        $result.Findings[0].PolicyId | Should -Be 'p1'
    }

    It 'passes when the configured value is listed in DisabledValues' {
        $setting = @{ Parameters = @{ DisabledValues = @('0') } }
        $result = Invoke-CopilotCheck 'ARG.COP.006' @{ CopilotWebSearchPolicy = [pscustomobject]@{ value = '0'; policyId = 'p1' } } @{ Setting = $setting }
        $result.Status | Should -Be 'Passed'
    }

    It 'is skipped when the setting cannot be read' {
        $result = Invoke-CopilotCheck 'ARG.COP.006' @{ CopilotWebSearchPolicy = [pscustomobject]@{ ArgusUnavailable = 'Denied (403).' } }
        $result.Status | Should -Be 'Skipped'
        $result.SkipReason | Should -Be 'Denied (403).'
    }

    It 'asks for review of a group-scoped policy' {
        (Invoke-CopilotCheck 'ARG.COP.006' @{ CopilotWebSearchPolicy = [pscustomobject]@{ GroupScoped = $true; value = $null; policyId = $null } }).Summary | Should -BeLike '*group-scoped*'
    }
}

Describe 'ARG.COP.007 Enhanced personalization' {
    It 'asks for review when it is on for everybody' {
        $result = Invoke-CopilotCheck 'ARG.COP.007' @{ CopilotPersonalization = [pscustomobject]@{ isEnabledInOrganization = $true; disabledForGroup = $null } }
        $result.Status | Should -Be 'Investigate'
    }

    It 'passes when it is off or a group is excluded' {
        (Invoke-CopilotCheck 'ARG.COP.007' @{ CopilotPersonalization = [pscustomobject]@{ isEnabledInOrganization = $false } }).Status | Should -Be 'Passed'
        $result = Invoke-CopilotCheck 'ARG.COP.007' @{ CopilotPersonalization = [pscustomobject]@{ isEnabledInOrganization = $true; disabledForGroup = 'grp-1' } }
        $result.Status | Should -Be 'Passed'
        $result.Summary | Should -BeLike '*grp-1*'
    }
}

Describe 'ARG.COP.003 Unused Copilot licences' {
    BeforeAll {
        $row = { param($Upn, $Last) [pscustomobject]@{ 'User Principal Name' = $Upn; 'Display Name' = $Upn; 'Last Activity Date' = $Last; 'Copilot Chat Last Activity Date' = $Last } }
        $script:copilotRows = @(
            (& $row 'active@contoso.com' '2026-10-12')
            (& $row 'idle@contoso.com' '2026-08-01')
            (& $row 'never@contoso.com' '')
        )
    }

    It 'lists licensed users without recent Copilot activity' {
        $result = Invoke-CopilotCheck 'ARG.COP.003' @{ CopilotUsage = $script:copilotRows; ReportSettings = $script:visible } @{ Licenses = @('M365_COPILOT_APPS') }
        $result.Status | Should -Be 'Failed'
        $result.Findings.UserPrincipalName | Should -Be @('never@contoso.com', 'idle@contoso.com')
        $result.Findings[1].DaysInactive | Should -Be 79
        $result.Summary | Should -Be '2 of 3 users with a Copilot licence have not used Copilot for more than 30 days.'
    }

    It 'passes when every licensed user is active' {
        $rows = @($script:copilotRows[0])
        (Invoke-CopilotCheck 'ARG.COP.003' @{ CopilotUsage = $rows; ReportSettings = $script:visible } @{ Licenses = @('M365_COPILOT_APPS') }).Status | Should -Be 'Passed'
    }

    It 'is skipped without a Microsoft 365 Copilot licence' {
        $result = Invoke-CopilotCheck 'ARG.COP.003' @{ CopilotUsage = @(); ReportSettings = $script:visible } @{ Licenses = @() }
        $result.Status | Should -Be 'Skipped'
        $result.SkipReason | Should -BeLike 'Microsoft 365 Copilot licence (M365_COPILOT_APPS) not detected*'
    }

    It 'asks for review with concealed report names' {
        $concealed = [pscustomobject]@{ displayConcealedNames = $true }
        (Invoke-CopilotCheck 'ARG.COP.003' @{ CopilotUsage = $script:copilotRows; ReportSettings = $concealed } @{ Licenses = @('M365_COPILOT_APPS') }).Status | Should -Be 'Investigate'
    }
}

Describe 'Agent catalogue checks (ARG.COP.011-012)' {
    BeforeAll {
        $package = {
            param($Name, $Type, $Available, [bool] $Blocked = $false, $Modified = '2026-10-01T00:00:00Z', $Request = $null)
            [pscustomobject]@{ id = "P_$Name"; displayName = $Name; type = $Type; availableTo = $Available; deployedTo = 'none'; isBlocked = $Blocked; publisher = "$Name Inc"; supportedHosts = @('Copilot'); lastModifiedDateTime = $Modified; requestType = $Request; requestStatus = if ($Request) { 'pending' } else { $null } }
        }
        $script:catalog = [pscustomobject]@{
            Packages        = @(
                (& $package 'Northwind' 'external' 'allowedForAll')
                (& $package 'Fabrikam' 'external' 'all')
                (& $package 'Blocked' 'external' 'allowedForAll' $true)
                (& $package 'Scoped' 'external' 'allowedForSome')
                (& $package 'HR Agent' 'custom' 'allowedForAll')
            )
            PendingRequests = @(
                (& $package 'Old request' 'custom' 'allowedForNone' $false '2026-09-01T00:00:00Z' 'publish')
                (& $package 'New request' 'custom' 'allowedForNone' $false '2026-10-17T00:00:00Z' 'access')
            )
        }
    }

    It 'lists external agents available to all users' {
        $result = Invoke-CopilotCheck 'ARG.COP.011' @{ CopilotPackages = $script:catalog } @{ Licenses = @('AGENT_365') }
        $result.Status | Should -Be 'Investigate'
        $result.EvaluatedCount | Should -Be 4
        $result.Findings.DisplayName | Should -Be @('Fabrikam', 'Northwind')
    }

    It 'passes without external agents open to everybody' {
        $catalog = [pscustomobject]@{ Packages = @($script:catalog.Packages[3], $script:catalog.Packages[4]); PendingRequests = @() }
        (Invoke-CopilotCheck 'ARG.COP.011' @{ CopilotPackages = $catalog } @{ Licenses = @('AGENT_365') }).Status | Should -Be 'Passed'
    }

    It 'fails for requests pending longer than the threshold' {
        $result = Invoke-CopilotCheck 'ARG.COP.012' @{ CopilotPackages = $script:catalog } @{ Licenses = @('AGENT_365') }
        $result.Status | Should -Be 'Failed'
        $result.Findings.DisplayName | Should -Be @('Old request')
        $result.Findings[0].RequestType | Should -Be 'publish'
        $result.Summary | Should -Be '1 of 2 pending agent requests are older than 7 days.'
    }

    It 'passes when no request is overdue' {
        $catalog = [pscustomobject]@{ Packages = @(); PendingRequests = @($script:catalog.PendingRequests[1]) }
        (Invoke-CopilotCheck 'ARG.COP.012' @{ CopilotPackages = $catalog } @{ Licenses = @('AGENT_365') }).Status | Should -Be 'Passed'
    }

    It 'is skipped without an Agent 365 licence: <Id>' -ForEach @(@{ Id = 'ARG.COP.011' }, @{ Id = 'ARG.COP.012' }) {
        $result = Invoke-CopilotCheck $Id @{ CopilotPackages = $script:catalog } @{ Licenses = @() }
        $result.Status | Should -Be 'Skipped'
        $result.SkipReason | Should -BeLike 'Agent 365 licence (AGENT_365) not detected*'
    }

    It 'is skipped when the catalogue cannot be read' {
        $result = Invoke-CopilotCheck 'ARG.COP.011' @{ CopilotPackages = [pscustomobject]@{ ArgusUnavailable = 'No access (403).' } } @{ Licenses = @('AGENT_365') }
        $result.Status | Should -Be 'Skipped'
        $result.SkipReason | Should -Be 'No access (403).'
    }
}
