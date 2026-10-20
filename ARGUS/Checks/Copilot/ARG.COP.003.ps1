Register-ArgusCheck @{
    Id          = 'ARG.COP.003'
    Title       = 'Copilot licences unused for more than {InactiveDays} days'
    Area        = 'Copilot'
    Category    = 'Licence governance'
    Severity    = 'Medium'
    Description = 'Users from the Microsoft 365 Copilot usage report (`copilot/reports/getMicrosoft365CopilotUsageUserDetail`, period D180), which lists only users with a Microsoft 365 Copilot licence, whose `Last Activity Date` is older than {InactiveDays} days or empty (no Copilot use in the last 180 days). With concealed report names, or when the report returns no rows, the result is To review. Skipped when no Microsoft 365 Copilot licence is detected.'
    Rationale   = 'Copilot licences are among the most expensive seats in Microsoft 365. Seats that are not used should go to people on the waiting list, or the user needs adoption support; either way the licence decision should be revisited.'
    Remediation = @{
        Steps      = "1. Ask the users or their managers whether Copilot is still needed; offer training where adoption is the issue.`n2. Remove the licence (or the user from the licensing group) where it is not needed and reassign it.`n3. Review the Copilot usage report monthly to keep seats with active users."
        PortalUrl  = 'https://admin.microsoft.com/#/reportsUsage/MicrosoftCopilot'
    }
    References  = @(
        @{ Title = 'Microsoft 365 reports - Microsoft 365 Copilot usage'; Url = 'https://learn.microsoft.com/en-us/microsoft-365/admin/activity-reports/microsoft-365-copilot-usage' }
        @{ Title = 'getMicrosoft365CopilotUsageUserDetail'; Url = 'https://learn.microsoft.com/en-us/microsoft-365/copilot/extensibility/api/admin-settings/reports/copilotreportroot-getmicrosoft365copilotusageuserdetail' }
    )
    Requires    = @{
        Services    = @('Graph')
        GraphScopes = @('Reports.Read.All')
        Licenses    = @('M365_COPILOT_APPS')
        DataSets    = @('CopilotUsage', 'ReportSettings')
    }
    Parameters  = @{ InactiveDays = 30 }
    Tags        = @('Copilot', 'Licensing', 'Reports')
    Test        = {
        param($Context)
        $rows = @($Context.Data['CopilotUsage'] | Where-Object { $_ })
        $issue = Get-ArgusReportIssue -ReportSettings $Context.Data['ReportSettings'] -Row $rows -ObjectName 'Copilot users'
        if ($issue) { return New-ArgusResult -Status Investigate -Summary $issue }

        $days = [int]$Context.Parameters.InactiveDays
        $cutoff = $Context.Now.Date.AddDays(-$days)
        $findings = @($rows | ForEach-Object {
                $last = ConvertTo-ArgusUtcDate (Get-ArgusProperty $_ 'Last Activity Date' '')
                if ($last -and $last -ge $cutoff) { return }
                [pscustomobject]@{
                    DisplayName       = Get-ArgusProperty $_ 'Display Name' ''
                    UserPrincipalName = Get-ArgusProperty $_ 'User Principal Name' ''
                    LastActivity      = Format-ArgusDate $last 'None in the last 180 days'
                    DaysInactive      = if ($last) { [int]($Context.Now.Date - $last.Date).TotalDays } else { $null }
                    LastChatActivity  = Format-ArgusDate (ConvertTo-ArgusUtcDate (Get-ArgusProperty $_ 'Copilot Chat Last Activity Date' '')) 'None'
                }
            } | Sort-Object @{ Expression = { if ($null -eq $_.DaysInactive) { [int]::MaxValue } else { $_.DaysInactive } }; Descending = $true }, UserPrincipalName)
        $status = if ($findings.Count -gt 0) { 'Failed' } else { 'Passed' }
        New-ArgusResult -Status $status -Findings $findings -EvaluatedCount $rows.Count `
            -Summary '{AffectedCount} of {EvaluatedCount} users with a Copilot licence have not used Copilot for more than {InactiveDays} days.'
    }
}
