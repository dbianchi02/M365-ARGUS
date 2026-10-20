Register-ArgusCheck @{
    Id          = 'ARG.ENT.004'
    Title       = 'Guests that never accepted the invitation (more than {PendingDays} days)'
    Area        = 'EntraID'
    Category    = 'External identities'
    Severity    = 'Medium'
    Description = 'Guest accounts whose `externalUserState` is still **PendingAcceptance** more than **{PendingDays}** days after they were invited (`externalUserStateChangeDateTime`, or `createdDateTime` when not set).'
    Rationale   = 'Unredeemed invitations clutter the directory, are often typos or abandoned collaborations, and can be redeemed later by whoever controls the mailbox.'
    Remediation = @{
        Steps      = "1. Check with the person who invited the guest whether the collaboration is still needed.`n2. Resend the invitation if it is, otherwise delete the guest account."
        PowerShell = "# Sample only - review before running. Deletes one pending guest.`nConnect-MgGraph -Scopes 'User.ReadWrite.All'`nRemove-MgUser -UserId '<ObjectId>'"
        PortalUrl  = 'https://entra.microsoft.com/'
    }
    References  = @(
        @{ Title = 'Microsoft Entra B2B collaboration invitation redemption'; Url = 'https://learn.microsoft.com/en-us/entra/external-id/redemption-experience' }
    )
    Requires    = @{
        Services    = @('Graph')
        GraphScopes = @('User.Read.All')
        DataSets    = @('Users')
    }
    Parameters  = @{ PendingDays = 30 }
    Tags        = @('Guests', 'Lifecycle')
    Test        = {
        param($Context)
        $threshold = $Context.Now.AddDays(-[int]$Context.Parameters.PendingDays)
        $guests = @($Context.Data['Users'] | Where-Object { (Get-ArgusProperty $_ 'userType') -eq 'Guest' })
        $findings = foreach ($guest in $guests) {
            if ((Get-ArgusProperty $guest 'externalUserState') -ne 'PendingAcceptance') { continue }
            $since = ConvertTo-ArgusUtcDate (Get-ArgusProperty $guest 'externalUserStateChangeDateTime')
            if (-not $since) { $since = ConvertTo-ArgusUtcDate (Get-ArgusProperty $guest 'createdDateTime') }
            if (-not $since -or $since -gt $threshold) { continue }
            [pscustomobject]@{
                DisplayName = Get-ArgusProperty $guest 'displayName' ''
                Mail        = Get-ArgusProperty $guest 'mail' ''
                InvitedOn   = Format-ArgusDate $since
                DaysPending = [int]($Context.Now - $since).TotalDays
                ObjectId    = Get-ArgusProperty $guest 'id' ''
            }
        }
        $findings = @($findings | Sort-Object DaysPending -Descending)
        $status = if ($findings.Count -gt 0) { 'Failed' } else { 'Passed' }
        New-ArgusResult -Status $status -Findings $findings -EvaluatedCount $guests.Count `
            -Summary '{AffectedCount} of {EvaluatedCount} guests have not accepted their invitation for {PendingDays}+ days.'
    }
}
