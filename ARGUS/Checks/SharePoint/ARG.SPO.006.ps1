Register-ArgusCheck @{
    Id          = 'ARG.SPO.006'
    Title       = 'Sites that allow Anyone links'
    Area        = 'SharePoint'
    Category    = 'Sharing'
    Severity    = 'Low'
    Description = 'Site collections (PnP.PowerShell `Get-PnPTenantSite`, OneDrive excluded) whose own sharing setting is `ExternalUserAndGuestSharing` (Anyone). Listed as Investigate: Anyone links may be intended on some sites, but each one should be known. Passes without evaluation when the organisation does not allow Anyone links. Needs `Connect-Argus -Service SharePoint`; otherwise the check is Skipped.'
    Rationale   = 'The organisation level sets the maximum; each site inherits it unless an administrator restricts it. Knowing which sites can create Anyone links lets you keep that capability only where it has a business owner and a reason.'
    Remediation = @{
        Steps      = "1. Review the listed sites with their owners.`n2. For sites that do not need Anyone links, lower the site sharing to New and existing guests (SharePoint admin center > Active sites > Sharing).`n3. For sites that keep it, check ARG.SPO.004 (link expiration)."
        PowerShell = "# Sample only - review before running.`nConnect-PnPOnline -Url 'https://<tenant>-admin.sharepoint.com' -Interactive -ClientId '<app id>'`nSet-PnPTenantSite -Identity '<site url>' -SharingCapability ExternalUserSharingOnly"
        PortalUrl  = 'https://admin.microsoft.com/sharepoint?page=siteManagement&modern=true'
    }
    References  = @(
        @{ Title = 'Change the sharing settings for a site'; Url = 'https://learn.microsoft.com/en-us/sharepoint/change-external-sharing-site' }
        @{ Title = 'Best practices for unauthenticated sharing'; Url = 'https://learn.microsoft.com/en-us/microsoft-365/solutions/best-practices-anonymous-sharing' }
    )
    Requires    = @{
        Services    = @('Graph', 'SharePoint')
        GraphScopes = @('SharePointTenantSettings.Read.All')
        DataSets    = @('SharePointTenantSettings', 'SharePointSites')
    }
    Tags        = @('SharePoint', 'Sharing', 'Inventory')
    Test        = {
        param($Context)
        if ((Get-ArgusProperty $Context.Data['SharePointTenantSettings'] 'sharingCapability' '') -ne 'externalUserAndGuestSharing') {
            return New-ArgusResult -Status Passed -EvaluatedCount 0 -AffectedCount 0 -Summary 'Anyone links are not allowed at organisation level, so no site can use them.'
        }
        $sites = @($Context.Data['SharePointSites'] | Where-Object { $_ -and [string](Get-ArgusProperty $_ 'Template' '') -notlike 'SPSPERS*' })
        $findings = @($sites | Where-Object { [string](Get-ArgusProperty $_ 'SharingCapability' '') -eq 'ExternalUserAndGuestSharing' } | ForEach-Object {
                [pscustomobject]@{
                    Title         = Get-ArgusProperty $_ 'Title' ''
                    SiteUrl       = Get-ArgusProperty $_ 'Url' ''
                    Template      = Get-ArgusProperty $_ 'Template' ''
                    Owner         = Get-ArgusProperty $_ 'Owner' ''
                    LastModified  = Format-ArgusDate (Get-ArgusProperty $_ 'LastContentModifiedDate' '')
                }
            } | Sort-Object SiteUrl)
        $status = if ($findings.Count -gt 0) { 'Investigate' } else { 'Passed' }
        New-ArgusResult -Status $status -Findings $findings -EvaluatedCount $sites.Count `
            -Summary '{AffectedCount} of {EvaluatedCount} sites allow Anyone links.'
    }
}
