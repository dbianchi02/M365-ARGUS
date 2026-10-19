#Requires -Version 7.2
<#
.SYNOPSIS
    Build script for ARGUS.

.DESCRIPTION
    Tasks:
    - Lint    : PSScriptAnalyzer on module, build and tests (settings: PSScriptAnalyzerSettings.psd1).
    - Test    : Pester 5 unit tests (Graph fully mocked). Writes NUnit XML to output/.
    - Docs    : regenerates docs/checks/*.md from check metadata.
    - Sample  : regenerates samples/sample-report.html from tests/Fixtures/sample-results.json.
    - Package : stages the module under output/package/ARGUS for publishing and validates the manifest.
    - All     : Lint, Test, Docs, Sample, Package.

.PARAMETER Task
    One or more tasks to run, in the given order.

.EXAMPLE
    ./build/build.ps1 -Task Lint, Test
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateSet('Lint', 'Test', 'Docs', 'Sample', 'Package', 'All')]
    [string[]] $Task = @('Lint', 'Test')
)

$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'
Set-StrictMode -Version Latest

$repoRoot = Split-Path -Path $PSScriptRoot -Parent
$moduleRoot = Join-Path $repoRoot 'ARGUS'
$outputRoot = Join-Path $repoRoot 'output'

function Invoke-LintTask {
    Import-Module PSScriptAnalyzer -ErrorAction Stop
    $settings = Join-Path $repoRoot 'PSScriptAnalyzerSettings.psd1'
    $issues = @(
        Invoke-ScriptAnalyzer -Path $moduleRoot -Recurse -Settings $settings
        Invoke-ScriptAnalyzer -Path (Join-Path $repoRoot 'build') -Recurse -Settings $settings
        # Fake checks and test scriptblocks declare param($Context) per the check contract without using it.
        Invoke-ScriptAnalyzer -Path (Join-Path $repoRoot 'tests') -Recurse -Settings $settings |
            Where-Object RuleName -NE 'PSReviewUnusedParameter'
    )
    if ($issues) {
        $issues | Format-Table -AutoSize RuleName, Severity, ScriptName, Line, Message | Out-String -Width 200 |
            Write-Information
        throw "PSScriptAnalyzer reported $(@($issues).Count) issue(s)."
    }
    Write-Information 'Lint: no PSScriptAnalyzer issues.'
}

function Invoke-TestTask {
    Import-Module Pester -MinimumVersion 5.5.0 -ErrorAction Stop
    $null = New-Item -Path $outputRoot -ItemType Directory -Force

    $config = New-PesterConfiguration
    $config.Run.Path = Join-Path $repoRoot 'tests'
    $config.Run.PassThru = $true
    $config.Output.Verbosity = 'Detailed'
    $config.TestResult.Enabled = $true
    $config.TestResult.OutputFormat = 'NUnitXml'
    $config.TestResult.OutputPath = Join-Path $outputRoot 'testResults.xml'

    $result = Invoke-Pester -Configuration $config
    if ($result.FailedCount -gt 0 -or $result.Result -ne 'Passed') {
        throw "Pester: $($result.FailedCount) test(s) failed."
    }
    Write-Information "Test: $($result.PassedCount) test(s) passed."
}

function Invoke-DocsTask {
    # Implemented in Phase 6: generates docs/checks/<Id>.md and the README check table from metadata.
    Write-Warning 'Docs task is a placeholder until Phase 6 (no checks registered yet). Nothing generated.'
}

function Invoke-SampleTask {
    # Implemented in Phase 3: Export-ArgusReport -InputPath tests/Fixtures/sample-results.json.
    Write-Warning 'Sample task is a placeholder until Phase 3 (HTML report not implemented yet). Nothing generated.'
}

function Invoke-PackageTask {
    $manifestPath = Join-Path $moduleRoot 'ARGUS.psd1'
    $manifest = Test-ModuleManifest -Path $manifestPath -ErrorAction Stop

    $stage = Join-Path $outputRoot 'package/ARGUS'
    if (Test-Path -LiteralPath $stage) { Remove-Item -LiteralPath $stage -Recurse -Force }
    $null = New-Item -Path $stage -ItemType Directory -Force

    Get-ChildItem -LiteralPath $moduleRoot -Force |
        Copy-Item -Destination $stage -Recurse -Force
    Get-ChildItem -LiteralPath $stage -Recurse -Force -Filter '.gitkeep' | Remove-Item -Force
    Copy-Item -LiteralPath (Join-Path $repoRoot 'LICENSE') -Destination $stage

    $null = Test-ModuleManifest -Path (Join-Path $stage 'ARGUS.psd1') -ErrorAction Stop
    $prerelease = $manifest.PrivateData.PSData.Prerelease
    $version = if ($prerelease) { "$($manifest.Version)-$prerelease" } else { "$($manifest.Version)" }
    Write-Information "Package: ARGUS $version staged in $stage"
}

$expanded = if ($Task -contains 'All') { @('Lint', 'Test', 'Docs', 'Sample', 'Package') } else { $Task }
foreach ($name in $expanded) {
    Write-Information "==> $name"
    & "Invoke-$($name)Task"
}
