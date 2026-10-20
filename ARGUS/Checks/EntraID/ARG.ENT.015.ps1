Register-ArgusCheck @{
    Id          = 'ARG.ENT.015'
    Title       = 'Directory synchronisation is up to date'
    Area        = 'EntraID'
    Category    = 'Hybrid identity'
    Severity    = 'Medium'
    Description = 'For hybrid tenants (`organization.onPremisesSyncEnabled` = true), fails when the last directory synchronisation (`onPremisesLastSyncDateTime`) is older than **{MaxSyncAgeHours}** hours. Cloud-only tenants are skipped.'
    Rationale   = 'When synchronisation stops, changes made on-premises (leavers disabled, group changes) no longer reach Microsoft 365, and governance decisions are based on stale data.'
    Remediation = @{
        Steps      = "1. Check the Microsoft Entra Connect (or Cloud Sync) server and its service.`n2. Review synchronisation errors in Microsoft Entra Connect Health.`n3. If synchronisation was decommissioned on purpose, turn it off in the tenant so the state is explicit."
        PortalUrl  = 'https://entra.microsoft.com/'
    }
    References  = @(
        @{ Title = 'Using Microsoft Entra Connect Health with sync'; Url = 'https://learn.microsoft.com/en-us/entra/identity/hybrid/connect/how-to-connect-health-sync' }
    )
    Requires    = @{
        Services    = @('Graph')
        GraphScopes = @('Organization.Read.All')
        DataSets    = @('Organization')
    }
    Parameters  = @{ MaxSyncAgeHours = 24 }
    Tags        = @('Hybrid', 'Lifecycle')
    Test        = {
        param($Context)
        $organization = $Context.Data['Organization']
        if (-not (Get-ArgusProperty $organization 'onPremisesSyncEnabled' $false)) {
            return New-ArgusResult -Status Skipped -SkipReason 'Cloud-only tenant: directory synchronisation is not enabled.'
        }
        $last = ConvertTo-ArgusUtcDate (Get-ArgusProperty $organization 'onPremisesLastSyncDateTime')
        if (-not $last) {
            return New-ArgusResult -Status Failed -Summary 'Directory synchronisation is enabled but no synchronisation has ever completed.'
        }
        $hours = [math]::Round(($Context.Now - $last).TotalHours, 1)
        $limit = [int]$Context.Parameters.MaxSyncAgeHours
        $when = $last.ToString('yyyy-MM-dd HH:mm', [cultureinfo]::InvariantCulture) + ' UTC'
        if ($hours -gt $limit) {
            return New-ArgusResult -Status Failed -Summary "The last directory synchronisation was $hours hours ago ($when); the limit is {MaxSyncAgeHours} hours."
        }
        New-ArgusResult -Status Passed -Summary "The last directory synchronisation was $hours hours ago ($when)."
    }
}
