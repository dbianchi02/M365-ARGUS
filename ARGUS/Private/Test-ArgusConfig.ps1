function Test-ArgusConfig {
    <#
    .SYNOPSIS
        Validates a merged ARGUS configuration and returns the list of problems (empty when valid).
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory)]
        [System.Collections.IDictionary] $Config
    )

    $problems = [System.Collections.Generic.List[string]]::new()
    $isNumber = { param($Value) $Value -is [int] -or $Value -is [long] -or $Value -is [double] -or $Value -is [decimal] }

    foreach ($section in 'Exclusions', 'Checks', 'Scoring', 'Report') {
        if ($Config[$section] -isnot [System.Collections.IDictionary]) {
            $problems.Add("Section '$section' is missing or is not an object.")
        }
    }
    if ($problems.Count -gt 0) { return $problems.ToArray() }

    foreach ($key in $Config.Exclusions.Keys) {
        if (-not $script:ArgusExclusionColumns.Contains($key)) {
            $problems.Add("Exclusions.$key is not a known exclusion list. Allowed: $($script:ArgusExclusionColumns.Keys -join ', ').")
        }
        elseif ($null -ne $Config.Exclusions[$key] -and $Config.Exclusions[$key] -isnot [System.Collections.IList]) {
            $problems.Add("Exclusions.$key must be an array.")
        }
    }

    $weights = $Config.Scoring['Weights']
    if ($weights -isnot [System.Collections.IDictionary]) {
        $problems.Add('Scoring.Weights must be an object.')
    }
    else {
        foreach ($severity in $script:ArgusSeverities) {
            if (-not $weights.Contains($severity) -or -not (& $isNumber $weights[$severity]) -or $weights[$severity] -lt 0) {
                $problems.Add("Scoring.Weights.$severity must be a number >= 0.")
            }
        }
    }
    $credit = $Config.Scoring['InvestigateCredit']
    if (-not (& $isNumber $credit) -or $credit -lt 0 -or $credit -gt 1) {
        $problems.Add('Scoring.InvestigateCredit must be a number between 0 and 1.')
    }
    $threshold = $Config.Scoring['PartialCoverageThreshold']
    if (-not (& $isNumber $threshold) -or $threshold -lt 0 -or $threshold -gt 100) {
        $problems.Add('Scoring.PartialCoverageThreshold must be a number between 0 and 100.')
    }

    $max = $Config.Report['MaxFindingsInHtml']
    if (-not ($max -is [int] -or $max -is [long]) -or $max -lt 0) {
        $problems.Add('Report.MaxFindingsInHtml must be an integer >= 0.')
    }

    foreach ($id in $Config.Checks.Keys) {
        $entry = $Config.Checks[$id]
        if ($entry -isnot [System.Collections.IDictionary]) {
            $problems.Add("Checks.$id must be an object.")
            continue
        }
        foreach ($key in $entry.Keys) {
            if ($key -notin 'Enabled', 'Parameters', 'Severity') { $problems.Add("Checks.$id.$key is not a known setting (Enabled, Parameters, Severity).") }
        }
        if ($entry.Contains('Enabled') -and $entry['Enabled'] -isnot [bool]) { $problems.Add("Checks.$id.Enabled must be true or false.") }
        if ($entry.Contains('Severity') -and $entry['Severity'] -notin $script:ArgusSeverities) {
            $problems.Add("Checks.$id.Severity must be one of $($script:ArgusSeverities -join ', ').")
        }
        if ($entry.Contains('Parameters') -and $entry['Parameters'] -isnot [System.Collections.IDictionary]) {
            $problems.Add("Checks.$id.Parameters must be an object.")
        }
    }

    $problems.ToArray()
}
