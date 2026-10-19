function Get-ArgusScore {
    <#
    .SYNOPSIS
        Computes the Governance Score, grade and coverage, overall and per area (spec section 6).

    .DESCRIPTION
        - Weight per check = Scoring.Weights[Severity].
        - Credit: Passed = 1, Investigate = Scoring.InvestigateCredit, Failed = 0.
        - Skipped, Error and NotRun are excluded from the denominator.
        - Score = round(100 * sum(weight * credit) / sum(weight of evaluated checks)), midpoint away from zero.
        - Coverage = evaluated weight / weight of the selected checks (all statuses except NotRun), in percent.
          When the selected weight is 0 (for example only Info checks) coverage is computed on check counts.
        - IsPartial when coverage < Scoring.PartialCoverageThreshold.
        - Grade: A >= 90, B >= 75, C >= 60, D >= 40, F < 40.
        When no weighted check was evaluated, Score and Grade are $null and the run is Partial.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]] $Result,

        [Parameter(Mandatory)]
        [System.Collections.IDictionary] $Scoring
    )

    $weights = $Scoring['Weights']
    $investigateCredit = [double]$Scoring['InvestigateCredit']
    $threshold = [double]$Scoring['PartialCoverageThreshold']

    $measure = {
        param([object[]] $Items)

        $counts = [ordered]@{ Total = $Items.Count }
        foreach ($status in $script:ArgusStatuses) {
            $counts[$status] = @($Items | Where-Object { $_.Status -eq $status }).Count
        }

        $earned = 0.0
        $evaluatedWeight = 0.0
        $selectedWeight = 0.0
        foreach ($item in $Items) {
            if ($item.Status -eq 'NotRun') { continue }
            $weight = [double]$weights[$item.Severity]
            $selectedWeight += $weight
            switch ($item.Status) {
                'Passed' { $evaluatedWeight += $weight; $earned += $weight }
                'Investigate' { $evaluatedWeight += $weight; $earned += $weight * $investigateCredit }
                'Failed' { $evaluatedWeight += $weight }
            }
        }

        $selectedCount = $counts.Total - $counts.NotRun
        $evaluatedCount = $counts.Passed + $counts.Failed + $counts.Investigate
        $coverage = if ($selectedWeight -gt 0) { 100 * $evaluatedWeight / $selectedWeight }
        elseif ($selectedCount -gt 0) { 100 * $evaluatedCount / $selectedCount }
        else { 0 }
        $coverage = [math]::Round($coverage, 1, [System.MidpointRounding]::AwayFromZero)

        $score = if ($evaluatedWeight -gt 0) {
            [int][math]::Round(100 * $earned / $evaluatedWeight, [System.MidpointRounding]::AwayFromZero)
        }
        else { $null }

        $grade = if ($null -eq $score) { $null }
        elseif ($score -ge 90) { 'A' }
        elseif ($score -ge 75) { 'B' }
        elseif ($score -ge 60) { 'C' }
        elseif ($score -ge 40) { 'D' }
        else { 'F' }

        [ordered]@{
            Score           = $score
            Grade           = $grade
            Coverage        = $coverage
            IsPartial       = ($null -eq $score) -or ($coverage -lt $threshold)
            EarnedWeight    = $earned
            EvaluatedWeight = $evaluatedWeight
            SelectedWeight  = $selectedWeight
            Counts          = [pscustomobject]$counts
        }
    }

    $items = @($Result)
    $overall = & $measure $items

    $areas = foreach ($area in $script:ArgusAreas.Keys) {
        $areaItems = @($items | Where-Object { $_.Area -eq $area })
        if ($areaItems.Count -eq 0) { continue }
        $areaScore = [ordered]@{ Area = $area; DisplayName = $script:ArgusAreas[$area].DisplayName }
        $measured = & $measure $areaItems
        foreach ($key in $measured.Keys) { $areaScore[$key] = $measured[$key] }
        [pscustomobject]$areaScore
    }

    $overall['Areas'] = @($areas)
    $overall['Weights'] = $weights
    $overall['InvestigateCredit'] = $investigateCredit
    $overall['PartialCoverageThreshold'] = $threshold
    [pscustomobject]$overall
}
