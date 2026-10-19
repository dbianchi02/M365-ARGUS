function Get-ArgusRequiredPermission {
    <#
    .SYNOPSIS
        Lists the permissions ARGUS needs, per check or aggregated.

    .DESCRIPTION
        Returns the Microsoft Graph permissions, Entra ID directory roles and Exchange Online role required
        by the selected checks, derived from each check's Requires metadata.

        By default one object per check is returned. Use -Aggregate to get the de-duplicated union, which is
        what Connect-Argus requests at sign-in. Use -AsAppPermission to get the application permissions
        (app roles) to grant to an app registration for unattended runs, instead of delegated scopes.

        All permissions are read-only.

    .PARAMETER Area
        Restrict the list to checks of these areas.

    .PARAMETER Id
        Restrict the list to these check IDs.

    .PARAMETER Aggregate
        Return a single de-duplicated object for all selected checks instead of one object per check.

    .PARAMETER AsAppPermission
        Return application permissions (app-only) rather than delegated scopes.

    .EXAMPLE
        Get-ArgusRequiredPermission

        Lists the delegated Graph scopes and roles required by each check.

    .EXAMPLE
        Get-ArgusRequiredPermission -Aggregate -AsAppPermission

        Lists the application permissions to grant to an app registration for unattended runs.

    .OUTPUTS
        PSCustomObject with CheckId, GraphPermissions, DirectoryRoles, ExchangeRole and Services.

    .LINK
        Connect-Argus

    .LINK
        Test-ArgusPrerequisite
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter()]
        [ValidateSet('EntraID', 'Applications', 'Licensing', 'GroupsTeams', 'SharePoint', 'Exchange')]
        [string[]] $Area,

        [Parameter()]
        [ValidatePattern('^ARG\.[A-Z]{3}\.\d{3}$')]
        [string[]] $Id,

        [Parameter()]
        [switch] $Aggregate,

        [Parameter()]
        [switch] $AsAppPermission
    )

    Write-Verbose "Get-ArgusRequiredPermission called with parameters: $($PSBoundParameters.Keys -join ', ')"
    throw [System.NotImplementedException]::new('Get-ArgusRequiredPermission is not implemented yet (planned for Phase 4).')
}
