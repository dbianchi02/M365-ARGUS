Register-ArgusCheck @{
    Id          = 'ARG.SPO.009'
    Title       = 'Inactive SharePoint sites (more than {InactiveDays} days)'
    Area        = 'SharePoint'
    Category    = 'Lifecycle'
    Severity    = 'Low'
    Description = 'SharePoint sites whose `Last Activity Date` in the site usage report (`getSharePointSiteUsageDetail`, period D180) is older than **{InactiveDays}** days or empty (no activity in the report period). Deleted sites and system sites (`ExcludedTemplates`: search center, compliance policy center, tenant fundamental site, app catalog) are ignored; OneDrive accounts are not part of this report. When the report leaves `Site URL` empty (a known issue of the usage reports), the URL is read from the `Site Id` (`GET /sites/<id>`); the owner falls back to `Owner Display Name` and is "Not reported" when the report has none. With concealed report names, or when the report returns no rows, the result is Investigate.'
    Rationale   = 'Inactive sites hold content and permissions that nobody curates, use storage and appear in search. Reviewing them regularly keeps the information architecture clean.'
    Remediation = @{
        Steps      = "1. Contact the site owners and confirm whether each site is still needed.`n2. Archive (Microsoft 365 Archive) or set to read-only the sites whose content must be kept, delete the others after your retention period.`n3. Consider a site lifecycle policy for inactive sites (SharePoint Advanced Management)."
        PortalUrl  = 'https://admin.microsoft.com/sharepoint?page=siteManagement&modern=true'
    }
    References  = @(
        @{ Title = 'Microsoft 365 reports in the admin center - SharePoint site usage'; Url = 'https://learn.microsoft.com/en-us/microsoft-365/admin/activity-reports/sharepoint-site-usage-ww' }
        @{ Title = 'Manage site lifecycle policies'; Url = 'https://learn.microsoft.com/en-us/sharepoint/site-lifecycle-management' }
    )
    Requires    = @{
        Services    = @('Graph')
        GraphScopes = @('Reports.Read.All', 'Sites.Read.All')
        DataSets    = @('SharePointSiteUsage', 'ReportSettings')
    }
    Parameters  = @{
        InactiveDays      = 180
        ExcludedTemplates = @('Basic Search Center', 'Enterprise Search Center', 'Compliance Policy Center', 'SharePoint Online Tenant Fundamental Site', 'App Catalog Site', 'Tenant Admin Site')
    }
    Tags        = @('SharePoint', 'Lifecycle', 'Reports')
    Test        = {
        param($Context)
        $rows = @($Context.Data['SharePointSiteUsage'] | Where-Object { $_ -and (Get-ArgusProperty $_ 'Is Deleted' '') -ne 'True' })
        $issue = Get-ArgusReportIssue -ReportSettings $Context.Data['ReportSettings'] -Row $rows -ObjectName 'inactive sites'
        if ($issue) { return New-ArgusResult -Status Investigate -Summary $issue }

        # System sites (search center, compliance policy center, tenant fundamental site...) are not governed content.
        $excluded = @($Context.Parameters.ExcludedTemplates | ForEach-Object { [string]$_ })
        $rows = @($rows | Where-Object { [string](Get-ArgusProperty $_ 'Root Web Template' '') -notin $excluded })
        $threshold = $Context.Now.AddDays(-[int]$Context.Parameters.InactiveDays)
        $inactive = @($rows | Where-Object {
                $last = ConvertTo-ArgusUtcDate (Get-ArgusProperty $_ 'Last Activity Date' '')
                -not $last -or $last -lt $threshold
            })
        # The report can return an empty Site URL (advisory SP676147): resolve it from the Site Id.
        $missing = @($inactive | Where-Object { -not (Get-ArgusProperty $_ 'Site URL' '') } | ForEach-Object { [string](Get-ArgusProperty $_ 'Site Id' '') })
        $urls = if ($missing.Count -gt 0) { Resolve-ArgusSiteUrl -SiteId $missing } else { @{} }
        $findings = @($inactive | ForEach-Object {
                $last = ConvertTo-ArgusUtcDate (Get-ArgusProperty $_ 'Last Activity Date' '')
                $url = [string](Get-ArgusProperty $_ 'Site URL' '')
                $siteId = ([string](Get-ArgusProperty $_ 'Site Id' '')).ToLowerInvariant()
                if (-not $url -and $urls.ContainsKey($siteId)) { $url = $urls[$siteId] }
                $owner = [string](Get-ArgusProperty $_ 'Owner Principal Name' '')
                if (-not $owner) { $owner = [string](Get-ArgusProperty $_ 'Owner Display Name' '') }
                [pscustomobject]@{
                    SiteUrl       = $url
                    Template      = Get-ArgusProperty $_ 'Root Web Template' ''
                    LastActivity  = Format-ArgusDate $last 'None in the last 180 days'
                    DaysInactive  = if ($last) { [int]($Context.Now - $last).TotalDays } else { $null }
                    StorageUsedGB = [math]::Round([double](Get-ArgusProperty $_ 'Storage Used (Byte)' 0) / 1GB, 2)
                    Files         = Get-ArgusProperty $_ 'File Count' ''
                    Owner         = if ($owner) { $owner } else { 'Not reported' }
                    SiteId        = $siteId
                }
            } | Sort-Object @{ Expression = { if ($null -eq $_.DaysInactive) { [int]::MaxValue } else { $_.DaysInactive } }; Descending = $true }, SiteUrl)
        $status = if ($findings.Count -gt 0) { 'Failed' } else { 'Passed' }
        New-ArgusResult -Status $status -Findings $findings -EvaluatedCount $rows.Count `
            -Summary '{AffectedCount} of {EvaluatedCount} SharePoint sites have had no activity for {InactiveDays}+ days.'
    }
}
