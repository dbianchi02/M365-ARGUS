function Test-ArgusLicenseAvailable {
    <#
    .SYNOPSIS
        Returns $true when the tenant has the given service plan (or one that implies it), or when
        licences are unknown (the caller then tries the request and falls back on error).
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [string] $Plan
    )

    $licenses = (Get-ArgusEnvironment).Licenses
    if ($null -eq $licenses) { return $true }
    $acceptable = @($Plan)
    if ($script:ArgusLicenses.ContainsKey($Plan)) { $acceptable += @($script:ArgusLicenses[$Plan].ImpliedBy) }
    [bool](@($licenses) | Where-Object { $_ -in $acceptable })
}
