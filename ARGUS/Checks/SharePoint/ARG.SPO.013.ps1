Register-ArgusCheck @{
    Id          = 'ARG.SPO.013'
    Title       = 'OneDrives near their storage quota (more than {QuotaPercent}%)'
    Area        = 'SharePoint'
    Category    = 'Storage'
    Severity    = 'Low'
    Description = 'OneDrive accounts from the OneDrive usage report (`getOneDriveUsageAccountDetail`, period D180) whose `Storage Used (Byte)` is more than **{QuotaPercent}%** of `Storage Allocated (Byte)`. Deleted accounts and accounts without an allocation are ignored. With concealed report names, or when the report returns no rows, the result is Investigate. When the report leaves `Site URL` empty (a known issue of the usage reports; this report has no Site Id), the URL comes from the `mySite` property of the user, or is derived from the UPN with the OneDrive naming convention when the user no longer exists (`UrlSource` column).'
    Rationale   = 'A full OneDrive stops syncing and saving, and users start keeping files on local disks or personal storage. Accounts close to the limit need a cleanup, a move of team content to SharePoint, or a higher quota.'
    Remediation = @{
        Steps      = "1. Ask the users to move team content to the relevant SharePoint sites and remove duplicates.`n2. Raise the OneDrive quota for users who need it (SharePoint admin center > Settings > OneDrive storage limit, or per user).`n3. Review the default OneDrive storage limit for new users."
        PortalUrl  = 'https://admin.microsoft.com/sharepoint?page=settings&modern=true'
    }
    References  = @(
        @{ Title = 'Set the default storage space for OneDrive users'; Url = 'https://learn.microsoft.com/en-us/sharepoint/set-default-storage-space' }
        @{ Title = 'Microsoft 365 reports in the admin center - OneDrive usage'; Url = 'https://learn.microsoft.com/en-us/microsoft-365/admin/activity-reports/onedrive-for-business-usage-ww' }
    )
    Requires    = @{
        Services    = @('Graph')
        GraphScopes = @('Reports.Read.All', 'User.Read.All', 'Organization.Read.All')
        DataSets    = @('OneDriveUsage', 'ReportSettings', 'Users', 'Organization')
    }
    Parameters  = @{ QuotaPercent = 90 }
    Tags        = @('OneDrive', 'Storage', 'Reports')
    Test        = {
        param($Context)
        $rows = @($Context.Data['OneDriveUsage'] | Where-Object { $_ -and (Get-ArgusProperty $_ 'Is Deleted' '') -ne 'True' })
        $issue = Get-ArgusReportIssue -ReportSettings $Context.Data['ReportSettings'] -Row $rows -ObjectName 'OneDrives near their quota'
        if ($issue) { return New-ArgusResult -Status Investigate -Summary $issue }

        $limit = [double]$Context.Parameters.QuotaPercent
        $evaluated = @($rows | Where-Object { [double](Get-ArgusProperty $_ 'Storage Allocated (Byte)' 0) -gt 0 })
        $findings = @($evaluated | ForEach-Object {
                $used = [double](Get-ArgusProperty $_ 'Storage Used (Byte)' 0)
                $allocated = [double](Get-ArgusProperty $_ 'Storage Allocated (Byte)' 0)
                $percent = [math]::Round(100 * $used / $allocated, 1)
                if ($percent -le $limit) { return }
                [pscustomobject]@{
                    DisplayName       = Get-ArgusProperty $_ 'Owner Display Name' ''
                    UserPrincipalName = Get-ArgusProperty $_ 'Owner Principal Name' ''
                    UsedGB            = [math]::Round($used / 1GB, 2)
                    AllocatedGB       = [math]::Round($allocated / 1GB, 2)
                    UsedPercent       = $percent
                    SiteUrl           = Get-ArgusProperty $_ 'Site URL' ''
                    UrlSource         = 'Report'
                }
            } | Sort-Object UsedPercent -Descending)
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
        New-ArgusResult -Status $status -Findings $findings -EvaluatedCount $evaluated.Count `
            -Summary '{AffectedCount} of {EvaluatedCount} OneDrive accounts use more than {QuotaPercent}% of their storage quota.'
    }
}
