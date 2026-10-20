Register-ArgusCheck @{
    Id          = 'ARG.EXO.007'
    Title       = 'Mailboxes with forwarding configured (inventory)'
    Area        = 'Exchange'
    Category    = 'Mail flow governance'
    Severity    = 'Low'
    Description = 'Inventory of mailboxes with mailbox-level forwarding (`ForwardingSmtpAddress` or `ForwardingAddress` in `Get-EXOMailbox`). A forwarding SMTP address whose domain is not a verified domain of the tenant is marked External; `ForwardingAddress` points to a recipient in the directory (it can be a mail contact outside the organisation). Inbox rules are not evaluated. Listed as To review: forwarding is often legitimate, but each one should have an owner and a reason, and forwarding left on leaver mailboxes should be removed.'
    Rationale   = 'Forwarding set years ago keeps copying mail to addresses nobody reviews, sometimes outside the organisation and after the owner left. Knowing where mail is forwarded, and why, is part of mailbox lifecycle governance; blocking automatic external forwarding is a security control outside the scope of ARGUS.'
    Remediation = @{
        Steps      = "1. Review each forwarding with the mailbox owner or manager: target, reason, still needed.`n2. Remove forwarding that is no longer needed (Exchange admin center > Mailboxes > mailbox > Mail flow settings > Email forwarding).`n3. For leavers, replace forwarding with a shared mailbox or delegate access for a limited period."
        PowerShell = "# Sample only - review before running.`nConnect-ExchangeOnline`nSet-Mailbox -Identity '<mailbox>' -ForwardingSmtpAddress `$null -ForwardingAddress `$null -DeliverToMailboxAndForward `$false"
        PortalUrl  = 'https://admin.exchange.microsoft.com/#/mailboxes'
    }
    References  = @(
        @{ Title = 'Configure email forwarding for a mailbox'; Url = 'https://learn.microsoft.com/en-us/exchange/recipients-in-exchange-online/manage-user-mailboxes/configure-email-forwarding' }
        @{ Title = 'Get-EXOMailbox'; Url = 'https://learn.microsoft.com/en-us/powershell/module/exchangepowershell/get-exomailbox' }
    )
    Requires    = @{
        Services    = @('Graph', 'Exchange')
        GraphScopes = @('Organization.Read.All')
        DataSets    = @('Mailboxes', 'Organization')
    }
    Tags        = @('Exchange', 'Mailboxes', 'MailFlow', 'Inventory')
    Test        = {
        param($Context)
        $domains = @(Get-ArgusProperty $Context.Data['Organization'] 'verifiedDomains' @() | ForEach-Object { ([string](Get-ArgusProperty $_ 'name' '')).ToLowerInvariant() } | Where-Object { $_ })
        $mailboxes = @($Context.Data['Mailboxes'])
        $findings = @($mailboxes | ForEach-Object {
                $smtp = [string](Get-ArgusProperty $_ 'ForwardingSmtpAddress' '')
                $recipient = [string](Get-ArgusProperty $_ 'ForwardingAddress' '')
                if (-not $smtp -and -not $recipient) { return }
                $address = $smtp -replace '^smtp:', ''
                $domain = if ($address -match '@(.+)$') { $Matches[1].ToLowerInvariant() } else { '' }
                $scope = if ($address) { if ($domain -and $domain -notin $domains) { 'External' } else { 'Internal' } } else { 'Directory recipient' }
                [pscustomobject]@{
                    DisplayName        = Get-ArgusProperty $_ 'DisplayName' ''
                    PrimarySmtpAddress = Get-ArgusProperty $_ 'PrimarySmtpAddress' ''
                    MailboxType        = Get-ArgusProperty $_ 'RecipientTypeDetails' ''
                    ForwardsTo         = if ($address) { $address } else { $recipient }
                    Target             = $scope
                    KeepsCopy          = [bool](Get-ArgusProperty $_ 'DeliverToMailboxAndForward' $false)
                    ObjectId           = Get-ArgusProperty $_ 'ExternalDirectoryObjectId' ''
                }
            } | Sort-Object @{ Expression = { $_.Target -ne 'External' } }, DisplayName)
        if ($findings.Count -eq 0) {
            return New-ArgusResult -Status Passed -EvaluatedCount $mailboxes.Count -AffectedCount 0 -Summary 'None of the {EvaluatedCount} mailboxes has mailbox-level forwarding.'
        }
        $external = @($findings | Where-Object Target -EQ 'External').Count
        New-ArgusResult -Status Investigate -Findings $findings -EvaluatedCount $mailboxes.Count `
            -Summary "{AffectedCount} of {EvaluatedCount} mailboxes forward mail ($external to external addresses); review each one."
    }
}
