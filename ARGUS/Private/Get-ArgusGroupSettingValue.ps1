function Get-ArgusGroupSettingValue {
    <#
    .SYNOPSIS
        Returns a value of the tenant-wide Group.Unified directory setting, or $null when not configured.

    .DESCRIPTION
        GET /groupSettings returns an empty list until an administrator creates the Group.Unified
        setting; until then every value has its documented default. Values are strings ("true", "").
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [AllowNull()]
        [object[]] $GroupSettings,

        [Parameter(Mandatory)]
        [string] $Name
    )

    $unifiedTemplate = '62375ab9-6b52-47ed-826b-58e47e0e304b'
    $setting = @($GroupSettings | Where-Object {
            $_ -and ((Get-ArgusProperty $_ 'displayName' '') -eq 'Group.Unified' -or (Get-ArgusProperty $_ 'templateId' '') -eq $unifiedTemplate)
        }) | Select-Object -First 1
    if (-not $setting) { return $null }
    $entry = @(Get-ArgusProperty $setting 'values' @() | Where-Object { (Get-ArgusProperty $_ 'name' '') -eq $Name }) | Select-Object -First 1
    if (-not $entry) { return $null }
    [string](Get-ArgusProperty $entry 'value' '')
}
