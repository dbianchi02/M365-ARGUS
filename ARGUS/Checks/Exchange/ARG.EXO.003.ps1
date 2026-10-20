Register-ArgusCheck @{
    Id          = 'ARG.EXO.003'
    Title       = 'Inactive shared mailboxes (more than {InactiveDays} days)'
    Area        = 'Exchange'
    Category    = 'Lifecycle'
    Severity    = 'Low'
    Description = 'Shared mailboxes (Exchange Online) whose `Last Activity Date` in the mailbox usage report (`getMailboxUsageDetail`, period D180) is older than **{InactiveDays}** days, or empty for mailboxes created before that. The report has no recipient type, so shared mailboxes are identified through Exchange Online. With concealed report names, or when the report returns no rows, the result is Investigate.'
    Rationale   = 'Shared mailboxes created for projects, events or old processes outlive their purpose. Unused ones keep permissions, addresses and sometimes licences that nobody reviews.'
    Remediation = @{
        Steps      = "1. Check with the delegates whether the mailbox is still needed.`n2. If it is not, set an auto-reply pointing to the right contact, remove permissions and licences, then delete it after your retention period.`n3. If it must be kept for records, apply a retention policy or hold."
        PortalUrl  = 'https://admin.exchange.microsoft.com/#/mailboxes'
    }
    References  = @(
        @{ Title = 'Microsoft 365 reports in the admin center - Mailbox usage'; Url = 'https://learn.microsoft.com/en-us/microsoft-365/admin/activity-reports/mailbox-usage' }
        @{ Title = 'About shared mailboxes'; Url = 'https://learn.microsoft.com/en-us/microsoft-365/admin/email/about-shared-mailboxes' }
    )
    Requires    = @{
        Services    = @('Graph', 'Exchange')
        GraphScopes = @('Reports.Read.All')
        DataSets    = @('MailboxUsage', 'ReportSettings', 'Mailboxes')
    }
    Parameters  = @{ InactiveDays = 90 }
    Tags        = @('Exchange', 'Mailboxes', 'Lifecycle', 'Reports')
    Test        = {
        param($Context)
        $rows = @($Context.Data['MailboxUsage'] | Where-Object { $_ -and (Get-ArgusProperty $_ 'Is Deleted' '') -ne 'True' })
        $issue = Get-ArgusReportIssue -ReportSettings $Context.Data['ReportSettings'] -Row $rows -ObjectName 'inactive shared mailboxes'
        if ($issue) { return New-ArgusResult -Status Investigate -Summary $issue }

        $shared = @{}
        foreach ($mailbox in @($Context.Data['Mailboxes'] | Where-Object { (Get-ArgusProperty $_ 'RecipientTypeDetails' '') -eq 'SharedMailbox' })) {
            $upn = [string](Get-ArgusProperty $mailbox 'UserPrincipalName' '')
            if ($upn) { $shared[$upn.ToLowerInvariant()] = $mailbox }
        }
        $threshold = $Context.Now.AddDays(-[int]$Context.Parameters.InactiveDays)
        $evaluated = @($rows | Where-Object {
                if (-not $shared.ContainsKey(([string](Get-ArgusProperty $_ 'User Principal Name' '')).ToLowerInvariant())) { return $false }
                $created = ConvertTo-ArgusUtcDate (Get-ArgusProperty $_ 'Created Date' '')
                -not $created -or $created -le $threshold
            })
        $findings = @($evaluated | ForEach-Object {
                $last = ConvertTo-ArgusUtcDate (Get-ArgusProperty $_ 'Last Activity Date' '')
                if ($last -and $last -ge $threshold) { return }
                $mailbox = $shared[([string](Get-ArgusProperty $_ 'User Principal Name' '')).ToLowerInvariant()]
                [pscustomobject]@{
                    DisplayName        = Get-ArgusProperty $_ 'Display Name' ''
                    PrimarySmtpAddress = Get-ArgusProperty $mailbox 'PrimarySmtpAddress' ''
                    LastActivity       = Format-ArgusDate $last 'None in the last 180 days'
                    DaysInactive       = if ($last) { [int]($Context.Now - $last).TotalDays } else { $null }
                    StorageUsedGB      = [math]::Round([double](Get-ArgusProperty $_ 'Storage Used (Byte)' 0) / 1GB, 2)
                    ObjectId           = Get-ArgusProperty $mailbox 'ExternalDirectoryObjectId' ''
                }
            } | Sort-Object @{ Expression = { if ($null -eq $_.DaysInactive) { [int]::MaxValue } else { $_.DaysInactive } }; Descending = $true }, DisplayName)
        $status = if ($findings.Count -gt 0) { 'Failed' } else { 'Passed' }
        New-ArgusResult -Status $status -Findings $findings -EvaluatedCount $evaluated.Count `
            -Summary '{AffectedCount} of {EvaluatedCount} shared mailboxes have had no activity for {InactiveDays}+ days.'
    }
}
