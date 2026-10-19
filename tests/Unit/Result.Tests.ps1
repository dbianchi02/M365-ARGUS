#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.5.0' }

BeforeAll {
    Get-Module ARGUS | Remove-Module -Force
    Import-Module (Join-Path $PSScriptRoot '../../ARGUS/ARGUS.psd1') -Force -ErrorAction Stop
}

AfterAll {
    Get-Module ARGUS | Remove-Module -Force
}

Describe 'New-ArgusResult' {
    It 'supports every status' -ForEach @('Passed', 'Failed', 'Investigate', 'NotRun') {
        InModuleScope ARGUS -Parameters @{ Status = $_ } {
            (New-ArgusResult -Status $Status).Status | Should -Be $Status
        }
    }

    It 'requires a reason for Skipped' {
        InModuleScope ARGUS {
            { New-ArgusResult -Status Skipped } | Should -Throw '*requires -SkipReason*'
            (New-ArgusResult -Status Skipped -SkipReason 'No P1').SkipReason | Should -Be 'No P1'
        }
    }

    It 'requires a message for Error' {
        InModuleScope ARGUS {
            { New-ArgusResult -Status Error } | Should -Throw '*requires -ErrorMessage*'
            (New-ArgusResult -Status Error -ErrorMessage 'boom').ErrorMessage | Should -Be 'boom'
        }
    }

    It 'rejects an unknown status' {
        InModuleScope ARGUS {
            { New-ArgusResult -Status Warning } | Should -Throw
        }
    }

    It 'defaults AffectedCount and FindingColumns from the findings' {
        InModuleScope ARGUS {
            $findings = @(
                [pscustomobject]@{ UserPrincipalName = 'a@contoso.com'; LastSignIn = $null }
                [pscustomobject]@{ UserPrincipalName = 'b@contoso.com'; LastSignIn = $null }
            )
            $result = New-ArgusResult -Status Failed -Findings $findings
            $result.AffectedCount | Should -Be 2
            $result.FindingColumns | Should -Be @('UserPrincipalName', 'LastSignIn')
            $result.EvaluatedCount | Should -BeNullOrEmpty
            $result.PSObject.TypeNames | Should -Contain 'Argus.Result'
        }
    }

    It 'keeps explicit counts and columns' {
        InModuleScope ARGUS {
            $result = New-ArgusResult -Status Failed -AffectedCount 5 -EvaluatedCount 100 -Findings @([pscustomobject]@{ A = 1; B = 2 }) -FindingColumns 'B', 'A'
            $result.AffectedCount | Should -Be 5
            $result.EvaluatedCount | Should -Be 100
            $result.FindingColumns | Should -Be @('B', 'A')
        }
    }

    It 'returns an empty findings array when there are none' {
        InModuleScope ARGUS {
            $result = New-ArgusResult -Status Passed
            @($result.Findings).Count | Should -Be 0
            $result.AffectedCount | Should -Be 0
        }
    }
}

Describe 'Resolve-ArgusTemplate' {
    It 'replaces placeholders and formats numbers with thousands separators' {
        InModuleScope ARGUS {
            Resolve-ArgusTemplate -Template '{AffectedCount} of {EvaluatedCount} users inactive for {InactiveDays}+ days.' `
                -Values @{ AffectedCount = 37; EvaluatedCount = 1204; InactiveDays = 90 } |
                Should -Be '37 of 1,204 users inactive for 90+ days.'
        }
    }

    It 'leaves unknown placeholders untouched' {
        InModuleScope ARGUS {
            Resolve-ArgusTemplate -Template 'Value {Missing}' -Values @{} | Should -Be 'Value {Missing}'
        }
    }

    It 'handles empty templates' {
        InModuleScope ARGUS {
            Resolve-ArgusTemplate -Template '' -Values @{} | Should -Be ''
        }
    }
}
