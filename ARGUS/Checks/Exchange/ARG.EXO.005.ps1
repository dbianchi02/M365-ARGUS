Register-ArgusCheck @{
    Id          = 'ARG.EXO.005'
    Title       = 'User mailboxes of disabled accounts'
    Area        = 'Exchange'
    Category    = 'Lifecycle'
    Severity    = 'Low'
    Description = 'User mailboxes (`RecipientTypeDetails` = UserMailbox) whose Microsoft Entra account is disabled (`accountEnabled` = false). Mailboxes on litigation hold or with in-place holds are counted as kept on purpose and not listed. Shared, room and equipment mailboxes are out of scope (their accounts are meant to be disabled).'
    Rationale   = 'A disabled user with a live user mailbox is a leaver process that stopped halfway: mail keeps arriving, nobody reads it, and the mailbox usually keeps a licence. Converting it to a shared mailbox, delegating it or deleting it closes the process.'
    Remediation = @{
        Steps      = "1. Ask the manager whether incoming mail or content is still needed.`n2. Convert the mailbox to a shared mailbox and grant access to the manager, or set up forwarding for a limited period.`n3. Remove the licence and delete the account after the retention period; apply a hold first when legal requirements apply."
        PortalUrl  = 'https://admin.exchange.microsoft.com/#/mailboxes'
    }
    References  = @(
        @{ Title = 'Convert a user mailbox to a shared mailbox'; Url = 'https://learn.microsoft.com/en-us/microsoft-365/admin/email/convert-user-mailbox-to-shared-mailbox' }
        @{ Title = 'Remove a former employee from Microsoft 365'; Url = 'https://learn.microsoft.com/en-us/microsoft-365/admin/add-users/remove-former-employee' }
    )
    Requires    = @{
        Services    = @('Graph', 'Exchange')
        GraphScopes = @('User.Read.All')
        DataSets    = @('Users', 'Mailboxes')
    }
    Tags        = @('Exchange', 'Mailboxes', 'Lifecycle')
    Test        = {
        param($Context)
        $users = @{}
        foreach ($user in @($Context.Data['Users'])) {
            $id = [string](Get-ArgusProperty $user 'id' '')
            if ($id) { $users[$id] = $user }
        }
        $mailboxes = @($Context.Data['Mailboxes'] | Where-Object { (Get-ArgusProperty $_ 'RecipientTypeDetails' '') -eq 'UserMailbox' })
        $disabled = @($mailboxes | Where-Object {
                $user = $users[[string](Get-ArgusProperty $_ 'ExternalDirectoryObjectId' '')]
                $user -and (Get-ArgusProperty $user 'accountEnabled') -eq $false
            })
        $held = @($disabled | Where-Object { (Get-ArgusProperty $_ 'LitigationHoldEnabled' $false) -eq $true -or @(Get-ArgusProperty $_ 'InPlaceHolds' @()).Count -gt 0 })
        $findings = @($disabled | Where-Object { $_ -notin $held } | ForEach-Object {
                $user = $users[[string](Get-ArgusProperty $_ 'ExternalDirectoryObjectId' '')]
                [pscustomobject]@{
                    DisplayName        = Get-ArgusProperty $_ 'DisplayName' ''
                    UserPrincipalName  = Get-ArgusProperty $_ 'UserPrincipalName' ''
                    PrimarySmtpAddress = Get-ArgusProperty $_ 'PrimarySmtpAddress' ''
                    Licensed           = if (@(Get-ArgusProperty $user 'assignedLicenses' @()).Count -gt 0) { 'Yes' } else { 'No' }
                    ArchiveStatus      = Get-ArgusProperty $_ 'ArchiveStatus' ''
                    ObjectId           = Get-ArgusProperty $_ 'ExternalDirectoryObjectId' ''
                }
            } | Sort-Object UserPrincipalName)
        $note = if ($held.Count -gt 0) { " $($held.Count) more on hold are kept on purpose." } else { '' }
        $status = if ($findings.Count -gt 0) { 'Failed' } else { 'Passed' }
        New-ArgusResult -Status $status -Findings $findings -EvaluatedCount $mailboxes.Count `
            -Summary ('{AffectedCount} of {EvaluatedCount} user mailboxes belong to disabled accounts and are not on hold.' + $note)
    }
}
