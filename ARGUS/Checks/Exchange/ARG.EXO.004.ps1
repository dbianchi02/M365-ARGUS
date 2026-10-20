Register-ArgusCheck @{
    Id          = 'ARG.EXO.004'
    Title       = 'Inactive user mailboxes (more than {InactiveDays} days)'
    Area        = 'Exchange'
    Category    = 'Lifecycle'
    Severity    = 'Low'
    Description = 'Mailboxes whose `Last Activity Date` in the mailbox usage report (`getMailboxUsageDetail`, period D180) is older than **{InactiveDays}** days, or empty for mailboxes created before that. When Exchange Online is connected only user mailboxes are evaluated; otherwise the report also contains shared mailboxes, which is noted in the summary. With concealed report names, or when the report returns no rows, the result is Investigate.'
    Rationale   = 'A user mailbox nobody uses usually belongs to a leaver or a forgotten test account: it keeps a licence, mail and permissions without a reason.'
    Remediation = @{
        Steps      = "1. Confirm with the manager whether the mailbox is still needed.`n2. If the content must be kept, convert it to a shared mailbox or apply a hold, then remove the licence.`n3. Otherwise disable and delete the account after your retention period."
        PortalUrl  = 'https://admin.exchange.microsoft.com/#/mailboxes'
    }
    References  = @(
        @{ Title = 'Microsoft 365 reports in the admin center - Mailbox usage'; Url = 'https://learn.microsoft.com/en-us/microsoft-365/admin/activity-reports/mailbox-usage' }
        @{ Title = 'Convert a user mailbox to a shared mailbox'; Url = 'https://learn.microsoft.com/en-us/microsoft-365/admin/email/convert-user-mailbox-to-shared-mailbox' }
    )
    Requires    = @{
        Services         = @('Graph')
        GraphScopes      = @('Reports.Read.All')
        DataSets         = @('MailboxUsage', 'ReportSettings')
        OptionalDataSets = @('Mailboxes')
    }
    Parameters  = @{ InactiveDays = 90 }
    Tags        = @('Exchange', 'Lifecycle', 'Reports')
    Test        = {
        param($Context)
        $rows = @($Context.Data['MailboxUsage'] | Where-Object { $_ -and (Get-ArgusProperty $_ 'Is Deleted' '') -ne 'True' })
        $issue = Get-ArgusReportIssue -ReportSettings $Context.Data['ReportSettings'] -Row $rows -ObjectName 'inactive mailboxes'
        if ($issue) { return New-ArgusResult -Status Investigate -Summary $issue }

        $note = ''
        if ($Context.Data.ContainsKey('Mailboxes')) {
            $userMailboxes = @{}
            foreach ($mailbox in @($Context.Data['Mailboxes'] | Where-Object { (Get-ArgusProperty $_ 'RecipientTypeDetails' '') -eq 'UserMailbox' })) {
                $upn = [string](Get-ArgusProperty $mailbox 'UserPrincipalName' '')
                if ($upn) { $userMailboxes[$upn.ToLowerInvariant()] = $true }
            }
            $rows = @($rows | Where-Object { $userMailboxes.ContainsKey(([string](Get-ArgusProperty $_ 'User Principal Name' '')).ToLowerInvariant()) })
        }
        else {
            $note = ' Exchange Online is not connected, so shared mailboxes could not be excluded.'
        }

        $threshold = $Context.Now.AddDays(-[int]$Context.Parameters.InactiveDays)
        $evaluated = @($rows | Where-Object { $created = ConvertTo-ArgusUtcDate (Get-ArgusProperty $_ 'Created Date' ''); -not $created -or $created -le $threshold })
        $findings = @($evaluated | ForEach-Object {
                $last = ConvertTo-ArgusUtcDate (Get-ArgusProperty $_ 'Last Activity Date' '')
                if ($last -and $last -ge $threshold) { return }
                [pscustomobject]@{
                    DisplayName       = Get-ArgusProperty $_ 'Display Name' ''
                    UserPrincipalName = Get-ArgusProperty $_ 'User Principal Name' ''
                    LastActivity      = Format-ArgusDate $last 'None in the last 180 days'
                    DaysInactive      = if ($last) { [int]($Context.Now - $last).TotalDays } else { $null }
                    StorageUsedGB     = [math]::Round([double](Get-ArgusProperty $_ 'Storage Used (Byte)' 0) / 1GB, 2)
                    Created           = Format-ArgusDate (Get-ArgusProperty $_ 'Created Date' '')
                }
            } | Sort-Object @{ Expression = { if ($null -eq $_.DaysInactive) { [int]::MaxValue } else { $_.DaysInactive } }; Descending = $true }, UserPrincipalName)
        $status = if ($findings.Count -gt 0) { 'Failed' } else { 'Passed' }
        New-ArgusResult -Status $status -Findings $findings -EvaluatedCount $evaluated.Count `
            -Summary ('{AffectedCount} of {EvaluatedCount} mailboxes have had no activity for {InactiveDays}+ days.' + $note)
    }
}
