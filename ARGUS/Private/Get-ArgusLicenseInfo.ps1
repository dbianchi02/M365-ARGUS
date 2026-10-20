function Get-ArgusLicenseInfo {
    <#
    .SYNOPSIS
        Returns the licence service plans relevant to ARGUS that are active in the tenant.

    .DESCRIPTION
        Reads subscribedSkus objects and returns the names of the known service plans
        ($script:ArgusLicenses, e.g. AAD_PREMIUM, AAD_PREMIUM_P2) that are provisioned ('Success')
        in a SKU whose capabilityStatus is Enabled or Warning (in grace period).
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]] $Sku
    )

    $found = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($item in $Sku) {
        if ($null -eq $item) { continue }
        $capability = if ($item.PSObject.Properties['capabilityStatus']) { [string]$item.capabilityStatus } else { 'Enabled' }
        if ($capability -notin 'Enabled', 'Warning') { continue }
        $plans = @(if ($item.PSObject.Properties['servicePlans']) { $item.servicePlans })
        foreach ($plan in $plans) {
            $name = [string]$plan.servicePlanName
            if ($script:ArgusLicenses.ContainsKey($name) -and [string]$plan.provisioningStatus -eq 'Success') {
                $null = $found.Add($name)
            }
        }
    }
    [string[]]@($found | Sort-Object)
}
