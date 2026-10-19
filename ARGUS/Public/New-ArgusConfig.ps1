function New-ArgusConfig {
    <#
    .SYNOPSIS
        Writes an ARGUS configuration file with the default values.

    .DESCRIPTION
        Creates a JSON configuration file containing the default thresholds, global exclusions,
        per-check overrides (Enabled, Parameters, Severity), scoring weights and report options.
        Edit the file and pass it to Invoke-Argus -ConfigPath to customise a run.

        Only a local file is written; nothing is changed in the tenant.

    .PARAMETER Path
        Path of the configuration file to create.

    .PARAMETER Force
        Overwrite the file if it already exists.

    .EXAMPLE
        New-ArgusConfig -Path ./contoso.config.json

        Writes the default configuration to contoso.config.json.

    .OUTPUTS
        System.IO.FileInfo for the created file.

    .LINK
        Invoke-Argus
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([System.IO.FileInfo])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string] $Path,

        [Parameter()]
        [switch] $Force
    )

    $fullPath = [System.IO.Path]::GetFullPath($Path, (Get-Location).ProviderPath)
    if ((Test-Path -LiteralPath $fullPath) -and -not $Force) {
        throw "File '$fullPath' already exists. Use -Force to overwrite it."
    }

    $config = Get-ArgusConfig
    $checks = [ordered]@{}
    foreach ($check in $script:ArgusBuiltInChecks) {
        $parameters = [ordered]@{}
        foreach ($key in ($check.Parameters.Keys | Sort-Object)) { $parameters[$key] = $check.Parameters[$key] }
        $checks[$check.Id] = [ordered]@{ Enabled = $true; Severity = $check.Severity; Parameters = $parameters }
    }

    $document = [ordered]@{
        Exclusions = $config.Exclusions
        Checks     = $checks
        Scoring    = $config.Scoring
        Report     = $config.Report
    }

    if ($PSCmdlet.ShouldProcess($fullPath, 'Write ARGUS configuration file')) {
        $directory = Split-Path -Path $fullPath -Parent
        if (-not (Test-Path -LiteralPath $directory)) { $null = New-Item -Path $directory -ItemType Directory -Force }
        $json = $document | ConvertTo-Json -Depth 10
        [System.IO.File]::WriteAllText($fullPath, $json, [System.Text.UTF8Encoding]::new($false))
        Get-Item -LiteralPath $fullPath
    }
}
