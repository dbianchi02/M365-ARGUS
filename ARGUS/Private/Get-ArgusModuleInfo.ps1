function Get-ArgusModuleInfo {
    <#
    .SYNOPSIS
        Reports whether the modules ARGUS uses are installed (required and optional).
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter()]
        [string[]] $Name = @('Microsoft.Graph.Authentication', 'ExchangeOnlineManagement', 'PnP.PowerShell', 'MSCommerce')
    )

    $purpose = @{
        'Microsoft.Graph.Authentication' = @{ Required = $true; Purpose = 'Microsoft Graph sign-in and requests (all checks)' }
        'ExchangeOnlineManagement'       = @{ Required = $false; Purpose = 'Exchange Online checks and shared/room/equipment mailbox detection' }
        'PnP.PowerShell'                 = @{ Required = $false; Purpose = 'SharePoint tenant sharing settings and classic site administrators' }
        'MSCommerce'                     = @{ Required = $false; Purpose = 'Self-service purchase and trial policies for Copilot (Windows only)' }
    }

    foreach ($moduleName in $Name) {
        $installed = Get-Module -ListAvailable -Name $moduleName -ErrorAction SilentlyContinue | Sort-Object Version -Descending | Select-Object -First 1
        [pscustomobject]@{
            Name      = $moduleName
            Required  = if ($purpose.ContainsKey($moduleName)) { $purpose[$moduleName].Required } else { $false }
            Installed = [bool]$installed
            Version   = if ($installed) { [string]$installed.Version } else { $null }
            Purpose   = if ($purpose.ContainsKey($moduleName)) { $purpose[$moduleName].Purpose } else { '' }
        }
    }
}
