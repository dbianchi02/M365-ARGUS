Register-ArgusCheck @{
    Id          = 'ARG.SPO.004'
    Title       = 'Anyone links expire within {MaxDays} days'
    Area        = 'SharePoint'
    Category    = 'Sharing'
    Severity    = 'Medium'
    Description = 'When the organisation allows Anyone links (`sharingCapability` = externalUserAndGuestSharing), reads `RequireAnonymousLinksExpireInDays` with PnP.PowerShell (`Get-PnPTenant`). Fails when Anyone links never expire (0 or not set) or expire after more than **{MaxDays}** days. Passes without evaluation when Anyone links are not allowed. Needs `Connect-Argus -Service SharePoint`; otherwise the check is Skipped.'
    Rationale   = 'An Anyone link works for whoever has it, for as long as it exists. An expiration limit bounds how long a forwarded or leaked link stays usable, without forbidding Anyone links where the business needs them.'
    Remediation = @{
        Steps      = "1. In the SharePoint admin center, go to Policies > Sharing.`n2. Under Choose expiration and permissions options for Anyone links, select These links must expire within this many days and enter a value (for example 30).`n3. Consider View as the default permission for Anyone links."
        PowerShell = "# Sample only - review before running.`nConnect-PnPOnline -Url 'https://<tenant>-admin.sharepoint.com' -Interactive -ClientId '<app id>'`nSet-PnPTenant -RequireAnonymousLinksExpireInDays 30"
        PortalUrl  = 'https://admin.microsoft.com/sharepoint?page=sharing&modern=true'
    }
    References  = @(
        @{ Title = 'Best practices for unauthenticated sharing'; Url = 'https://learn.microsoft.com/en-us/microsoft-365/solutions/best-practices-anonymous-sharing' }
        @{ Title = 'Set-SPOTenant: RequireAnonymousLinksExpireInDays'; Url = 'https://learn.microsoft.com/en-us/powershell/module/microsoft.online.sharepoint.powershell/set-spotenant' }
    )
    Requires    = @{
        Services    = @('Graph', 'SharePoint')
        GraphScopes = @('SharePointTenantSettings.Read.All')
        DataSets    = @('SharePointTenantSettings', 'SharePointTenant')
    }
    Parameters  = @{ MaxDays = 30 }
    Tags        = @('SharePoint', 'OneDrive', 'Sharing')
    Test        = {
        param($Context)
        if ((Get-ArgusProperty $Context.Data['SharePointTenantSettings'] 'sharingCapability' '') -ne 'externalUserAndGuestSharing') {
            return New-ArgusResult -Status Passed -EvaluatedCount 0 -AffectedCount 0 -Summary 'Anyone links are not allowed at organisation level.'
        }
        $value = Get-ArgusProperty $Context.Data['SharePointTenant'] 'RequireAnonymousLinksExpireInDays'
        if ($null -eq $value) { return New-ArgusResult -Status Investigate -Summary 'The Anyone link expiration setting could not be read.' }
        $days = [int]$value
        $max = [int]$Context.Parameters.MaxDays
        $finding = [pscustomobject]@{ Setting = 'RequireAnonymousLinksExpireInDays'; Days = if ($days -le 0) { 'Never' } else { $days }; MaximumDays = $max }
        if ($days -le 0) {
            return New-ArgusResult -Status Failed -Findings @($finding) -EvaluatedCount 1 -Summary 'Anyone links are allowed and never expire.'
        }
        if ($days -gt $max) {
            return New-ArgusResult -Status Failed -Findings @($finding) -EvaluatedCount 1 -Summary "Anyone links expire after $days days, more than {MaxDays}."
        }
        New-ArgusResult -Status Passed -EvaluatedCount 1 -AffectedCount 0 -Summary "Anyone links expire after $days days."
    }
}
