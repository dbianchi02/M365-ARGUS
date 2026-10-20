function Get-ArgusCheck {
    <#
    .SYNOPSIS
        Lists the ARGUS check catalogue with its metadata.

    .DESCRIPTION
        Returns the registered governance checks (built-in and, optionally, custom checks) with their
        metadata: Id, Title, Area, Category, Severity, Description, Rationale, Remediation, References,
        Requires, Parameters, Tags and UsesBeta. No tenant connection is needed.

    .PARAMETER Area
        Filter by area.

    .PARAMETER Severity
        Filter by severity.

    .PARAMETER Id
        Filter by check ID. Wildcards are supported (for example ARG.ENT.*).

    .PARAMETER Tag
        Return checks that have at least one of these tags.

    .PARAMETER CustomCheckPath
        Additional folder(s) containing custom check files to include in the catalogue.

    .EXAMPLE
        Get-ArgusCheck

        Lists the whole catalogue.

    .EXAMPLE
        Get-ArgusCheck -Area EntraID -Severity High, Critical

        Lists high and critical Entra ID checks.

    .EXAMPLE
        Get-ArgusCheck -Id 'ARG.APP.*' | Format-Table Id, Title, Severity

        Lists application checks in a table.

    .OUTPUTS
        PSCustomObject (one per check).

    .LINK
        Invoke-Argus
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter()]
        [ValidateSet('EntraID', 'Applications', 'Licensing', 'GroupsTeams', 'SharePoint', 'Exchange', 'Copilot')]
        [string[]] $Area,

        [Parameter()]
        [ValidateSet('Critical', 'High', 'Medium', 'Low', 'Info')]
        [string[]] $Severity,

        [Parameter()]
        [SupportsWildcards()]
        [string[]] $Id,

        [Parameter()]
        [string[]] $Tag,

        [Parameter()]
        [string[]] $CustomCheckPath
    )

    $catalog = @(Get-ArgusCheckCatalog -CustomCheckPath $CustomCheckPath)

    foreach ($check in $catalog) {
        if ($Area -and $check.Area -notin $Area) { continue }
        if ($Severity -and $check.Severity -notin $Severity) { continue }
        if ($Id -and -not ($Id | Where-Object { $check.Id -like $_ })) { continue }
        if ($Tag -and -not ($check.Tags | Where-Object { $_ -in $Tag })) { continue }

        [pscustomobject]@{
            PSTypeName      = 'Argus.CheckInfo'
            Id              = $check.Id
            Title           = Resolve-ArgusTemplate -Template $check.Title -Values $check.Parameters
            Area            = $check.Area
            Category        = $check.Category
            Severity        = $check.Severity
            Description     = Resolve-ArgusTemplate -Template $check.Description -Values $check.Parameters
            Rationale       = $check.Rationale
            Remediation     = $check.Remediation
            References      = $check.References
            Requires        = $check.Requires
            Parameters      = $check.Parameters.Clone()
            Tags            = $check.Tags
            UsesBeta        = $check.UsesBeta
            ApplyExclusions = $check.ApplyExclusions
            Source          = $check.Source
        }
    }
}
