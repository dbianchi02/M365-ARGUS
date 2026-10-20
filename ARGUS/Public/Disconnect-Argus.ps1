function Disconnect-Argus {
    <#
    .SYNOPSIS
        Disconnects the sessions opened by Connect-Argus.

    .DESCRIPTION
        Closes the Microsoft Graph, Exchange Online and SharePoint Online sessions that were opened by
        Connect-Argus and clears the per-run data cache. Sessions opened outside ARGUS are left untouched.

    .PARAMETER Service
        Services to disconnect. Defaults to all services opened by ARGUS. Valid values: Graph, Exchange, SharePoint, Commerce.

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
        [ValidateSet('Graph', 'Exchange', 'SharePoint', 'Commerce')]
        [string[]] $Service = @('Graph', 'Exchange', 'SharePoint', 'Commerce')
    )

    if ($null -eq $script:ArgusConnection) {
        Write-Verbose 'No ARGUS session is open.'
        return
    }

    $opened = @($script:ArgusConnection.OpenedServices)
    $closed = [System.Collections.Generic.List[string]]::new()
    foreach ($name in $Service) {
        if ($name -notin $opened) { continue }
        try {
            switch ($name) {
                'Graph' { Disconnect-MgGraph -ErrorAction Stop | Out-Null }
                'Exchange' { if (Get-Command -Name Disconnect-ExchangeOnline -ErrorAction SilentlyContinue) { Disconnect-ExchangeOnline -Confirm:$false -ErrorAction Stop } }
                'SharePoint' { if (Get-Command -Name Disconnect-PnPOnline -ErrorAction SilentlyContinue) { Disconnect-PnPOnline -ErrorAction Stop } }
                # MSCommerce ran in its own process: forgetting the policies closes the session for ARGUS.
                'Commerce' { $script:ArgusCommercePolicies = $null }
            }
        }
        catch {
            Write-Verbose "Disconnecting $name reported: $($_.Exception.Message)"
        }
        $closed.Add($name)
    }

    $remaining = @($opened | Where-Object { $_ -notin $closed })
    if ('Graph' -in $closed -or $remaining.Count -eq 0) {
        $script:ArgusConnection = $null
        $script:ArgusCommercePolicies = $null
    }
    else {
        $script:ArgusConnection.OpenedServices = [string[]]$remaining
        $script:ArgusConnection.ConnectedServices = [string[]]@($script:ArgusConnection.ConnectedServices | Where-Object { $_ -notin $closed })
    }
    $script:ArgusDataCache = @{}
    $script:ArgusDataSetNotes = @{}
    Write-Verbose "Disconnected: $($closed -join ', ')"
}
