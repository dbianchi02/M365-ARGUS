#Requires -Version 7.2
<#
.SYNOPSIS
    Build script for ARGUS.

.DESCRIPTION
    Tasks:
    - Lint    : PSScriptAnalyzer on module, build and tests (settings: PSScriptAnalyzerSettings.psd1).
    - Test    : Pester 5 unit tests (Graph fully mocked). Writes NUnit XML to output/.
    - Docs    : regenerates docs/checks/*.md from check metadata.
    - Sample  : regenerates samples/sample-report.html (test sample) and samples/showcase-report.html (public demo).
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
        # Tests: fake checks declare param($Context) per the check contract without using it, and
        # compact positional calls keep data-driven test cases readable.
        Invoke-ScriptAnalyzer -Path (Join-Path $repoRoot 'tests') -Recurse -Settings $settings |
            Where-Object RuleName -NotIn 'PSReviewUnusedParameter', 'PSAvoidUsingPositionalParameters'
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

function ConvertTo-MarkdownCell {
    param([AllowNull()] [object] $Value)
    $text = (@($Value | Where-Object { $null -ne $_ -and "$_" -ne '' }) | ForEach-Object { "$_" }) -join ', '
    if (-not $text) { return [string][char]0x2014 }
    $text.Replace('|', '\|').Replace("`r", '').Replace("`n", ' ')
}

function Invoke-DocsTask {
    # Output is deterministic (no dates, sorted, LF endings) so CI can fail when docs are out of date.
    Import-Module (Join-Path $moduleRoot 'ARGUS.psd1') -Force
    $docsRoot = Join-Path $repoRoot 'docs/checks'
    $null = New-Item -Path $docsRoot -ItemType Directory -Force
    Get-ChildItem -LiteralPath $docsRoot -Filter '*.md' | Remove-Item -Force

    $checks = @(Get-ArgusCheck | Sort-Object Area, Id)
    foreach ($check in $checks) {
        $permission = Get-ArgusRequiredPermission -Id $check.Id
        $graphScopes = @($permission.GraphPermissions | ForEach-Object { '`' + $_ + '`' })
        $lines = [System.Collections.Generic.List[string]]::new()
        $lines.Add("# $($check.Id) $([char]0x2014) $($check.Title)")
        $lines.Add('')
        $lines.Add('| | |')
        $lines.Add('|---|---|')
        $lines.Add("| Area | $($check.Area) |")
        $lines.Add("| Category | $(ConvertTo-MarkdownCell $check.Category) |")
        $lines.Add("| Severity | $($check.Severity) |")
        $lines.Add("| Services | $(ConvertTo-MarkdownCell $check.Requires.Services) |")
        $lines.Add("| Graph permissions (read-only) | $(ConvertTo-MarkdownCell $graphScopes) |")
        $lines.Add("| Directory roles (delegated) | $(ConvertTo-MarkdownCell $permission.DirectoryRoles) |")
        if ($permission.ExchangePermission) { $lines.Add("| Exchange Online | $(ConvertTo-MarkdownCell $permission.ExchangePermission) |") }
        $lines.Add("| Licences | $(ConvertTo-MarkdownCell $check.Requires.Licenses) |")
        $lines.Add("| Data sets | $(ConvertTo-MarkdownCell $check.Requires.DataSets)$(if ($check.Requires.OptionalDataSets) { " (optional: $(ConvertTo-MarkdownCell $check.Requires.OptionalDataSets))" }) |")
        $lines.Add("| Uses Graph beta | $(if ($check.UsesBeta) { 'Yes' } else { 'No' }) |")
        $lines.Add("| Tags | $(ConvertTo-MarkdownCell $check.Tags) |")
        $lines.Add('')
        $lines.Add('## What is checked')
        $lines.Add('')
        $lines.Add($check.Description)
        $lines.Add('')
        $lines.Add('## Why it matters')
        $lines.Add('')
        $lines.Add($check.Rationale)
        $lines.Add('')
        $lines.Add('## How to fix')
        $lines.Add('')
        $lines.Add(($check.Remediation.Steps -replace "`r", ''))
        if ($check.Remediation.PortalUrl) {
            $lines.Add('')
            $lines.Add("Portal: <$($check.Remediation.PortalUrl)>")
        }
        if ($check.Remediation.PowerShell) {
            $lines.Add('')
            $lines.Add('```powershell')
            $lines.Add(($check.Remediation.PowerShell -replace "`r", ''))
            $lines.Add('```')
        }
        if ($check.Parameters -and $check.Parameters.Count -gt 0) {
            $lines.Add('')
            $lines.Add('## Parameters')
            $lines.Add('')
            $lines.Add("Defaults, overridable in the configuration file under ``Checks.""$($check.Id)"".Parameters``.")
            $lines.Add('')
            $lines.Add('| Name | Default |')
            $lines.Add('|---|---|')
            foreach ($name in @($check.Parameters.Keys | Sort-Object)) {
                $lines.Add("| ``$name`` | $(ConvertTo-MarkdownCell $check.Parameters[$name]) |")
            }
        }
        if ($check.References) {
            $lines.Add('')
            $lines.Add('## References')
            $lines.Add('')
            foreach ($reference in @($check.References)) { $lines.Add("- [$($reference.Title)]($($reference.Url))") }
        }
        $lines.Add('')
        $lines.Add('---')
        $lines.Add('')
        $lines.Add('*Generated from the check metadata by `./build/build.ps1 -Task Docs`. Do not edit by hand.*')
        [System.IO.File]::WriteAllText((Join-Path $docsRoot "$($check.Id).md"), (($lines -join "`n") + "`n"))
    }

    $index = [System.Collections.Generic.List[string]]::new()
    $index.Add('# ARGUS check catalogue')
    $index.Add('')
    $index.Add("$($checks.Count) read-only governance checks. Generated from the check metadata by ``./build/build.ps1 -Task Docs``.")
    foreach ($area in @($checks | Group-Object Area)) {
        $index.Add('')
        $index.Add("## $($area.Name) ($($area.Count))")
        $index.Add('')
        $index.Add('| Id | Check | Severity | Services |')
        $index.Add('|---|---|---|---|')
        foreach ($check in $area.Group) {
            $index.Add("| [$($check.Id)]($($check.Id).md) | $(ConvertTo-MarkdownCell $check.Title) | $($check.Severity) | $(ConvertTo-MarkdownCell $check.Requires.Services) |")
        }
    }
    [System.IO.File]::WriteAllText((Join-Path $docsRoot 'README.md'), (($index -join "`n") + "`n"))
    Write-Information "Docs: $($checks.Count) check page(s) and the index written to $docsRoot"
}

function Invoke-SampleTask {
    # The fixture itself is regenerated with tests/Fixtures/New-SampleResult.ps1 (deterministic).
    Import-Module (Join-Path $moduleRoot 'ARGUS.psd1') -Force
    $fixture = Join-Path $repoRoot 'tests/Fixtures/sample-results.json'
    $target = Join-Path $repoRoot 'samples/sample-report.html'
    $file = Export-ArgusReport -InputPath $fixture -OutputPath $target -NoBrowser
    Write-Information "Sample: $($file.FullName) ($([math]::Round($file.Length / 1KB)) KB)"
    # Public demo (healthy fictitious tenant), linked from the README and attached to releases.
    $null = & (Join-Path $PSScriptRoot 'New-ShowcaseReport.ps1')
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
