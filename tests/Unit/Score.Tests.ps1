#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.5.0' }

BeforeAll {
    Get-Module ARGUS | Remove-Module -Force
    Import-Module (Join-Path $PSScriptRoot '../../ARGUS/ARGUS.psd1') -Force -ErrorAction Stop

    InModuleScope ARGUS {
        function script:Get-TestItem {
            param([string] $Status, [string] $Severity = 'Medium', [string] $Area = 'EntraID')
            [pscustomobject]@{ Status = $Status; Severity = $Severity; Area = $Area }
        }
        function script:Get-TestScoring {
            param([hashtable] $Weights, [double] $InvestigateCredit = 0.5, [double] $Threshold = 70)
            $scoring = (Get-ArgusConfig).Scoring
            if ($Weights) { foreach ($key in $Weights.Keys) { $scoring.Weights[$key] = $Weights[$key] } }
            $scoring.InvestigateCredit = $InvestigateCredit
            $scoring.PartialCoverageThreshold = $Threshold
            $scoring
        }
    }
}

AfterAll {
    Get-Module ARGUS | Remove-Module -Force
}

Describe 'Get-ArgusScore' {
    It 'scores 100 / A when every check passes' {
        InModuleScope ARGUS {
            $score = Get-ArgusScore -Result @((Get-TestItem Passed High), (Get-TestItem Passed Low)) -Scoring (Get-TestScoring)
            $score.Score | Should -Be 100
            $score.Grade | Should -Be 'A'
            $score.Coverage | Should -Be 100
            $score.IsPartial | Should -BeFalse
        }
    }

    It 'applies weights and the Investigate credit' {
        InModuleScope ARGUS {
            # (10*1 + 5*0 + 3*0.5 + 1*1) / (10 + 5 + 3 + 1) = 12.5 / 19 = 65.79 -> 66
            $items = @((Get-TestItem Passed Critical), (Get-TestItem Failed High), (Get-TestItem Investigate Medium), (Get-TestItem Passed Low))
            $score = Get-ArgusScore -Result $items -Scoring (Get-TestScoring)
            $score.Score | Should -Be 66
            $score.Grade | Should -Be 'C'
            $score.EarnedWeight | Should -Be 12.5
            $score.EvaluatedWeight | Should -Be 19
        }
    }

    It 'uses the configured Investigate credit' {
        InModuleScope ARGUS {
            $items = @((Get-TestItem Passed), (Get-TestItem Investigate))
            (Get-ArgusScore -Result $items -Scoring (Get-TestScoring -InvestigateCredit 0)).Score | Should -Be 50
            (Get-ArgusScore -Result $items -Scoring (Get-TestScoring -InvestigateCredit 1)).Score | Should -Be 100
        }
    }

    It 'excludes Skipped, Error and NotRun from the score denominator' {
        InModuleScope ARGUS {
            $items = @((Get-TestItem Passed Medium), (Get-TestItem Error Critical), (Get-TestItem Skipped High), (Get-TestItem NotRun Critical))
            $score = Get-ArgusScore -Result $items -Scoring (Get-TestScoring)
            $score.Score | Should -Be 100
        }
    }

    It 'computes coverage on selected checks (NotRun excluded) and flags Partial below the threshold' {
        InModuleScope ARGUS {
            # selected weight = 3 + 10 + 5 = 18 (NotRun excluded), evaluated = 3 -> 16.7 %
            $items = @((Get-TestItem Passed Medium), (Get-TestItem Error Critical), (Get-TestItem Skipped High), (Get-TestItem NotRun Critical))
            $score = Get-ArgusScore -Result $items -Scoring (Get-TestScoring)
            $score.Coverage | Should -Be 16.7
            $score.SelectedWeight | Should -Be 18
            $score.IsPartial | Should -BeTrue
        }
    }

    It 'is not Partial when NotRun checks are the only ones not evaluated' {
        InModuleScope ARGUS {
            $score = Get-ArgusScore -Result @((Get-TestItem Passed Medium), (Get-TestItem NotRun Critical)) -Scoring (Get-TestScoring)
            $score.Coverage | Should -Be 100
            $score.IsPartial | Should -BeFalse
        }
    }

    It 'is not Partial at exactly the threshold' {
        InModuleScope ARGUS {
            $scoring = Get-TestScoring -Weights @{ Medium = 7; Low = 3 }
            $score = Get-ArgusScore -Result @((Get-TestItem Passed Medium), (Get-TestItem Skipped Low)) -Scoring $scoring
            $score.Coverage | Should -Be 70
            $score.IsPartial | Should -BeFalse
        }
    }

    It 'returns no score when nothing was evaluated (empty run)' {
        InModuleScope ARGUS {
            $score = Get-ArgusScore -Result @() -Scoring (Get-TestScoring)
            $score.Score | Should -BeNullOrEmpty
            $score.Grade | Should -BeNullOrEmpty
            $score.Coverage | Should -Be 0
            $score.IsPartial | Should -BeTrue
            $score.Counts.Total | Should -Be 0
            @($score.Areas).Count | Should -Be 0
        }
    }

    It 'returns no score when every check is skipped or errored' {
        InModuleScope ARGUS {
            $score = Get-ArgusScore -Result @((Get-TestItem Skipped High), (Get-TestItem Error Low)) -Scoring (Get-TestScoring)
            $score.Score | Should -BeNullOrEmpty
            $score.Coverage | Should -Be 0
            $score.IsPartial | Should -BeTrue
        }
    }

    It 'returns no score for Info-only runs and computes coverage on counts' {
        InModuleScope ARGUS {
            $score = Get-ArgusScore -Result @((Get-TestItem Passed Info), (Get-TestItem Failed Info), (Get-TestItem Skipped Info), (Get-TestItem Passed Info)) -Scoring (Get-TestScoring)
            $score.Score | Should -BeNullOrEmpty
            $score.Grade | Should -BeNullOrEmpty
            $score.Coverage | Should -Be 75
            $score.IsPartial | Should -BeTrue
        }
    }

    It 'ignores Info checks in a weighted score' {
        InModuleScope ARGUS {
            $score = Get-ArgusScore -Result @((Get-TestItem Passed Medium), (Get-TestItem Failed Info)) -Scoring (Get-TestScoring)
            $score.Score | Should -Be 100
        }
    }

    It 'rounds half away from zero' {
        InModuleScope ARGUS {
            # 1 of 8 equal weights = 12.5 -> 13 (banker's rounding would give 12)
            $items = @(Get-TestItem Passed) + @(1..7 | ForEach-Object { Get-TestItem Failed })
            (Get-ArgusScore -Result $items -Scoring (Get-TestScoring)).Score | Should -Be 13
        }
    }

    It 'grades <Passed>/100 as <Grade>' -ForEach @(
        @{ Passed = 100; Grade = 'A' }, @{ Passed = 90; Grade = 'A' }, @{ Passed = 89; Grade = 'B' }
        @{ Passed = 75; Grade = 'B' }, @{ Passed = 74; Grade = 'C' }, @{ Passed = 60; Grade = 'C' }
        @{ Passed = 59; Grade = 'D' }, @{ Passed = 40; Grade = 'D' }, @{ Passed = 39; Grade = 'F' }, @{ Passed = 0; Grade = 'F' }
    ) {
        InModuleScope ARGUS -Parameters @{ Passed = $Passed; Grade = $Grade } {
            $items = @(1..100 | ForEach-Object { if ($_ -le $Passed) { Get-TestItem Passed } else { Get-TestItem Failed } })
            $score = Get-ArgusScore -Result $items -Scoring (Get-TestScoring)
            $score.Score | Should -Be $Passed
            $score.Grade | Should -Be $Grade
        }
    }

    It 'computes per-area scores in area order with status counts' {
        InModuleScope ARGUS {
            $items = @(
                (Get-TestItem Failed High Exchange), (Get-TestItem Passed High EntraID), (Get-TestItem Investigate Medium EntraID),
                (Get-TestItem Skipped Low Exchange), (Get-TestItem NotRun Low Licensing)
            )
            $score = Get-ArgusScore -Result $items -Scoring (Get-TestScoring)
            $score.Areas.Area | Should -Be @('EntraID', 'Licensing', 'Exchange')
            $entra = $score.Areas | Where-Object Area -EQ 'EntraID'
            $entra.Score | Should -Be 81   # (5 + 1.5) / 8 = 81.25
            $entra.DisplayName | Should -Be 'Entra ID'
            $exchange = $score.Areas | Where-Object Area -EQ 'Exchange'
            $exchange.Score | Should -Be 0
            $exchange.Counts.Skipped | Should -Be 1
            ($score.Areas | Where-Object Area -EQ 'Licensing').Score | Should -BeNullOrEmpty
            $score.Counts.Total | Should -Be 5
            $score.Counts.NotRun | Should -Be 1
        }
    }
}
