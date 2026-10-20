Register-ArgusCheck @{
    Id          = 'ARG.EXO.002'
    Title       = 'Shared mailboxes without delegates'
    Area        = 'Exchange'
    Category    = 'Ownership'
    Severity    = 'Low'
    Description = 'Shared mailboxes with no explicit FullAccess permission (`Get-EXOMailboxPermission`: not inherited, not denied, `NT AUTHORITY\SELF` ignored). Send As and Send on Behalf permissions are not considered: without FullAccess nobody can open the mailbox. One Exchange call per shared mailbox.'
    Rationale   = 'A shared mailbox nobody can open still receives mail that nobody reads, often from customers or suppliers. Every shared mailbox should have named people responsible for it.'
    Remediation = @{
        Steps      = "1. Find out who should handle the mailbox (department, previous owners, mail content).`n2. Grant FullAccess to those people, preferably through a mail-enabled security group.`n3. If the mailbox is no longer needed, set an auto-reply, then remove it after your retention period."
        PowerShell = "# Sample only - review before running.`nConnect-ExchangeOnline`nAdd-MailboxPermission -Identity '<shared mailbox>' -User '<user or group>' -AccessRights FullAccess -AutoMapping `$true"
        PortalUrl  = 'https://admin.exchange.microsoft.com/#/mailboxes'
    }
    References  = @(
        @{ Title = 'Manage permissions for recipients in Exchange Online'; Url = 'https://learn.microsoft.com/en-us/exchange/recipients-in-exchange-online/manage-permissions-for-recipients' }
        @{ Title = 'Get-EXOMailboxPermission'; Url = 'https://learn.microsoft.com/en-us/powershell/module/exchangepowershell/get-exomailboxpermission' }
    )
    Requires    = @{
        Services = @('Graph', 'Exchange')
        DataSets = @('Mailboxes', 'SharedMailboxPermissions')
    }
    Tags        = @('Exchange', 'Mailboxes', 'Ownership')
    Test        = {
        param($Context)
        $permissions = $Context.Data['SharedMailboxPermissions']
        $shared = @($Context.Data['Mailboxes'] | Where-Object { (Get-ArgusProperty $_ 'RecipientTypeDetails' '') -eq 'SharedMailbox' })
        $findings = @($shared | ForEach-Object {
                $key = [string](Get-ArgusProperty $_ 'ExternalDirectoryObjectId' '')
                if (-not $key) { $key = [string](Get-ArgusProperty $_ 'UserPrincipalName' '') }
                if ($permissions -and $permissions.Contains($key) -and @($permissions[$key]).Count -gt 0) { return }
                [pscustomobject]@{
                    DisplayName        = Get-ArgusProperty $_ 'DisplayName' ''
                    PrimarySmtpAddress = Get-ArgusProperty $_ 'PrimarySmtpAddress' ''
                    UserPrincipalName  = Get-ArgusProperty $_ 'UserPrincipalName' ''
                    ObjectId           = Get-ArgusProperty $_ 'ExternalDirectoryObjectId' ''
                }
            } | Sort-Object DisplayName)
        $status = if ($findings.Count -gt 0) { 'Failed' } else { 'Passed' }
        New-ArgusResult -Status $status -Findings $findings -EvaluatedCount $shared.Count `
            -Summary '{AffectedCount} of {EvaluatedCount} shared mailboxes have no FullAccess delegate.'
    }
}
