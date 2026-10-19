function Get-ArgusEnvironment {
    <#
    .SYNOPSIS
        Describes the current connections, granted scopes and detected licences.

    .DESCRIPTION
        Used by the runner to decide which checks are Skipped. A property that is $null means "unknown":
        the runner then does not skip on that dimension (for example GrantedScopes before Phase 4).
        Populated from the state written by Connect-Argus; without a connection only defaults are returned.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param()

    $environment = [ordered]@{
        ConnectedServices    = [string[]]@()
        GrantedScopes        = $null
        Licenses             = $null
        ConcealedReportNames = $null
        TenantId             = $null
        TenantName           = $null
        TenantDefaultDomain  = $null
        Account              = $null
        AuthMode             = $null
    }

    if ($null -ne $script:ArgusConnection) {
        foreach ($name in @($environment.Keys)) {
            $property = $script:ArgusConnection.PSObject.Properties[$name]
            if ($property) { $environment[$name] = $property.Value }
        }
    }

    [pscustomobject]$environment
}
