function Write-ArgusRunSummary {
    <#
    .SYNOPSIS
        Prints the compact end-of-run console summary (score, grade, counts per status, output files).
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Console summary is the documented exception to the no Write-Host rule.')]
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory)]
        [pscustomobject] $Document,

        [Parameter()]
        [System.IO.FileInfo[]] $File = @()
    )

    $score = $Document.Score
    $tenant = if ($Document.Tenant.Name) { $Document.Tenant.Name } elseif ($Document.Tenant.DefaultDomain) { $Document.Tenant.DefaultDomain } else { 'unknown tenant' }
    $scoreText = if ($null -eq $score.Score) { 'n/a' } else { "$($score.Score)/100 ($($score.Grade))" }
    $partial = if ($score.IsPartial) { ' [Partial]' } else { '' }

    Write-Host ''
    Write-Host "ARGUS $($Document.Tool.Version) - $tenant"
    Write-Host ("Governance Score: {0}  Coverage: {1}%{2}" -f $scoreText, $score.Coverage, $partial)

    $colors = @{ Passed = 'Green'; Failed = 'Red'; Investigate = 'Yellow'; Error = 'Magenta'; Skipped = 'DarkGray'; NotRun = 'DarkGray' }
    Write-Host ("Checks: {0}  " -f $score.Counts.Total) -NoNewline
    foreach ($status in $script:ArgusStatuses) {
        Write-Host ("{0}: {1}  " -f $status, $score.Counts.$status) -ForegroundColor $colors[$status] -NoNewline
    }
    Write-Host ''

    foreach ($item in $File) {
        Write-Host "Output: $($item.FullName)"
    }
    Write-Host ''
}
