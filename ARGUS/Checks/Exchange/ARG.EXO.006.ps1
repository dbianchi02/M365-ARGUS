Register-ArgusCheck @{
    Id          = 'ARG.EXO.006'
    Title       = 'Mailboxes near their quota (more than {QuotaPercent}% of the warning quota)'
    Area        = 'Exchange'
    Category    = 'Storage'
    Severity    = 'Low'
    Description = 'User and shared mailboxes from the mailbox usage report (`getMailboxUsageDetail`, period D180) whose `Storage Used (Byte)` is more than **{QuotaPercent}%** of `Issue Warning Quota (Byte)` (the size at which the owner starts receiving warnings; `Prohibit Send Quota` is used when no warning quota is set). The findings also show how close the mailbox is to Prohibit Send. When Exchange Online is connected the mailbox type (user, shared, room, equipment) is shown. Deleted mailboxes and mailboxes without a quota are ignored. With concealed report names, or when the report returns no rows, the result is Investigate.'
    Rationale   = 'Users can react to quota warnings, shared mailboxes cannot: nobody receives their warnings, and they stop accepting mail without notice once they reach the limit. Mailboxes past or near the warning quota need an archive, a retention policy, a cleanup or, for shared mailboxes above 50 GB, a licence.'
    Remediation = @{
        Steps      = "1. Enable the archive mailbox (and auto-expanding archiving where licensed) for the listed mailboxes.`n2. Apply a retention policy that moves old items to the archive.`n3. For shared mailboxes above 50 GB, assign the licence that raises the quota."
        PortalUrl  = 'https://admin.exchange.microsoft.com/#/mailboxes'
    }
    References  = @(
        @{ Title = 'Microsoft 365 reports in the admin center - Mailbox usage'; Url = 'https://learn.microsoft.com/en-us/microsoft-365/admin/activity-reports/mailbox-usage' }
        @{ Title = 'Enable archive mailboxes'; Url = 'https://learn.microsoft.com/en-us/purview/enable-archive-mailboxes' }
    )
    Requires    = @{
        Services         = @('Graph')
        GraphScopes      = @('Reports.Read.All')
        DataSets         = @('MailboxUsage', 'ReportSettings')
        OptionalDataSets = @('Mailboxes')
    }
    Parameters  = @{ QuotaPercent = 90 }
    Tags        = @('Exchange', 'Storage', 'Reports')
    Test        = {
        param($Context)
        $rows = @($Context.Data['MailboxUsage'] | Where-Object { $_ -and (Get-ArgusProperty $_ 'Is Deleted' '') -ne 'True' })
        $issue = Get-ArgusReportIssue -ReportSettings $Context.Data['ReportSettings'] -Row $rows -ObjectName 'mailboxes near their quota'
        if ($issue) { return New-ArgusResult -Status Investigate -Summary $issue }

        $types = @{}
        foreach ($mailbox in @($Context.Data['Mailboxes'] | Where-Object { $_ })) {
            $upn = [string](Get-ArgusProperty $mailbox 'UserPrincipalName' '')
            if ($upn) { $types[$upn.ToLowerInvariant()] = [string](Get-ArgusProperty $mailbox 'RecipientTypeDetails' '') }
        }
        $limit = [double]$Context.Parameters.QuotaPercent
        $quotaOf = {
            param($Row)
            $warning = [double](Get-ArgusProperty $Row 'Issue Warning Quota (Byte)' 0)
            if ($warning -gt 0) { $warning } else { [double](Get-ArgusProperty $Row 'Prohibit Send Quota (Byte)' 0) }
        }
        $evaluated = @($rows | Where-Object { (& $quotaOf $_) -gt 0 })
        $findings = @($evaluated | ForEach-Object {
                $used = [double](Get-ArgusProperty $_ 'Storage Used (Byte)' 0)
                $warningPercent = [math]::Round(100 * $used / (& $quotaOf $_), 1)
                if ($warningPercent -le $limit) { return }
                $prohibit = [double](Get-ArgusProperty $_ 'Prohibit Send Quota (Byte)' 0)
                $upn = [string](Get-ArgusProperty $_ 'User Principal Name' '')
                [pscustomobject]@{
                    DisplayName        = Get-ArgusProperty $_ 'Display Name' ''
                    UserPrincipalName  = $upn
                    MailboxType        = if ($types.ContainsKey($upn.ToLowerInvariant())) { $types[$upn.ToLowerInvariant()] } else { '' }
                    UsedGB             = [math]::Round($used / 1GB, 2)
                    WarningQuotaGB     = [math]::Round([double](Get-ArgusProperty $_ 'Issue Warning Quota (Byte)' 0) / 1GB, 2)
                    ProhibitSendGB     = [math]::Round($prohibit / 1GB, 2)
                    PercentOfWarning   = $warningPercent
                    PercentOfProhibit  = if ($prohibit -gt 0) { [math]::Round(100 * $used / $prohibit, 1) } else { $null }
                    HasArchive         = Get-ArgusProperty $_ 'Has Archive' ''
                }
            } | Sort-Object PercentOfWarning -Descending)
        $shared = @($findings | Where-Object MailboxType -EQ 'SharedMailbox').Count
        $note = if ($types.Count -gt 0) { " ($shared shared)" } else { '' }
        $status = if ($findings.Count -gt 0) { 'Failed' } else { 'Passed' }
        New-ArgusResult -Status $status -Findings $findings -EvaluatedCount $evaluated.Count `
            -Summary ('{AffectedCount} of {EvaluatedCount} mailboxes use more than {QuotaPercent}% of their warning quota' + $note + '.')
    }
}
