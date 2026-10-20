Register-ArgusCheck @{
    Id          = 'ARG.ENT.001'
    Title       = 'Enabled members inactive for more than {InactiveDays} days'
    Area        = 'EntraID'
    Category    = 'Identity lifecycle'
    Severity    = 'Medium'
    Description = 'Enabled member accounts whose last successful sign-in (interactive or non-interactive) is older than **{InactiveDays}** days, including accounts that never signed in and were created more than {InactiveDays} days ago. Uses `signInActivity.lastSuccessfulSignInDateTime`, falling back to the last sign-in attempt for activity before December 2023.'
    Rationale   = 'Accounts nobody uses keep their group memberships, app access and licences. Reviewing them regularly is the basis of identity lifecycle governance.'
    Remediation = @{
        Steps      = "1. Confirm with the manager or HR that the account is no longer needed.`n2. Block sign-in for the account.`n3. After your retention period, remove licences and group memberships, then delete the account."
        PowerShell = "# Sample only - review before running. Blocks sign-in for one account.`nConnect-MgGraph -Scopes 'User.ReadWrite.All'`nUpdate-MgUser -UserId '<ObjectId>' -AccountEnabled:`$false"
        PortalUrl  = 'https://entra.microsoft.com/'
    }
    References  = @(
        @{ Title = 'Manage inactive user accounts in Microsoft Entra ID'; Url = 'https://learn.microsoft.com/en-us/entra/identity/monitoring-health/howto-manage-inactive-user-accounts' }
    )
    Requires    = @{
        Services    = @('Graph')
        GraphScopes = @('User.Read.All', 'AuditLog.Read.All')
        Licenses    = @('AAD_PREMIUM')
        DataSets    = @('Users')
    }
    Parameters  = @{ InactiveDays = 90 }
    Tags        = @('Lifecycle', 'Users')
    Test        = {
        param($Context)
        $days = [int]$Context.Parameters.InactiveDays
        $threshold = $Context.Now.AddDays(-$days)
        $users = @($Context.Data['Users'])
        if (-not (Test-ArgusSignInActivity -User $users)) {
            return New-ArgusResult -Status Skipped -SkipReason 'Sign-in activity is not available for this tenant or account (Entra ID P1 and AuditLog.Read.All are needed).'
        }

        $evaluated = @($users | Where-Object { (Get-ArgusProperty $_ 'userType') -eq 'Member' -and (Get-ArgusProperty $_ 'accountEnabled') -eq $true })
        $findings = foreach ($user in $evaluated) {
            $created = ConvertTo-ArgusUtcDate (Get-ArgusProperty $user 'createdDateTime')
            if ($created -and $created -gt $threshold) { continue }
            $last = Get-ArgusUserLastSignIn -User $user
            if ($last -and $last -ge $threshold) { continue }
            [pscustomobject]@{
                DisplayName       = Get-ArgusProperty $user 'displayName' ''
                UserPrincipalName = Get-ArgusProperty $user 'userPrincipalName' ''
                LastSignIn        = Format-ArgusDate $last 'Never'
                DaysInactive      = if ($last) { [int]($Context.Now - $last).TotalDays } elseif ($created) { [int]($Context.Now - $created).TotalDays } else { $null }
                Created           = Format-ArgusDate $created
                Licensed          = @(Get-ArgusProperty $user 'assignedLicenses' @()).Count -gt 0
                SyncedFromOnPrem  = [bool](Get-ArgusProperty $user 'onPremisesSyncEnabled' $false)
                ObjectId          = Get-ArgusProperty $user 'id' ''
            }
        }
        $findings = @($findings | Sort-Object DaysInactive -Descending)
        $status = if ($findings.Count -gt 0) { 'Failed' } else { 'Passed' }
        New-ArgusResult -Status $status -Findings $findings -EvaluatedCount $evaluated.Count `
            -Summary '{AffectedCount} of {EvaluatedCount} enabled members have not signed in for {InactiveDays}+ days.'
    }
}
