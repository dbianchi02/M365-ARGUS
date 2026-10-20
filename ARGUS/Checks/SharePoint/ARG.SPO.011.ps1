Register-ArgusCheck @{
    Id          = 'ARG.SPO.011'
    Title       = 'OneDrive retention for deleted users is at least {MinRetentionDays} days'
    Area        = 'SharePoint'
    Category    = 'Lifecycle'
    Severity    = 'Low'
    Description = 'Reads `admin/sharepoint/settings.deletedUserPersonalSiteRetentionPeriodInDays`: how long the OneDrive of a deleted user is kept before it is deleted (30 days by default, up to 3650). Fails when it is shorter than **{MinRetentionDays}** days.'
    Rationale   = 'After a user is deleted, the manager has only this period to find and move business files from the OneDrive. Thirty days is often shorter than the time it takes to notice that something is missing, especially when the leaver process runs late.'
    Remediation = @{
        Steps      = "1. Agree the retention period with records management (for example 90 or 365 days).`n2. In the SharePoint admin center, go to Settings > OneDrive retention and set Days to retain a deleted user's OneDrive.`n3. Make sure the leaver process grants the manager access to the OneDrive and that retention policies cover legal requirements."
        PowerShell = "# Sample only - review before running.`nConnect-MgGraph -Scopes 'SharePointTenantSettings.ReadWrite.All'`nInvoke-MgGraphRequest -Method PATCH -Uri 'https://graph.microsoft.com/v1.0/admin/sharepoint/settings' -Body @{ deletedUserPersonalSiteRetentionPeriodInDays = 365 }"
        PortalUrl  = 'https://admin.microsoft.com/sharepoint?page=settings&modern=true'
    }
    References  = @(
        @{ Title = 'Set the OneDrive retention for deleted users'; Url = 'https://learn.microsoft.com/en-us/sharepoint/set-retention' }
        @{ Title = 'OneDrive retention and deletion'; Url = 'https://learn.microsoft.com/en-us/sharepoint/retention-and-deletion' }
    )
    Requires    = @{
        Services    = @('Graph')
        GraphScopes = @('SharePointTenantSettings.Read.All')
        DataSets    = @('SharePointTenantSettings')
    }
    Parameters  = @{ MinRetentionDays = 90 }
    Tags        = @('OneDrive', 'Lifecycle', 'Policy')
    Test        = {
        param($Context)
        $days = Get-ArgusProperty $Context.Data['SharePointTenantSettings'] 'deletedUserPersonalSiteRetentionPeriodInDays'
        if ($null -eq $days) { return New-ArgusResult -Status Investigate -Summary 'The OneDrive retention setting could not be read.' }
        $minimum = [int]$Context.Parameters.MinRetentionDays
        $finding = [pscustomobject]@{ Setting = 'deletedUserPersonalSiteRetentionPeriodInDays'; Days = [int]$days; MinimumDays = $minimum }
        if ([int]$days -lt $minimum) {
            return New-ArgusResult -Status Failed -Findings @($finding) -EvaluatedCount 1 `
                -Summary "The OneDrive of a deleted user is kept for $days days, less than {MinRetentionDays}."
        }
        New-ArgusResult -Status Passed -EvaluatedCount 1 -AffectedCount 0 -Summary "The OneDrive of a deleted user is kept for $days days."
    }
}
