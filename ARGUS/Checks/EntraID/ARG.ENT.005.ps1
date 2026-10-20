Register-ArgusCheck @{
    Id          = 'ARG.ENT.005'
    Title       = 'Guests inactive for more than {InactiveDays} days'
    Area        = 'EntraID'
    Category    = 'External identities'
    Severity    = 'Medium'
    Description = 'Enabled guest accounts that accepted their invitation but have not signed in for **{InactiveDays}** days, including guests that never signed in and were added more than {InactiveDays} days ago. Guests still pending acceptance are covered by ARG.ENT.004.'
    Rationale   = 'Guests keep access to Teams, sites and files after the collaboration has ended. Removing inactive guests limits what external people can still reach.'
    Remediation = @{
        Steps      = "1. Confirm with the sponsor or group owners that the collaboration has ended.`n2. Block sign-in or delete the guest account.`n3. Consider recurring access reviews for guests (Entra ID P2 or ID Governance)."
        PowerShell = "# Sample only - review before running. Deletes one guest account (restorable for 30 days).`nConnect-MgGraph -Scopes 'User.ReadWrite.All'`nRemove-MgUser -UserId '<ObjectId>'"
        PortalUrl  = 'https://entra.microsoft.com/'
    }
    References  = @(
        @{ Title = 'Manage inactive user accounts in Microsoft Entra ID'; Url = 'https://learn.microsoft.com/en-us/entra/identity/monitoring-health/howto-manage-inactive-user-accounts' }
        @{ Title = 'Manage guest access with access reviews'; Url = 'https://learn.microsoft.com/en-us/entra/id-governance/manage-guest-access-with-access-reviews' }
    )
    Requires    = @{
        Services    = @('Graph')
        GraphScopes = @('User.Read.All', 'AuditLog.Read.All')
        Licenses    = @('AAD_PREMIUM')
        DataSets    = @('Users')
    }
    Parameters  = @{ InactiveDays = 90 }
    Tags        = @('Guests', 'Lifecycle')
    Test        = {
        param($Context)
        $days = [int]$Context.Parameters.InactiveDays
        $threshold = $Context.Now.AddDays(-$days)
        $users = @($Context.Data['Users'])
        if (-not (Test-ArgusSignInActivity -User $users)) {
            return New-ArgusResult -Status Skipped -SkipReason 'Sign-in activity is not available for this tenant or account (Entra ID P1 and AuditLog.Read.All are needed).'
        }

        $evaluated = @($users | Where-Object {
                (Get-ArgusProperty $_ 'userType') -eq 'Guest' -and (Get-ArgusProperty $_ 'accountEnabled') -eq $true -and
                (Get-ArgusProperty $_ 'externalUserState') -ne 'PendingAcceptance'
            })
        $findings = foreach ($user in $evaluated) {
            $created = ConvertTo-ArgusUtcDate (Get-ArgusProperty $user 'createdDateTime')
            if ($created -and $created -gt $threshold) { continue }
            $last = Get-ArgusUserLastSignIn -User $user
            if ($last -and $last -ge $threshold) { continue }
            [pscustomobject]@{
                DisplayName       = Get-ArgusProperty $user 'displayName' ''
                Mail              = Get-ArgusProperty $user 'mail' ''
                UserPrincipalName = Get-ArgusProperty $user 'userPrincipalName' ''
                LastSignIn        = Format-ArgusDate $last 'Never'
                DaysInactive      = if ($last) { [int]($Context.Now - $last).TotalDays } elseif ($created) { [int]($Context.Now - $created).TotalDays } else { $null }
                Invited           = Format-ArgusDate $created
                ObjectId          = Get-ArgusProperty $user 'id' ''
            }
        }
        $findings = @($findings | Sort-Object DaysInactive -Descending)
        $status = if ($findings.Count -gt 0) { 'Failed' } else { 'Passed' }
        New-ArgusResult -Status $status -Findings $findings -EvaluatedCount $evaluated.Count `
            -Summary '{AffectedCount} of {EvaluatedCount} active guests have not signed in for {InactiveDays}+ days.'
    }
}
