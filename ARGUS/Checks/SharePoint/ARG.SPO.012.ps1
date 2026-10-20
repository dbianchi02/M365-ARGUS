Register-ArgusCheck @{
    Id          = 'ARG.SPO.012'
    Title       = 'OneDrive of deleted or disabled users with content'
    Area        = 'SharePoint'
    Category    = 'Lifecycle'
    Severity    = 'Low'
    Description = 'OneDrive accounts from the OneDrive usage report (`getOneDriveUsageAccountDetail`, period D180) that still hold content (`Storage Used (Byte)` > 0, not deleted) while their owner is disabled or no longer exists in Microsoft Entra ID. The OneDrive of a deleted user is kept for the retention period set in the SharePoint admin center (30 days by default) and then deleted. With concealed report names, or when the report returns no rows, the result is Investigate. When the report leaves `Site URL` empty (a known issue of the usage reports; this report has no Site Id), the URL comes from the `mySite` property of the user, or is derived from the UPN with the OneDrive naming convention when the user no longer exists (`UrlSource` column).'
    Rationale   = 'Files of people who left stay in OneDrives that nobody looks after, with their sharing links still active. Deciding what to keep and transferring it to a manager or a site is part of the leaver process.'
    Remediation = @{
        Steps      = "1. For each account, ask the manager whether content must be kept.`n2. Transfer the needed files to the manager or to a SharePoint site (the manager gets access automatically when the user is deleted, if configured).`n3. Delete the account or let the OneDrive retention period expire; apply a retention policy first when legal requirements apply."
        PortalUrl  = 'https://admin.microsoft.com/sharepoint?page=settings&modern=true'
    }
    References  = @(
        @{ Title = 'OneDrive retention and deletion'; Url = 'https://learn.microsoft.com/en-us/sharepoint/retention-and-deletion' }
        @{ Title = 'Microsoft 365 reports in the admin center - OneDrive usage'; Url = 'https://learn.microsoft.com/en-us/microsoft-365/admin/activity-reports/onedrive-for-business-usage-ww' }
    )
    Requires    = @{
        Services    = @('Graph')
        GraphScopes = @('Reports.Read.All', 'User.Read.All', 'Organization.Read.All')
        DataSets    = @('OneDriveUsage', 'ReportSettings', 'Users', 'Organization')
    }
    Tags        = @('OneDrive', 'Lifecycle', 'Reports')
    Test        = {
        param($Context)
        $rows = @($Context.Data['OneDriveUsage'] | Where-Object { $_ -and (Get-ArgusProperty $_ 'Is Deleted' '') -ne 'True' })
        $issue = Get-ArgusReportIssue -ReportSettings $Context.Data['ReportSettings'] -Row $rows -ObjectName 'OneDrive owners'
        if ($issue) { return New-ArgusResult -Status Investigate -Summary $issue }

        $users = @{}
        foreach ($user in @($Context.Data['Users'])) {
            $upn = [string](Get-ArgusProperty $user 'userPrincipalName' '')
            if ($upn) { $users[$upn.ToLowerInvariant()] = $user }
        }
        $findings = @($rows | ForEach-Object {
                $used = [double](Get-ArgusProperty $_ 'Storage Used (Byte)' 0)
                if ($used -le 0) { return }
                $upn = [string](Get-ArgusProperty $_ 'Owner Principal Name' '')
                $state = if (-not $users.ContainsKey($upn.ToLowerInvariant())) { 'Deleted or not found' }
                elseif ((Get-ArgusProperty $users[$upn.ToLowerInvariant()] 'accountEnabled') -ne $true) { 'Disabled' }
                else { return }
                [pscustomobject]@{
                    DisplayName       = Get-ArgusProperty $_ 'Owner Display Name' ''
                    UserPrincipalName = $upn
                    OwnerState        = $state
                    StorageUsedGB     = [math]::Round($used / 1GB, 2)
                    Files             = Get-ArgusProperty $_ 'File Count' ''
                    LastActivity      = Format-ArgusDate (Get-ArgusProperty $_ 'Last Activity Date' '') 'None in the last 180 days'
                    SiteUrl           = Get-ArgusProperty $_ 'Site URL' ''
                    UrlSource         = 'Report'
                }
            } | Sort-Object StorageUsedGB -Descending)
        # The report can return an empty Site URL (advisory SP676147) and has no Site Id: resolve it per user.
        $missing = @($findings | Where-Object { -not $_.SiteUrl })
        if ($missing.Count -gt 0) {
            $urls = Resolve-ArgusOneDriveUrl -UserPrincipalName @($missing.UserPrincipalName) -User @($Context.Data['Users']) -Organization $Context.Data['Organization']
            foreach ($finding in $missing) {
                $resolved = $urls[([string]$finding.UserPrincipalName).ToLowerInvariant()]
                if ($resolved) {
                    $finding.SiteUrl = $resolved.Url
                    $finding.UrlSource = if ($resolved.Derived) { 'Derived from the UPN' } else { 'User mySite' }
                }
                else { $finding.UrlSource = 'Not available' }
            }
        }
        $status = if ($findings.Count -gt 0) { 'Failed' } else { 'Passed' }
        New-ArgusResult -Status $status -Findings $findings -EvaluatedCount $rows.Count `
            -Summary '{AffectedCount} of {EvaluatedCount} OneDrive accounts with content belong to disabled or deleted users.'
    }
}
