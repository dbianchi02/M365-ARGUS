Register-ArgusCheck @{
    Id          = 'ARG.SPO.010'
    Title       = 'Sites near their storage quota (more than {QuotaPercent}%)'
    Area        = 'SharePoint'
    Category    = 'Storage'
    Severity    = 'Low'
    Description = 'SharePoint sites whose used storage is more than **{QuotaPercent}%** of the allocated storage, from the site usage report (`Storage Used (Byte)` / `Storage Allocated (Byte)`, period D180). Deleted sites and sites without an allocation are ignored. With concealed report names, or when the report returns no rows, the result is Investigate. When the report leaves `Site URL` empty (a known issue of the usage reports), the URL is read from the `Site Id`: first from the PnP tenant site list when SharePoint is connected (it includes private group and channel sites), then with `GET /sites/<id>`, which in delegated mode only reads the sites the account can access.'
    Rationale   = 'A site that reaches its quota becomes read-only for new content, which interrupts work. Planning quota increases or clean-up in advance avoids that.'
    Remediation = @{
        Steps      = "1. Review large libraries, old versions and the recycle bin of each site.`n2. Clean up or archive content that is no longer needed, or reduce the number of kept versions.`n3. Increase the site storage limit if the content is needed and tenant storage allows it."
        PortalUrl  = 'https://admin.microsoft.com/sharepoint?page=siteManagement&modern=true'
    }
    References  = @(
        @{ Title = 'Manage site storage limits'; Url = 'https://learn.microsoft.com/en-us/sharepoint/manage-site-collection-storage-limits' }
        @{ Title = 'Microsoft 365 reports in the admin center - SharePoint site usage'; Url = 'https://learn.microsoft.com/en-us/microsoft-365/admin/activity-reports/sharepoint-site-usage-ww' }
    )
    Requires    = @{
        Services         = @('Graph')
        GraphScopes      = @('Reports.Read.All', 'Sites.Read.All')
        DataSets         = @('SharePointSiteUsage', 'ReportSettings')
        OptionalDataSets = @('SharePointSites')
    }
    Parameters  = @{ QuotaPercent = 90 }
    Tags        = @('SharePoint', 'Storage', 'Reports')
    Test        = {
        param($Context)
        $rows = @($Context.Data['SharePointSiteUsage'] | Where-Object { $_ -and (Get-ArgusProperty $_ 'Is Deleted' '') -ne 'True' })
        $issue = Get-ArgusReportIssue -ReportSettings $Context.Data['ReportSettings'] -Row $rows -ObjectName 'sites near their quota'
        if ($issue) { return New-ArgusResult -Status Investigate -Summary $issue }

        $limit = [double]$Context.Parameters.QuotaPercent
        $evaluated = @($rows | Where-Object { [double](Get-ArgusProperty $_ 'Storage Allocated (Byte)' 0) -gt 0 })
        $near = @($evaluated | Where-Object {
                100 * [double](Get-ArgusProperty $_ 'Storage Used (Byte)' 0) / [double](Get-ArgusProperty $_ 'Storage Allocated (Byte)' 1) -gt $limit
            })
        # The report can return an empty Site URL (advisory SP676147): resolve it from the Site Id.
        $missing = @($near | Where-Object { -not (Get-ArgusProperty $_ 'Site URL' '') } | ForEach-Object { [string](Get-ArgusProperty $_ 'Site Id' '') })
        $urls = if ($missing.Count -gt 0) { Resolve-ArgusSiteUrl -SiteId $missing -TenantSite $Context.Data['SharePointSites'] } else { @{} }
        $findings = @($near | ForEach-Object {
                $used = [double](Get-ArgusProperty $_ 'Storage Used (Byte)' 0)
                $allocated = [double](Get-ArgusProperty $_ 'Storage Allocated (Byte)' 0)
                $url = [string](Get-ArgusProperty $_ 'Site URL' '')
                $siteId = ([string](Get-ArgusProperty $_ 'Site Id' '')).ToLowerInvariant()
                if (-not $url -and $urls.ContainsKey($siteId)) { $url = $urls[$siteId] }
                $owner = [string](Get-ArgusProperty $_ 'Owner Principal Name' '')
                if (-not $owner) { $owner = [string](Get-ArgusProperty $_ 'Owner Display Name' '') }
                [pscustomobject]@{
                    SiteUrl     = $url
                    UsedGB      = [math]::Round($used / 1GB, 2)
                    AllocatedGB = [math]::Round($allocated / 1GB, 2)
                    UsedPercent = [math]::Round(100 * $used / $allocated, 1)
                    Owner       = if ($owner) { $owner } else { 'Not reported' }
                    SiteId      = $siteId
                }
            } | Sort-Object UsedPercent -Descending)
        $unresolved = @($findings | Where-Object { -not $_.SiteUrl }).Count
        $note = if ($unresolved -gt 0 -and -not $Context.Data['SharePointSites']) { " The URL of $unresolved site(s) could not be read: private group and channel sites need the SharePoint (PnP) connection." } else { '' }
        $status = if ($findings.Count -gt 0) { 'Failed' } else { 'Passed' }
        New-ArgusResult -Status $status -Findings $findings -EvaluatedCount $evaluated.Count `
            -Summary ('{AffectedCount} of {EvaluatedCount} SharePoint sites use more than {QuotaPercent}% of their storage quota.' + $note)
    }
}
