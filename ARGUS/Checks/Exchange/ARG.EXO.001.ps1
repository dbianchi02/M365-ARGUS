Register-ArgusCheck @{
    Id          = 'ARG.EXO.001'
    Title       = 'Shared mailboxes with sign-in enabled'
    Area        = 'Exchange'
    Category    = 'Mailbox governance'
    Severity    = 'Medium'
    Description = 'Shared mailboxes (Exchange Online) whose user account in Microsoft Entra ID is enabled (`accountEnabled` = true). People access shared mailboxes through their own accounts and mailbox permissions; the account of the shared mailbox itself does not need to sign in.'
    Rationale   = 'An enabled shared mailbox account has a password that nobody owns, is often excluded from reviews, and lets anyone who knows the password sign in directly instead of through audited delegate access.'
    Remediation = @{
        Steps      = "1. Confirm that nobody signs in directly to the shared mailbox account (check its sign-in logs).`n2. Block sign-in for the account (Microsoft 365 admin center > Users > Block sign-in); mailbox access through permissions keeps working.`n3. Make blocking sign-in part of the process that creates or converts shared mailboxes."
        PowerShell = "# Sample only - review before running. Blocks sign-in for one shared mailbox account.`nConnect-MgGraph -Scopes 'User.ReadWrite.All'`nUpdate-MgUser -UserId '<ObjectId>' -AccountEnabled:`$false"
        PortalUrl  = 'https://admin.microsoft.com/Adminportal/Home#/SharedMailbox'
    }
    References  = @(
        @{ Title = 'About shared mailboxes'; Url = 'https://learn.microsoft.com/en-us/microsoft-365/admin/email/about-shared-mailboxes' }
        @{ Title = 'Block shared mailbox accounts from signing in'; Url = 'https://learn.microsoft.com/en-us/microsoft-365/admin/email/create-a-shared-mailbox#block-sign-in-for-shared-mailbox-accounts' }
    )
    Requires    = @{
        Services    = @('Graph', 'Exchange')
        GraphScopes = @('User.Read.All')
        DataSets    = @('Users', 'Mailboxes')
    }
    Tags        = @('Exchange', 'Mailboxes')
    Test        = {
        param($Context)
        $users = @{}
        foreach ($user in @($Context.Data['Users'])) { $users[([string](Get-ArgusProperty $user 'id' '')).ToLowerInvariant()] = $user }
        $shared = @($Context.Data['Mailboxes'] | Where-Object { (Get-ArgusProperty $_ 'RecipientTypeDetails' '') -eq 'SharedMailbox' })
        $findings = @($shared | ForEach-Object {
                $id = ([string](Get-ArgusProperty $_ 'ExternalDirectoryObjectId' '')).ToLowerInvariant()
                if (-not $users.ContainsKey($id) -or (Get-ArgusProperty $users[$id] 'accountEnabled') -ne $true) { return }
                [pscustomobject]@{
                    DisplayName        = Get-ArgusProperty $_ 'DisplayName' ''
                    PrimarySmtpAddress = Get-ArgusProperty $_ 'PrimarySmtpAddress' ''
                    UserPrincipalName  = Get-ArgusProperty $users[$id] 'userPrincipalName' ''
                    Licensed           = if (@(Get-ArgusProperty $users[$id] 'assignedLicenses' @()).Count) { 'Yes' } else { 'No' }
                    ObjectId           = Get-ArgusProperty $users[$id] 'id' ''
                }
            } | Sort-Object DisplayName)
        $status = if ($findings.Count -gt 0) { 'Failed' } else { 'Passed' }
        New-ArgusResult -Status $status -Findings $findings -EvaluatedCount $shared.Count `
            -Summary '{AffectedCount} of {EvaluatedCount} shared mailboxes have sign-in enabled.'
    }
}
