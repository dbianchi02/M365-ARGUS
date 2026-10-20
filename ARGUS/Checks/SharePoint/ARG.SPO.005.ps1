Register-ArgusCheck @{
    Id          = 'ARG.SPO.005'
    Title       = 'Guest access to sites and files expires'
    Area        = 'SharePoint'
    Category    = 'Sharing'
    Severity    = 'Medium'
    Description = 'Reads `ExternalUserExpirationRequired` and `ExternalUserExpireInDays` with PnP.PowerShell (`Get-PnPTenant`): whether guests lose access to sites and files after a number of days unless a site owner renews it. Fails when the policy is off. Passes without evaluation when external sharing is disabled (`sharingCapability` = disabled). Needs `Connect-Argus -Service SharePoint`; otherwise the check is Skipped.'
    Rationale   = 'Guests invited for a project keep access long after it ends. An expiration policy makes site owners confirm, periodically, who still needs access; it complements guest reviews in Entra ID (ARG.ENT.005).'
    Remediation = @{
        Steps      = "1. In the SharePoint admin center, go to Policies > Sharing > More external sharing settings.`n2. Select Guest access to a site or OneDrive will expire automatically after this many days and enter a value (for example 90).`n3. Tell site owners that they will be asked to extend access for guests who still need it."
        PowerShell = "# Sample only - review before running.`nConnect-PnPOnline -Url 'https://<tenant>-admin.sharepoint.com' -Interactive -ClientId '<app id>'`nSet-PnPTenant -ExternalUserExpirationRequired `$true -ExternalUserExpireInDays 90"
        PortalUrl  = 'https://admin.microsoft.com/sharepoint?page=sharing&modern=true'
    }
    References  = @(
        @{ Title = 'Manage guest access expiration for sites and files'; Url = 'https://learn.microsoft.com/en-us/sharepoint/turn-external-sharing-on-or-off#change-the-organization-level-external-sharing-setting' }
        @{ Title = 'Set-SPOTenant: ExternalUserExpirationRequired'; Url = 'https://learn.microsoft.com/en-us/powershell/module/microsoft.online.sharepoint.powershell/set-spotenant' }
    )
    Requires    = @{
        Services    = @('Graph', 'SharePoint')
        GraphScopes = @('SharePointTenantSettings.Read.All')
        DataSets    = @('SharePointTenantSettings', 'SharePointTenant')
    }
    Tags        = @('SharePoint', 'OneDrive', 'Sharing', 'Guests')
    Test        = {
        param($Context)
        if ((Get-ArgusProperty $Context.Data['SharePointTenantSettings'] 'sharingCapability' '') -eq 'disabled') {
            return New-ArgusResult -Status Passed -EvaluatedCount 0 -AffectedCount 0 -Summary 'External sharing is disabled, so guests cannot be given access.'
        }
        $tenant = $Context.Data['SharePointTenant']
        $required = Get-ArgusProperty $tenant 'ExternalUserExpirationRequired'
        if ($null -eq $required) { return New-ArgusResult -Status Investigate -Summary 'The guest access expiration setting could not be read.' }
        $days = Get-ArgusProperty $tenant 'ExternalUserExpireInDays' ''
        if (-not $required) {
            $finding = [pscustomobject]@{ Setting = 'ExternalUserExpirationRequired'; Value = 'False'; ExpireInDays = $days }
            return New-ArgusResult -Status Failed -Findings @($finding) -EvaluatedCount 1 -Summary 'Guest access to sites and OneDrive never expires (ExternalUserExpirationRequired = false).'
        }
        New-ArgusResult -Status Passed -EvaluatedCount 1 -AffectedCount 0 -Summary "Guest access to sites and OneDrive expires after $days days unless renewed."
    }
}
