Register-ArgusCheck @{
    Id          = 'ARG.ENT.014'
    Title       = 'Stale devices (no sign-in for more than {StaleDays} days)'
    Area        = 'EntraID'
    Category    = 'Device hygiene'
    Severity    = 'Low'
    Description = 'Devices whose `approximateLastSignInDateTime` is older than **{StaleDays}** days (or that never signed in and were registered more than {StaleDays} days ago). Both enabled and disabled devices are listed; disabled ones are usually ready to be deleted.'
    Rationale   = 'Stale devices make device inventories, Conditional Access reporting and licence counts unreliable.'
    Remediation = @{
        Steps      = "1. Disable stale devices first and wait a grace period (for example 30 days).`n2. Delete devices that nobody claimed.`n3. Before deleting Windows devices, make sure BitLocker recovery keys you still need are kept, and do not delete Windows Autopilot devices from Entra ID directly."
        PowerShell = "# Sample only - review before running. Disables one device.`nConnect-MgGraph -Scopes 'Device.ReadWrite.All'`nUpdate-MgDevice -DeviceId '<Id>' -AccountEnabled:`$false"
        PortalUrl  = 'https://entra.microsoft.com/'
    }
    References  = @(
        @{ Title = 'How to manage stale devices in Microsoft Entra ID'; Url = 'https://learn.microsoft.com/en-us/entra/identity/devices/manage-stale-devices' }
    )
    Requires    = @{
        Services    = @('Graph')
        GraphScopes = @('Device.Read.All')
        DataSets    = @('Devices')
    }
    Parameters  = @{ StaleDays = 180 }
    Tags        = @('Devices', 'Lifecycle')
    Test        = {
        param($Context)
        $threshold = $Context.Now.AddDays(-[int]$Context.Parameters.StaleDays)
        $devices = @($Context.Data['Devices'])
        $findings = foreach ($device in $devices) {
            $last = ConvertTo-ArgusUtcDate (Get-ArgusProperty $device 'approximateLastSignInDateTime')
            $registered = ConvertTo-ArgusUtcDate (Get-ArgusProperty $device 'registrationDateTime')
            $reference = if ($last) { $last } else { $registered }
            if (-not $reference -or $reference -ge $threshold) { continue }
            [pscustomobject]@{
                DeviceName      = Get-ArgusProperty $device 'displayName' ''
                OperatingSystem = (@((Get-ArgusProperty $device 'operatingSystem' ''), (Get-ArgusProperty $device 'operatingSystemVersion' '')) | Where-Object { $_ }) -join ' '
                TrustType       = Get-ArgusProperty $device 'trustType' ''
                Enabled         = [bool](Get-ArgusProperty $device 'accountEnabled' $false)
                LastSignIn      = Format-ArgusDate $last 'Never'
                DaysSinceSignIn = [int]($Context.Now - $reference).TotalDays
                Id              = Get-ArgusProperty $device 'id' ''
            }
        }
        $findings = @($findings | Sort-Object DaysSinceSignIn -Descending)
        $status = if ($findings.Count -gt 0) { 'Failed' } else { 'Passed' }
        New-ArgusResult -Status $status -Findings $findings -EvaluatedCount $devices.Count `
            -Summary '{AffectedCount} of {EvaluatedCount} devices have not signed in for {StaleDays}+ days.'
    }
}
