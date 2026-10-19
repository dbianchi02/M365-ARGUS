function Disconnect-Argus {
    <#
    .SYNOPSIS
        Disconnects the sessions opened by Connect-Argus.

    .DESCRIPTION
        Closes the Microsoft Graph, Exchange Online and SharePoint Online sessions that were opened by
        Connect-Argus and clears the per-run data cache. Sessions opened outside ARGUS are left untouched.

    .PARAMETER Service
        Services to disconnect. Defaults to all services opened by ARGUS. Valid values: Graph, Exchange, SharePoint.

    .EXAMPLE
        Disconnect-Argus

        Disconnects every session opened by ARGUS.

    .EXAMPLE
        Disconnect-Argus -Service Exchange

        Disconnects only the Exchange Online session opened by ARGUS.

    .OUTPUTS
        None.

    .LINK
        Connect-Argus
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter()]
        [ValidateSet('Graph', 'Exchange', 'SharePoint')]
        [string[]] $Service = @('Graph', 'Exchange', 'SharePoint')
    )

    Write-Verbose "Disconnect-Argus called with parameters: $($PSBoundParameters.Keys -join ', ')"
    throw [System.NotImplementedException]::new('Disconnect-Argus is not implemented yet (planned for Phase 4).')
}
