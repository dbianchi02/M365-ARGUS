function Export-ArgusReport {
    <#
    .SYNOPSIS
        Renders an HTML report from an existing ARGUS results JSON file.

    .DESCRIPTION
        Reads a results file written by Invoke-Argus (-OutputFormat Json) and renders the self-contained
        HTML report from it, without connecting to the tenant. Useful to re-render a past run with a newer
        report template, or to build the sample report from fixtures.

        The report has no external dependencies (no CDN, fonts or network access) and can be opened offline
        or sent to a customer. Tenant data is rendered as text only.

    .PARAMETER InputPath
        Path of the results JSON file.

    .PARAMETER OutputPath
        Path of the HTML file to write. Defaults to the input path with the .html extension.

    .PARAMETER MaxFindingsInHtml
        Maximum number of findings rows embedded in the HTML report per check. Defaults to the value
        recorded in the results file (Run.MaxFindingsInHtml), or 500.

    .PARAMETER LogoPath
        Optional logo (png, jpg, gif or svg, max 1 MB) embedded in the report header.

    .PARAMETER NoBrowser
        Do not open the HTML report in the default browser.

    .EXAMPLE
        Export-ArgusReport -InputPath ./output/ARGUS-Report-contoso-20260101-0900.json

        Re-renders the HTML report next to the JSON file and opens it.

    .EXAMPLE
        Export-ArgusReport -InputPath ./tests/Fixtures/sample-results.json -OutputPath ./samples/sample-report.html -NoBrowser

        Builds the sample report from fixtures.

    .OUTPUTS
        System.IO.FileInfo for the HTML file.

    .LINK
        Invoke-Argus
    #>
    [CmdletBinding()]
    [OutputType([System.IO.FileInfo])]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipelineByPropertyName)]
        [Alias('FullName')]
        [ValidateNotNullOrEmpty()]
        [string] $InputPath,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string] $OutputPath,

        [Parameter()]
        [ValidateRange(0, 100000)]
        [int] $MaxFindingsInHtml = 500,

        [Parameter()]
        [string] $LogoPath,

        [Parameter()]
        [switch] $NoBrowser
    )

    process {
        $inputFull = [System.IO.Path]::GetFullPath($InputPath, (Get-Location).ProviderPath)
        if (-not (Test-Path -LiteralPath $inputFull -PathType Leaf)) {
            throw "Results file '$inputFull' not found."
        }
        $json = [System.IO.File]::ReadAllText($inputFull)

        try {
            $root = [System.Text.Json.Nodes.JsonNode]::Parse($json)
        }
        catch {
            throw "Results file '$inputFull' is not valid JSON: $($_.Exception.Message)"
        }
        $schema = if ($root -is [System.Text.Json.Nodes.JsonObject] -and $null -ne $root['SchemaVersion']) { $root['SchemaVersion'].ToString() } else { '' }
        if ($schema -notmatch '^1\.\d+$') {
            throw "Results file '$inputFull' has unsupported SchemaVersion '$schema' (expected 1.x)."
        }

        $max = $MaxFindingsInHtml
        if (-not $PSBoundParameters.ContainsKey('MaxFindingsInHtml') -and $root['Run'] -is [System.Text.Json.Nodes.JsonObject] -and $null -ne $root['Run']['MaxFindingsInHtml']) {
            $max = [int]$root['Run']['MaxFindingsInHtml'].ToString()
        }

        $outputFull = if ($OutputPath) { [System.IO.Path]::GetFullPath($OutputPath, (Get-Location).ProviderPath) }
        else { [System.IO.Path]::ChangeExtension($inputFull, '.html') }
        $directory = Split-Path -Path $outputFull -Parent
        if (-not (Test-Path -LiteralPath $directory)) { $null = New-Item -Path $directory -ItemType Directory -Force }

        $html = ConvertTo-ArgusHtml -Json $json -MaxFindingsInHtml $max -LogoPath $LogoPath
        [System.IO.File]::WriteAllText($outputFull, $html, [System.Text.UTF8Encoding]::new($false))
        Write-Verbose "Report written to $outputFull"

        if (-not $NoBrowser) { Open-ArgusFile -Path $outputFull }
        Get-Item -LiteralPath $outputFull
    }
}
