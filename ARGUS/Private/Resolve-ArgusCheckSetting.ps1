function Resolve-ArgusCheckSetting {
    <#
    .SYNOPSIS
        Returns the effective Enabled / Severity / Parameters of a check after config overrides.

    .DESCRIPTION
        Parameter overrides for names the check does not declare are ignored with a warning, so a typo
        in the config can't silently change behaviour.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [pscustomobject] $Check,

        [Parameter(Mandatory)]
        [System.Collections.IDictionary] $Config
    )

    $parameters = @{}
    foreach ($key in $Check.Parameters.Keys) { $parameters[$key] = $Check.Parameters[$key] }

    $setting = @{ Enabled = $true; Severity = $Check.Severity; Parameters = $parameters }

    $entry = $Config.Checks[$Check.Id]
    if ($entry -is [System.Collections.IDictionary]) {
        if ($entry.Contains('Enabled')) { $setting.Enabled = [bool]$entry['Enabled'] }
        if ($entry.Contains('Severity')) { $setting.Severity = [string]$entry['Severity'] }
        if ($entry['Parameters'] -is [System.Collections.IDictionary]) {
            foreach ($key in $entry['Parameters'].Keys) {
                if ($parameters.ContainsKey($key)) {
                    $parameters[$key] = $entry['Parameters'][$key]
                }
                else {
                    Write-Warning "Configuration sets unknown parameter '$key' for check $($Check.Id); it is ignored."
                }
            }
        }
    }
    $setting
}
