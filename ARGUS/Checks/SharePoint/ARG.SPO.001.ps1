Register-ArgusCheck @{
    Id          = 'ARG.SPO.001'
    Title       = 'SharePoint site creation is restricted'
    Area        = 'SharePoint'
    Category    = 'Site governance'
    Severity    = 'Medium'
    Description = 'Reads `admin/sharepoint/settings.isSiteCreationEnabled` ("Users can create SharePoint sites" in the SharePoint admin center) and `isSiteCreationUIEnabled`. When users can create sites, communication sites and team sites without a group can be created by anyone, even if Microsoft 365 group creation is restricted (ARG.GRP.001): Investigate, as it is a valid choice for some organisations.'
    Rationale   = 'Self-service sites multiply quickly, often without a clear owner, classification or lifecycle. Restricting creation, or routing it through a request process with a template, keeps the site estate governable and the Copilot index clean.'
    Remediation = @{
        Steps      = "1. Decide whether site creation is open or goes through a request process.`n2. To restrict it, in the SharePoint admin center go to Settings > Site creation and turn off Users can create SharePoint sites.`n3. Keep ARG.GRP.001 aligned: group-connected sites are governed by the Microsoft 365 group creation policy."
        PortalUrl  = 'https://admin.microsoft.com/sharepoint?page=settings&modern=true'
    }
    References  = @(
        @{ Title = 'Manage site creation in SharePoint'; Url = 'https://learn.microsoft.com/en-us/sharepoint/manage-site-creation' }
        @{ Title = 'sharepointSettings resource type'; Url = 'https://learn.microsoft.com/en-us/graph/api/resources/sharepointsettings' }
    )
    Requires    = @{
        Services    = @('Graph')
        GraphScopes = @('SharePointTenantSettings.Read.All')
        DataSets    = @('SharePointTenantSettings')
    }
    Tags        = @('SharePoint', 'Policy')
    Test        = {
        param($Context)
        $settings = $Context.Data['SharePointTenantSettings']
        $enabled = Get-ArgusProperty $settings 'isSiteCreationEnabled'
        if ($null -eq $enabled) { return New-ArgusResult -Status Investigate -Summary 'The SharePoint site creation setting could not be read.' }
        if (-not $enabled) {
            return New-ArgusResult -Status Passed -EvaluatedCount 1 -AffectedCount 0 -Summary 'Only administrators can create SharePoint sites outside Microsoft 365 groups.'
        }
        $finding = [pscustomobject]@{
            Setting              = 'isSiteCreationEnabled'
            Value                = 'True'
            CreateCommandsShown  = Get-ArgusProperty $settings 'isSiteCreationUIEnabled' ''
            DefaultManagedPath   = Get-ArgusProperty $settings 'siteCreationDefaultManagedPath' ''
        }
        New-ArgusResult -Status Investigate -Findings @($finding) -EvaluatedCount 1 `
            -Summary 'Users can create SharePoint sites (isSiteCreationEnabled = true). Confirm this is intended and governed.'
    }
}
