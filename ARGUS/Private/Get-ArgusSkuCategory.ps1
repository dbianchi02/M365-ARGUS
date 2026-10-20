function Get-ArgusSkuCategory {
    <#
    .SYNOPSIS
        Classifies the tenant's SKUs as Paid, Trial or Free, keyed by lowercase skuId.

    .DESCRIPTION
        Free: skuPartNumber in the ignored list (free, viral and developer offers) or a SKU with
        FreeSeatThreshold or more enabled seats (free offers are provisioned with very large quantities).
        Trial: every subscription of the SKU in /directory/subscriptions has isTrial = true.
        Everything else is Paid, including SKUs without subscription information.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]] $SubscribedSku,

        [Parameter()]
        [AllowEmptyCollection()]
        [object[]] $Subscription = @(),

        [Parameter()]
        [AllowEmptyCollection()]
        [string[]] $IgnoredSku = @(),

        [Parameter()]
        [int] $FreeSeatThreshold = 10000
    )

    $trialFlags = @{}
    foreach ($item in @($Subscription | Where-Object { $_ })) {
        $id = ([string](Get-ArgusProperty $item 'skuId' '')).ToLowerInvariant()
        if (-not $id -or (Get-ArgusProperty $item 'status' '') -eq 'Deleted') { continue }
        if (-not $trialFlags.ContainsKey($id)) { $trialFlags[$id] = [System.Collections.Generic.List[bool]]::new() }
        $trialFlags[$id].Add([bool](Get-ArgusProperty $item 'isTrial' $false))
    }

    $categories = @{}
    foreach ($sku in @($SubscribedSku | Where-Object { $_ })) {
        $id = ([string](Get-ArgusProperty $sku 'skuId' '')).ToLowerInvariant()
        if (-not $id) { continue }
        $part = [string](Get-ArgusProperty $sku 'skuPartNumber' '')
        $enabled = [int](Get-ArgusProperty $sku 'prepaidUnits.enabled' 0)
        $categories[$id] = if ($part -in $IgnoredSku -or $enabled -ge $FreeSeatThreshold) { 'Free' }
        elseif ($trialFlags.ContainsKey($id) -and $trialFlags[$id].Count -gt 0 -and $trialFlags[$id] -notcontains $false) { 'Trial' }
        else { 'Paid' }
    }
    $categories
}
