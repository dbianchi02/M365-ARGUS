#Requires -Version 7.2
<#
.SYNOPSIS
    Writes samples/showcase-report.html: the public demo report of a healthy fictitious tenant.

.DESCRIPTION
    Starts from the fictitious sample (tests/Fixtures/sample-results.json) and turns it into a healthy tenant:
    a few Low/Medium findings and reviews are kept, every other check is Passed, usage report names are
    visible (no banner). The score is recomputed with the module's Get-ArgusScore.
    samples/sample-report.html stays the test sample (every status, HTML payloads); this file is the one
    linked from the README and attached to releases. No real tenant data is used.

.PARAMETER OutputPath
    Target HTML file. Defaults to samples/showcase-report.html.

.EXAMPLE
    ./build/New-ShowcaseReport.ps1
#>
[CmdletBinding()]
[OutputType([System.IO.FileInfo])]
param(
    [string] $OutputPath
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Path $PSScriptRoot -Parent
if (-not $OutputPath) { $OutputPath = Join-Path $repoRoot 'samples/showcase-report.html' }
Import-Module (Join-Path $repoRoot 'ARGUS/ARGUS.psd1') -Force

# Checks that keep a finding or a review, so the showcase stays realistic; every other check is Passed.
$keepFailed = 'ARG.ENT.014', 'ARG.APP.003', 'ARG.SPO.009', 'ARG.LIC.006'
$keepInvestigate = 'ARG.ENT.003', 'ARG.ENT.012', 'ARG.COP.004', 'ARG.COP.005', 'ARG.COP.008', 'ARG.COP.010'

$document = Get-Content -LiteralPath (Join-Path $repoRoot 'tests/Fixtures/sample-results.json') -Raw | ConvertFrom-Json -Depth 64
foreach ($result in $document.Results) {
    if ($result.Id -in $keepFailed) { $result.Status = 'Failed'; continue }
    if ($result.Id -in $keepInvestigate) { $result.Status = 'Investigate'; continue }
    $evaluated = [int]$result.EvaluatedCount
    $result.Status = 'Passed'
    $result.Summary = if ($evaluated -gt 0) { 'No issue found ({0:N0} evaluated).' -f $evaluated } else { 'The setting matches the recommendation.' }
    $result.AffectedCount = 0
    $result.Findings = @()
    $result.SkipReason = $null
    $result.ErrorMessage = $null
}
$document.Environment.ConcealedReportNames = $false
$document.Run.Filters.ExcludeId = @()

$config = & (Get-Module ARGUS) { Get-ArgusConfig }
$document.Score = & (Get-Module ARGUS) { param($Result, $Scoring) Get-ArgusScore -Result $Result -Scoring $Scoring } @($document.Results) $config.Scoring

$json = Join-Path ([System.IO.Path]::GetTempPath()) ('argus-showcase-' + [guid]::NewGuid().ToString('N') + '.json')
try {
    $document | ConvertTo-Json -Depth 64 | Set-Content -LiteralPath $json -Encoding utf8NoBOM
    $file = Export-ArgusReport -InputPath $json -OutputPath $OutputPath -NoBrowser
    Write-Information "Showcase: $($file.FullName) (score $($document.Score.Score) $($document.Score.Grade))"
    $file
}
finally {
    Remove-Item -LiteralPath $json -Force -ErrorAction SilentlyContinue
}
