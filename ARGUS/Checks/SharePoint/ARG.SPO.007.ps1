Register-ArgusCheck @{
    Id          = 'ARG.SPO.007'
    Title       = 'Sites without a sensitivity label'
    Area        = 'SharePoint'
    Category    = 'Site governance'
    Severity    = 'Low'
    Description = 'Site collections (PnP.PowerShell `Get-PnPTenantSite`, OneDrive and system sites excluded) without a sensitivity label (`SensitivityLabel` empty). When no site has a label at all, sensitivity labels are probably not used for sites and groups: the result is To review instead of Failed. Needs `Connect-Argus -Service SharePoint`; otherwise the check is Skipped.'
    Rationale   = 'A container label sets the privacy, external sharing and guest access of a site in one place and tells users and Copilot how sensitive its content is. Once labels are in use, unlabelled sites are the ones that escape those controls and the classification.'
    Remediation = @{
        Steps      = "1. If labels are not used for sites yet, plan container labels with the compliance team (Microsoft Purview > Information protection).`n2. Apply the appropriate label to each listed site (SharePoint admin center > Active sites > site > Settings > Sensitivity), or to its Microsoft 365 group.`n3. Consider a default label and requiring a label when sites and groups are created."
        PowerShell = "# Sample only - review before running.`nConnect-PnPOnline -Url 'https://<tenant>-admin.sharepoint.com' -Interactive -ClientId '<app id>'`nSet-PnPTenantSite -Identity '<site url>' -SensitivityLabel '<label id>'"
        PortalUrl  = 'https://admin.microsoft.com/sharepoint?page=siteManagement&modern=true'
    }
    References  = @(
        @{ Title = 'Use sensitivity labels to protect content in Microsoft Teams, Microsoft 365 groups, and SharePoint sites'; Url = 'https://learn.microsoft.com/en-us/purview/sensitivity-labels-teams-groups-sites' }
        @{ Title = 'Get-SPOSite: SensitivityLabel'; Url = 'https://learn.microsoft.com/en-us/powershell/module/microsoft.online.sharepoint.powershell/get-sposite' }
    )
    Requires    = @{
        Services = @('Graph', 'SharePoint')
        DataSets = @('SharePointSites')
    }
    Tags        = @('SharePoint', 'Classification', 'Inventory')
    Test        = {
        param($Context)
        $skipTemplates = 'SPSPERS*', 'SPSMSITEHOST*', 'RedirectSite*', 'APPCATALOG*', 'SRCHCEN*', 'POINTPUBLISHINGHUB*', 'POINTPUBLISHINGTOPIC*', 'TEAMCHANNEL*'
        $sites = @($Context.Data['SharePointSites'] | Where-Object {
                $template = [string](Get-ArgusProperty $_ 'Template' '')
                $_ -and -not @($skipTemplates | Where-Object { $template -like $_ }).Count
            })
        $labelled = @($sites | Where-Object { [string](Get-ArgusProperty $_ 'SensitivityLabel' '') -notin '', [guid]::Empty.ToString() })
        $findings = @($sites | Where-Object { $_ -notin $labelled } | ForEach-Object {
                [pscustomobject]@{
                    Title        = Get-ArgusProperty $_ 'Title' ''
                    SiteUrl      = Get-ArgusProperty $_ 'Url' ''
                    Template     = Get-ArgusProperty $_ 'Template' ''
                    Owner        = Get-ArgusProperty $_ 'Owner' ''
                    LastModified = Format-ArgusDate (Get-ArgusProperty $_ 'LastContentModifiedDate' '')
                }
            } | Sort-Object SiteUrl)
        if ($findings.Count -eq 0) {
            return New-ArgusResult -Status Passed -EvaluatedCount $sites.Count -AffectedCount 0 -Summary 'Every one of the {EvaluatedCount} sites has a sensitivity label.'
        }
        if ($labelled.Count -eq 0) {
            return New-ArgusResult -Status Investigate -Findings $findings -EvaluatedCount $sites.Count `
                -Summary 'None of the {EvaluatedCount} sites has a sensitivity label: confirm whether container labels are planned for sites and groups.'
        }
        New-ArgusResult -Status Failed -Findings $findings -EvaluatedCount $sites.Count `
            -Summary "{AffectedCount} of {EvaluatedCount} sites have no sensitivity label ($($labelled.Count) are labelled)."
    }
}
