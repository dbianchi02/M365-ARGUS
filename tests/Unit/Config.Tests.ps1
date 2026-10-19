#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.5.0' }

BeforeAll {
    Get-Module ARGUS | Remove-Module -Force
    Import-Module (Join-Path $PSScriptRoot '../../ARGUS/ARGUS.psd1') -Force -ErrorAction Stop
    . (Join-Path $PSScriptRoot 'TestHelpers.ps1')

    function Write-TestConfig {
        param([string] $Name, [string] $Json)
        $path = Join-Path $TestDrive $Name
        Set-Content -LiteralPath $path -Value $Json -Encoding utf8
        $path
    }
}

AfterAll {
    Get-Module ARGUS | Remove-Module -Force
}

Describe 'Merge-ArgusHashtable' {
    It 'merges nested dictionaries key by key' {
        InModuleScope ARGUS {
            $merged = Merge-ArgusHashtable -Base @{ A = @{ X = 1; Y = 2 }; B = 1 } -Override @{ A = @{ Y = 3 } }
            $merged.A.X | Should -Be 1
            $merged.A.Y | Should -Be 3
            $merged.B | Should -Be 1
        }
    }

    It 'replaces arrays instead of concatenating them' {
        InModuleScope ARGUS {
            $merged = Merge-ArgusHashtable -Base @{ L = @('a', 'b') } -Override @{ L = @('c') }
            $merged.L | Should -Be @('c')
            $cleared = Merge-ArgusHashtable -Base @{ L = @('a') } -Override @{ L = @() }
            @($cleared.L).Count | Should -Be 0
        }
    }

    It 'does not modify the inputs' {
        InModuleScope ARGUS {
            $base = @{ A = @{ X = 1 } }
            $null = Merge-ArgusHashtable -Base $base -Override @{ A = @{ X = 2 } }
            $base.A.X | Should -Be 1
        }
    }

    It 'returns a case-insensitive hashtable' {
        InModuleScope ARGUS {
            $merged = Merge-ArgusHashtable -Base @{} -Override @{ Scoring = 1 }
            $merged['scoring'] | Should -Be 1
        }
    }
}

Describe 'Get-ArgusConfig' {
    It 'loads valid defaults' {
        InModuleScope ARGUS {
            $config = Get-ArgusConfig
            $config.Scoring.Weights.Critical | Should -Be 10
            $config.Scoring.Weights.High | Should -Be 5
            $config.Scoring.Weights.Medium | Should -Be 3
            $config.Scoring.Weights.Low | Should -Be 1
            $config.Scoring.Weights.Info | Should -Be 0
            $config.Scoring.InvestigateCredit | Should -Be 0.5
            $config.Scoring.PartialCoverageThreshold | Should -Be 70
            $config.Report.MaxFindingsInHtml | Should -Be 500
            @($config.Exclusions.UserPrincipalNames).Count | Should -Be 0
        }
    }

    It 'deep-merges a user file over the defaults' {
        $path = Write-TestConfig -Name 'user.json' -Json @'
{
  "Exclusions": { "UserPrincipalNames": ["breakglass01@contoso.onmicrosoft.com"] },
  "Checks": { "ARG.ENT.001": { "Parameters": { "InactiveDays": 120 }, "Severity": "High" } },
  "Scoring": { "Weights": { "High": 8 } }
}
'@
        InModuleScope ARGUS -Parameters @{ Path = $path } {
            $config = Get-ArgusConfig -Path $Path
            $config.Scoring.Weights.High | Should -Be 8
            $config.Scoring.Weights.Critical | Should -Be 10
            $config.Scoring.InvestigateCredit | Should -Be 0.5
            $config.Exclusions.UserPrincipalNames | Should -Be @('breakglass01@contoso.onmicrosoft.com')
            @($config.Exclusions.ObjectIds).Count | Should -Be 0
            $config.Checks['ARG.ENT.001'].Parameters.InactiveDays | Should -Be 120
            $config.Report.MaxFindingsInHtml | Should -Be 500
        }
    }

    It 'throws on a missing file' {
        InModuleScope ARGUS {
            { Get-ArgusConfig -Path (Join-Path $TestDrive 'missing.json') } | Should -Throw '*not found*'
        }
    }

    It 'throws on invalid JSON' {
        $path = Write-TestConfig -Name 'broken.json' -Json '{ "Scoring": '
        InModuleScope ARGUS -Parameters @{ Path = $path } {
            { Get-ArgusConfig -Path $Path } | Should -Throw '*not valid JSON*'
        }
    }

    It 'rejects <Name>' -ForEach @(
        @{ Name = 'a negative weight'; Json = '{ "Scoring": { "Weights": { "High": -1 } } }'; Message = '*Scoring.Weights.High*' }
        @{ Name = 'a non-numeric weight'; Json = '{ "Scoring": { "Weights": { "Low": "one" } } }'; Message = '*Scoring.Weights.Low*' }
        @{ Name = 'an InvestigateCredit above 1'; Json = '{ "Scoring": { "InvestigateCredit": 2 } }'; Message = '*InvestigateCredit*' }
        @{ Name = 'an unknown severity override'; Json = '{ "Checks": { "ARG.ENT.001": { "Severity": "Urgent" } } }'; Message = '*Checks.ARG.ENT.001.Severity*' }
        @{ Name = 'a non-boolean Enabled'; Json = '{ "Checks": { "ARG.ENT.001": { "Enabled": "no" } } }'; Message = '*Enabled must be true or false*' }
        @{ Name = 'an unknown check setting'; Json = '{ "Checks": { "ARG.ENT.001": { "Weight": 3 } } }'; Message = '*not a known setting*' }
        @{ Name = 'an unknown exclusion list'; Json = '{ "Exclusions": { "Mailboxes": [] } }'; Message = '*Exclusions.Mailboxes*' }
        @{ Name = 'a non-array exclusion list'; Json = '{ "Exclusions": { "AppIds": "x" } }'; Message = '*Exclusions.AppIds must be an array*' }
        @{ Name = 'a negative MaxFindingsInHtml'; Json = '{ "Report": { "MaxFindingsInHtml": -5 } }'; Message = '*MaxFindingsInHtml*' }
        @{ Name = 'a non-object root'; Json = '[1, 2]'; Message = '*must contain a JSON object*' }
    ) {
        $path = Write-TestConfig -Name 'invalid.json' -Json $Json
        InModuleScope ARGUS -Parameters @{ Path = $path; Message = $Message } {
            { Get-ArgusConfig -Path $Path } | Should -Throw -ExpectedMessage $Message
        }
    }
}

Describe 'Resolve-ArgusCheckSetting' {
    It 'returns the check defaults when the config has no entry' {
        InModuleScope ARGUS {
            $check = Get-TestCheck -Override @{ Parameters = @{ InactiveDays = 90 } }
            $setting = Resolve-ArgusCheckSetting -Check $check -Config (Get-ArgusConfig)
            $setting.Enabled | Should -BeTrue
            $setting.Severity | Should -Be 'Medium'
            $setting.Parameters.InactiveDays | Should -Be 90
        }
    }

    It 'applies Enabled, Severity and Parameters overrides' {
        InModuleScope ARGUS {
            $check = Get-TestCheck -Override @{ Parameters = @{ InactiveDays = 90; Other = 1 } }
            $config = Get-ArgusConfig
            $config.Checks['ARG.ENT.001'] = @{ Enabled = $false; Severity = 'High'; Parameters = @{ InactiveDays = 120 } }
            $setting = Resolve-ArgusCheckSetting -Check $check -Config $config
            $setting.Enabled | Should -BeFalse
            $setting.Severity | Should -Be 'High'
            $setting.Parameters.InactiveDays | Should -Be 120
            $setting.Parameters.Other | Should -Be 1
            $check.Parameters.InactiveDays | Should -Be 90
        }
    }

    It 'ignores unknown parameters with a warning' {
        InModuleScope ARGUS {
            $check = Get-TestCheck -Override @{ Parameters = @{ InactiveDays = 90 } }
            $config = Get-ArgusConfig
            $config.Checks['ARG.ENT.001'] = @{ Parameters = @{ InactiveDayz = 1 } }
            $setting = Resolve-ArgusCheckSetting -Check $check -Config $config -WarningVariable warnings -WarningAction SilentlyContinue
            $setting.Parameters.ContainsKey('InactiveDayz') | Should -BeFalse
            ($warnings | Out-String) | Should -BeLike "*unknown parameter 'InactiveDayz'*"
        }
    }
}
