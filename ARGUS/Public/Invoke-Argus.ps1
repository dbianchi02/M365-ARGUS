function Invoke-Argus {
    <#
    .SYNOPSIS
        Runs the ARGUS governance checks and writes the report.

    .DESCRIPTION
        Runs the selected read-only governance checks against the connected Microsoft 365 tenant,
        computes the weighted Governance Score and writes the outputs:
        - a self-contained HTML report (dashboard, per-check findings and remediation);
        - a JSON results file (machine-readable, re-renderable with Export-ArgusReport);
        - optionally one CSV per failed check with the full findings list.

        Checks excluded by -Area, -Id, -ExcludeId or -Tag are reported as NotRun. Checks whose
        prerequisites (service connection, scope, licence) are not met are reported as Skipped with
        the reason. A check that throws is reported as Error and the run continues.

        Call Connect-Argus first.

    .PARAMETER Area
        Run only checks of these areas.

    .PARAMETER Id
        Run only these check IDs. Wildcards are supported (for example ARG.ENT.*).

    .PARAMETER ExcludeId
        Do not run these check IDs. Wildcards are supported.

    .PARAMETER Tag
        Run only checks with at least one of these tags.

    .PARAMETER ConfigPath
        Path of a configuration file created with New-ArgusConfig. Values are merged over the defaults.

    .PARAMETER OutputPath
        Folder where the report files are written. Created if missing. Defaults to ./output.

    .PARAMETER OutputFormat
        Output formats to write. Valid values: Html, Json, Csv. Defaults to Html and Json.

    .PARAMETER NoBrowser
        Do not open the HTML report in the default browser at the end of the run.

    .PARAMETER PassThru
        Return the results object.

    .PARAMETER CustomCheckPath
        Additional folder(s) containing custom check files to run alongside the built-in catalogue.

    .PARAMETER MaxFindingsInHtml
        Maximum number of findings rows embedded in the HTML report per check. The full list is always
        available in the JSON and CSV outputs. Defaults to 500.

    .EXAMPLE
        Connect-Argus; Invoke-Argus

        Runs the full catalogue and opens the HTML report.

    .EXAMPLE
        Invoke-Argus -Area EntraID, Licensing -OutputFormat Html, Json, Csv -NoBrowser

        Runs the Entra ID and Licensing checks and writes HTML, JSON and CSV files without opening a browser.

    .EXAMPLE
        $result = Invoke-Argus -ConfigPath ./contoso.config.json -ExcludeId ARG.SPO.002 -PassThru -NoBrowser

        Runs with a custom configuration, skips one check and returns the results object.

    .OUTPUTS
        None by default. With -PassThru, a PSCustomObject containing run metadata, score and per-check results.

    .LINK
        Connect-Argus

    .LINK
        Get-ArgusCheck

    .LINK
        Export-ArgusReport
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter()]
        [ValidateSet('EntraID', 'Applications', 'Licensing', 'GroupsTeams', 'SharePoint', 'Exchange')]
        [string[]] $Area,

        [Parameter()]
        [SupportsWildcards()]
        [string[]] $Id,

        [Parameter()]
        [SupportsWildcards()]
        [string[]] $ExcludeId,

        [Parameter()]
        [string[]] $Tag,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string] $ConfigPath,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string] $OutputPath = (Join-Path -Path (Get-Location) -ChildPath 'output'),

        [Parameter()]
        [ValidateSet('Html', 'Json', 'Csv')]
        [string[]] $OutputFormat = @('Html', 'Json'),

        [Parameter()]
        [switch] $NoBrowser,

        [Parameter()]
        [switch] $PassThru,

        [Parameter()]
        [string[]] $CustomCheckPath,

        [Parameter()]
        [ValidateRange(0, 100000)]
        [int] $MaxFindingsInHtml = 500
    )

    $startedAt = [datetimeoffset]::Now

    $config = Get-ArgusConfig -Path $ConfigPath
    if ($PSBoundParameters.ContainsKey('MaxFindingsInHtml')) {
        $config.Report.MaxFindingsInHtml = $MaxFindingsInHtml
    }

    $catalog = @(Get-ArgusCheckCatalog -CustomCheckPath $CustomCheckPath)
    $environment = Get-ArgusEnvironment
    if ('Graph' -notin $environment.ConnectedServices) {
        Write-Warning 'Not connected to Microsoft Graph. Run Connect-Argus first; checks that need Graph will be Skipped.'
    }

    $filter = @{}
    foreach ($name in 'Area', 'Id', 'ExcludeId', 'Tag') {
        if ($PSBoundParameters.ContainsKey($name)) { $filter[$name] = $PSBoundParameters[$name] }
    }

    $script:ArgusDataCache = @{}
    $results = @(Invoke-ArgusCheckRunner -Check $catalog -Config $config -Environment $environment -Now $startedAt.UtcDateTime @filter)
    $score = Get-ArgusScore -Result $results -Scoring $config.Scoring
    $finishedAt = [datetimeoffset]::Now

    $document = ConvertTo-ArgusResultDocument -Result $results -Score $score -Environment $environment -Config $config `
        -StartedAt $startedAt -FinishedAt $finishedAt -Filter $filter -ConfigPath $ConfigPath

    # Outputs
    $null = New-Item -Path $OutputPath -ItemType Directory -Force
    $tenantLabel = $environment.TenantDefaultDomain ?? $environment.TenantName ?? 'tenant'
    $slug = (($tenantLabel -split '\.')[0] -replace '[^A-Za-z0-9-]', '-').Trim('-')
    if (-not $slug) { $slug = 'tenant' }
    $baseName = 'ARGUS-Report-{0}-{1}' -f $slug, $startedAt.ToString('yyyyMMdd-HHmm')

    $files = [System.Collections.Generic.List[System.IO.FileInfo]]::new()
    if ('Json' -in $OutputFormat) {
        $files.Add((Export-ArgusResultJson -Document $document -Path (Join-Path $OutputPath "$baseName.json")))
    }
    if ('Csv' -in $OutputFormat) {
        foreach ($result in $results | Where-Object { $_.Status -eq 'Failed' -and @($_.Findings).Count -gt 0 }) {
            $files.Add((Export-ArgusFindingCsv -Result $result -Path (Join-Path $OutputPath "$baseName-$($result.Id).csv")))
        }
    }
    if ('Html' -in $OutputFormat) {
        # Implemented in Phase 3 (Export-ArgusReport / ConvertTo-ArgusHtml).
        Write-Warning 'HTML output is not implemented yet (Phase 3); use -OutputFormat Json.'
    }
    Write-Verbose "NoBrowser: $NoBrowser"

    Write-ArgusRunSummary -Document $document -File $files

    if ($PassThru) { $document }
}
