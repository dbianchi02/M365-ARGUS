function Get-ArgusRequiredPermission {
    <#
    .SYNOPSIS
        Lists the permissions ARGUS needs, per check or aggregated.

    .DESCRIPTION
        Returns the Microsoft Graph permissions, Entra ID directory roles and Exchange Online permission
        required by the selected checks. A check needs its own Requires.GraphScopes plus the permissions
        of every shared data set it uses (Requires.DataSets).

        By default one object per check is returned. Use -Aggregate to get the de-duplicated union plus
        the core permissions ARGUS always needs (tenant details, licence detection, report settings, the
        signed-in user's roles): this is the list Connect-Argus requests at sign-in.

        Use -AsAppPermission for unattended runs: the Graph permission names are the same, granted as
        application permissions (app roles), and Exchange uses Exchange.ManageAsApp plus an Entra role.

        With delegated (interactive) sign-in, a permission is only effective together with a directory
        role of the signed-in user: DirectoryRoles lists the least-privileged built-in roles that can read
        the data. The recommended roles for running ARGUS are Global Reader and Reports Reader.

        All permissions are read-only.

    .PARAMETER Area
        Restrict the list to checks of these areas.

    .PARAMETER Id
        Restrict the list to these check IDs.

    .PARAMETER Aggregate
        Return a single de-duplicated object for all selected checks, including the core permissions.

    .PARAMETER AsAppPermission
        Describe application permissions (app-only) rather than delegated scopes.

    .EXAMPLE
        Get-ArgusRequiredPermission

        Lists the delegated Graph scopes and roles required by each check.

    .EXAMPLE
        Get-ArgusRequiredPermission -Aggregate

        Lists every delegated scope Connect-Argus requests at sign-in.

    .EXAMPLE
        Get-ArgusRequiredPermission -Aggregate -AsAppPermission

        Lists the application permissions to grant to an app registration for unattended runs.

    .OUTPUTS
        PSCustomObject with CheckId, Title, PermissionType, Services, GraphPermissions, DirectoryRoles,
        ExchangePermission and Licenses.

    .LINK
        Connect-Argus

    .LINK
        Test-ArgusPrerequisite
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter()]
        [ValidateSet('EntraID', 'Applications', 'Licensing', 'GroupsTeams', 'SharePoint', 'Exchange', 'Copilot')]
        [string[]] $Area,

        [Parameter()]
        [ValidatePattern('^ARG\.[A-Z]{3}\.\d{3}$')]
        [string[]] $Id,

        [Parameter()]
        [switch] $Aggregate,

        [Parameter()]
        [switch] $AsAppPermission
    )

    $dataSets = @{}
    foreach ($definition in Get-ArgusDataSetDefinition) { $dataSets[$definition.Name] = $definition }

    $permissionType = if ($AsAppPermission) { 'Application' } else { 'Delegated' }
    $exchangePermission = if ($AsAppPermission) {
        'Exchange.ManageAsApp (Office 365 Exchange Online API) and the Entra role Global Reader for the app'
    }
    else {
        'Entra role Global Reader, or Exchange role group View-Only Organization Management'
    }

    $checks = @($script:ArgusBuiltInChecks | Where-Object {
            (-not $Area -or $_.Area -in $Area) -and (-not $Id -or $_.Id -in $Id)
        })

    $describe = {
        param([object[]] $Selected, [string] $CheckId, [string] $Title, [string[]] $Extra)
        $graph = [System.Collections.Generic.SortedSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
        $roles = [System.Collections.Generic.SortedSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
        $services = [System.Collections.Generic.SortedSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
        $licenses = [System.Collections.Generic.SortedSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
        foreach ($permission in $Extra) { $null = $graph.Add($permission) }
        foreach ($check in $Selected) {
            foreach ($scope in $check.Requires.GraphScopes) { $null = $graph.Add($scope) }
            foreach ($service in $check.Requires.Services) { $null = $services.Add($service) }
            foreach ($license in $check.Requires.Licenses) { $null = $licenses.Add($license) }
            foreach ($name in @($check.Requires.DataSets) + @($check.Requires.OptionalDataSets)) {
                if (-not $dataSets.ContainsKey($name)) { continue }
                $dataSet = $dataSets[$name]
                $null = $services.Add($dataSet.Service)
                foreach ($permission in $dataSet.Permissions) { $null = $graph.Add($permission) }
                foreach ($role in $dataSet.Roles) { $null = $roles.Add($role) }
            }
        }
        if ($Extra) { $null = $services.Add('Graph') }
        [pscustomobject]@{
            PSTypeName         = 'Argus.RequiredPermission'
            CheckId            = $CheckId
            Title              = $Title
            PermissionType     = $permissionType
            Services           = [string[]]@($services)
            GraphPermissions   = [string[]]@($graph)
            DirectoryRoles     = if ($AsAppPermission) { [string[]]@() } else { [string[]]@($roles) }
            ExchangePermission = if ($services.Contains('Exchange')) { $exchangePermission } else { $null }
            Licenses           = [string[]]@($licenses)
        }
    }

    if ($Aggregate) {
        $result = & $describe $checks '(all selected checks)' 'Permissions requested by Connect-Argus' $script:ArgusCorePermissions
        if (-not $AsAppPermission) {
            $result | Add-Member -NotePropertyName RecommendedRoles -NotePropertyValue ([string[]]$script:ArgusRecommendedRoles)
        }
        return $result
    }

    foreach ($check in $checks) {
        & $describe @($check) $check.Id $check.Title @()
    }
}
