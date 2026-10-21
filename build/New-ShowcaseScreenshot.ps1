#Requires -Version 7.2
<#
.SYNOPSIS
    Renders the README screenshots of the report (docs/assets/argus-report-light.png and -dark.png).

.DESCRIPTION
    Starts from the fictitious sample (tests/Fixtures/sample-results.json) and turns it into a healthy tenant:
    a few Low/Medium findings and reviews are kept, every other check is Passed, usage report names are
    visible (no banner). The score is recomputed with the module's Get-ArgusScore. The report is exported to a
    temporary folder and captured with a Chromium browser (Edge or Chrome) in light and dark mode.
    The committed sample report and its fixture are not changed. No real tenant data is used.

.PARAMETER BrowserPath
    Chromium-based browser used for the capture. Defaults to Edge or Chrome when installed.

.EXAMPLE
    ./build/New-ShowcaseScreenshot.ps1
#>
[CmdletBinding()]
param(
    [string] $BrowserPath
)

$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'
$repoRoot = Split-Path -Path $PSScriptRoot -Parent
Import-Module (Join-Path $repoRoot 'ARGUS/ARGUS.psd1') -Force

if (-not $BrowserPath) {
    $BrowserPath = @(
        "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe"
        "$env:ProgramFiles\Google\Chrome\Application\chrome.exe"
        '/usr/bin/google-chrome', '/usr/bin/microsoft-edge', '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'
    ) | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -First 1
}
if (-not $BrowserPath) { throw 'No Chromium-based browser found: pass -BrowserPath.' }

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
Write-Information "Showcase score: $($document.Score.Score) $($document.Score.Grade)"

$work = Join-Path ([System.IO.Path]::GetTempPath()) ('argus-showcase-' + [guid]::NewGuid().ToString('N'))
$null = New-Item -Path $work -ItemType Directory
try {
    $json = Join-Path $work 'showcase.json'
    $document | ConvertTo-Json -Depth 64 | Set-Content -LiteralPath $json -Encoding utf8NoBOM
    $html = Join-Path $work 'showcase.html'
    $null = Export-ArgusReport -InputPath $json -OutputPath $html -NoBrowser
    foreach ($theme in 'light', 'dark') {
        # The report reads its theme from localStorage ('argus-theme') before rendering: set it in a copy.
        $page = Join-Path $work "showcase-$theme.html"
        $preset = "<script>try { localStorage.setItem('argus-theme', '$theme'); } catch (e) { }</script>"
        (Get-Content -LiteralPath $html -Raw) -replace '(?i)<head>', "<head>$preset" | Set-Content -LiteralPath $page -Encoding utf8NoBOM
        $uri = [System.Uri]::new($page, [System.UriKind]::Absolute).AbsoluteUri
        $target = Join-Path $repoRoot "docs/assets/argus-report-$theme.png"
        $arguments = @('--headless=new', '--disable-gpu', '--hide-scrollbars', '--force-device-scale-factor=2', '--window-size=1280,1180',
            '--virtual-time-budget=3000', "--user-data-dir=$(Join-Path $work "profile-$theme")", "--screenshot=$target", $uri)
        # ArgumentList passes every argument unchanged (paths may contain spaces) and the browser is awaited
        # (on Windows the call operator does not wait for a GUI-subsystem executable).
        $start = [System.Diagnostics.ProcessStartInfo]::new($BrowserPath)
        foreach ($argument in $arguments) { $start.ArgumentList.Add($argument) }
        if (Test-Path -LiteralPath $target) { Remove-Item -LiteralPath $target -Force }
        $process = [System.Diagnostics.Process]::Start($start)
        # Edge can keep helper processes running after the capture: wait for the file, then end the process tree.
        $deadline = [datetime]::UtcNow.AddSeconds(120)
        while (-not $process.HasExited -and -not (Test-Path -LiteralPath $target) -and [datetime]::UtcNow -lt $deadline) { Start-Sleep -Milliseconds 500 }
        Start-Sleep -Seconds 2
        if (-not $process.HasExited) { $process.Kill($true) }
        if (-not (Test-Path -LiteralPath $target)) { throw "Screenshot not written: $target" }
        Write-Information "Screenshot: $target"
    }
}
finally {
    Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
}
