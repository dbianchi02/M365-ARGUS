function Get-ArgusCheckCatalog {
    <#
    .SYNOPSIS
        Returns the built-in check definitions plus the custom checks found under -CustomCheckPath.

    .DESCRIPTION
        Built-in checks are registered once at module import. Custom checks are loaded on every call and
        are not kept in the session, so each run sees the current content of the custom folder.
        A custom check reusing a built-in Id is rejected with a non-terminating error.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter()]
        [string[]] $CustomCheckPath
    )

    $catalog = @($script:ArgusBuiltInChecks)
    if ($CustomCheckPath) {
        $resolved = foreach ($path in $CustomCheckPath) {
            $item = Resolve-Path -LiteralPath $path -ErrorAction SilentlyContinue
            if ($item) { $item.ProviderPath } else { Write-Error -Message "Custom check path '$path' does not exist." -Category ObjectNotFound -TargetObject $path }
        }
        if ($resolved) {
            $catalog += @(Import-ArgusCheck -Path $resolved -ExistingId @($catalog | ForEach-Object { $_.Id }))
        }
    }

    $areaOrder = @($script:ArgusAreas.Keys)
    $catalog | Sort-Object -Property @{ Expression = { $areaOrder.IndexOf($_.Area) } }, Id
}
