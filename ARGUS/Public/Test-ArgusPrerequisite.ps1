function Test-ArgusPrerequisite {
    <#
    .SYNOPSIS
        Reports whether the prerequisites for an ARGUS run are met.

    .DESCRIPTION
        Inspects the current environment and connections and reports:
        - required and optional modules (Microsoft.Graph.Authentication, ExchangeOnlineManagement, PnP.PowerShell, MSCommerce) and their versions;
        - active connections (Graph, Exchange Online, SharePoint Online) and the account or app used;
        - granted Graph scopes / app roles compared with the ones required by the selected checks;
        - detected licences relevant to the checks (Entra ID P1 / P2);
        - which checks would be Skipped and why.

        The cmdlet is read-only and does not run any check.

    .PARAMETER Area
        Restrict the evaluation to checks of these areas.

    .PARAMETER Id
        Restrict the evaluation to these check IDs (for example ARG.ENT.001).

    .PARAMETER Tag
        Restrict the evaluation to checks with at least one of these tags.

    .PARAMETER CustomCheckPath
        Additional folder(s) containing custom check files to include in the evaluation.

    .EXAMPLE
        Test-ArgusPrerequisite

        Evaluates prerequisites for the whole catalogue.

    .EXAMPLE
        Test-ArgusPrerequisite -Area Exchange, SharePoint

        Shows which Exchange and SharePoint checks would be skipped with the current connections.

    .OUTPUTS
        PSCustomObject describing modules, connections, permissions, licences and per-check readiness.

    .LINK
        Connect-Argus

    .LINK
        Get-ArgusRequiredPermission
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
        [string[]] $Tag,

        [Parameter()]
        [string[]] $CustomCheckPath
    )

    $environment = Get-ArgusEnvironment
    $modules = @(Get-ArgusModuleInfo)
    foreach ($module in $modules | Where-Object { -not $_.Installed }) {
        $level = if ($module.Required) { 'required' } else { 'optional' }
        Write-Warning "Module $($module.Name) ($level) is not installed: $($module.Purpose)."
    }

    $connected = 'Graph' -in $environment.ConnectedServices
    if (-not $connected) { Write-Warning 'Not connected to Microsoft Graph. Run Connect-Argus first.' }

    # Permissions requested at sign-in vs. granted
    $required = @((Get-ArgusRequiredPermission -Aggregate).GraphPermissions)
    [string[]] $missing = @()
    if ($null -ne $environment.GrantedScopes) {
        $missing = @($required | Where-Object { $_ -notin $environment.GrantedScopes -and ($_ -replace '\.Read\.', '.ReadWrite.') -notin $environment.GrantedScopes })
    }
    if ($missing.Count -gt 0) { Write-Warning "Permissions not granted: $($missing -join ', ')." }

    # Directory roles of the signed-in user (delegated only; direct assignments)
    $roles = $null
    if ($connected -and $environment.AuthMode -like 'Interactive*') {
        try {
            $me = Invoke-ArgusGraphRequest -Uri '/me?$select=id'
            $assignments = @(Invoke-ArgusGraphRequest -Uri ("/roleManagement/directory/roleAssignments?`$filter=principalId eq '{0}'&`$expand=roleDefinition(`$select=displayName)" -f $me.id) -All)
            $roles = [string[]]@($assignments | ForEach-Object { $_.roleDefinition.displayName } | Sort-Object -Unique)
            $lacking = @($script:ArgusRecommendedRoles | Where-Object { $_ -notin $roles })
            $isAdmin = 'Global Administrator' -in $roles
            if ($lacking.Count -gt 0 -and -not $isAdmin) {
                Write-Warning ("The signed-in account does not hold {0} (direct assignment). With delegated sign-in, ARGUS can only read what your own roles allow; some checks may be Skipped or return errors." -f ($lacking -join ' and '))
            }
        }
        catch {
            Write-Verbose "Role assignments of the signed-in user could not be read: $($_.Exception.Message)"
        }
    }

    # Per-check readiness
    $config = Get-ArgusConfig
    $catalog = @(Get-ArgusCheckCatalog -CustomCheckPath $CustomCheckPath)
    $checks = foreach ($check in $catalog) {
        if ($Area -and $check.Area -notin $Area) { continue }
        if ($Id -and $check.Id -notin $Id) { continue }
        if ($Tag -and -not ($check.Tags | Where-Object { $_ -in $Tag })) { continue }
        $setting = Resolve-ArgusCheckSetting -Check $check -Config $config -WarningAction SilentlyContinue
        $reasons = @(Test-ArgusRequirement -Check $check -Environment $environment)
        [pscustomobject]@{
            Id     = $check.Id
            Title  = $check.Title
            Ready  = $setting.Enabled -and $reasons.Count -eq 0
            Reason = if (-not $setting.Enabled) { 'Disabled in configuration.' } elseif ($reasons.Count) { ($reasons -join '; ') + '.' } else { '' }
        }
    }
    $checks = @($checks)

    [pscustomobject]@{
        PSTypeName           = 'Argus.Prerequisite'
        Connected            = [string[]]@($environment.ConnectedServices)
        Account              = $environment.Account
        AuthMode             = $environment.AuthMode
        Tenant               = if ($environment.TenantName) { $environment.TenantName } else { $environment.TenantId }
        Modules              = $modules
        MissingPermissions   = [string[]]$missing
        SignedInUserRoles    = $roles
        RecommendedRoles     = [string[]]$script:ArgusRecommendedRoles
        Licenses             = $environment.Licenses
        ConcealedReportNames = $environment.ConcealedReportNames
        ChecksReady          = @($checks | Where-Object Ready).Count
        ChecksSkipped        = @($checks | Where-Object { -not $_.Ready }).Count
        Checks               = $checks
    }
}
