function Get-ArgusConfig {
    <#
    .SYNOPSIS
        Loads the default configuration and deep-merges an optional user configuration file over it.

    .DESCRIPTION
        Defaults come from Config/argus.default.json. The user file only needs the keys it overrides.
        The merged configuration is validated; any problem throws a single message listing all of them.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter()]
        [string] $Path
    )

    $defaultPath = Join-Path $script:ArgusModuleRoot 'Config/argus.default.json'
    $config = Get-Content -LiteralPath $defaultPath -Raw | ConvertFrom-Json -AsHashtable
    $config = Merge-ArgusHashtable -Base @{} -Override $config

    if ($Path) {
        if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
            throw "Configuration file '$Path' not found."
        }
        try {
            $user = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json -AsHashtable -ErrorAction Stop
        }
        catch {
            throw "Configuration file '$Path' is not valid JSON: $($_.Exception.Message)"
        }
        if ($user -isnot [System.Collections.IDictionary]) {
            throw "Configuration file '$Path' must contain a JSON object."
        }
        $config = Merge-ArgusHashtable -Base $config -Override $user
    }

    $problems = @(Test-ArgusConfig -Config $config)
    if ($problems.Count -gt 0) {
        $source = if ($Path) { "'$Path'" } else { 'default configuration' }
        throw "Invalid ARGUS configuration ($source): $($problems -join ' ')"
    }
    $config
}
