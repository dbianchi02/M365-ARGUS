function Test-ArgusExcluded {
    <#
    .SYNOPSIS
        Returns $true when a finding row matches a global exclusion from the configuration.

    .DESCRIPTION
        Each exclusion list is matched case-insensitively against the finding columns mapped in
        $script:ArgusExclusionColumns (for example UserPrincipalNames -> UserPrincipalName, UPN).
        Site URLs are compared without a trailing slash.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        [object] $InputObject,

        [Parameter(Mandatory)]
        [AllowNull()]
        [System.Collections.IDictionary] $Exclusions
    )

    if ($null -eq $InputObject -or $null -eq $Exclusions) { return $false }

    foreach ($list in $script:ArgusExclusionColumns.Keys) {
        $values = @($Exclusions[$list] | Where-Object { $_ } | ForEach-Object { ([string]$_).TrimEnd('/') })
        if ($values.Count -eq 0) { continue }
        foreach ($column in $script:ArgusExclusionColumns[$list]) {
            $property = $InputObject.PSObject.Properties[$column]
            if ($null -eq $property -or $null -eq $property.Value) { continue }
            if (([string]$property.Value).TrimEnd('/') -in $values) { return $true }
        }
    }
    $false
}
