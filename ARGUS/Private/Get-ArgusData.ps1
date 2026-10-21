function Get-ArgusData {
    <#
    .SYNOPSIS
        Returns a shared tenant data set, fetching it once per run.

    .DESCRIPTION
        Data sets (Users, Groups, SubscribedSkus, ...) are fetched by the loader registered in
        $script:ArgusDataSetLoaders and cached in $script:ArgusDataCache for the rest of the run.
        Invoke-Argus clears the cache at the start of each run.
    #>
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Name,

        [Parameter()]
        [switch] $Force
    )

    if (-not $Force -and $script:ArgusDataCache.ContainsKey($Name)) {
        Write-Output -InputObject $script:ArgusDataCache[$Name] -NoEnumerate
        return
    }

    $loader = $script:ArgusDataSetLoaders[$Name]
    if ($null -eq $loader) {
        throw "No loader is registered for data set '$Name'."
    }

    Write-Verbose "Loading data set '$Name'."
    $data = & $loader
    $script:ArgusDataCache[$Name] = $data
    Write-Output -InputObject $data -NoEnumerate
}
