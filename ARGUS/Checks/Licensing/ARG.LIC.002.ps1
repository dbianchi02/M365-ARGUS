Register-ArgusCheck @{
    Id          = 'ARG.LIC.002'
    Title       = 'Enabled licensed users inactive for more than {InactiveDays} days'
    Area        = 'Licensing'
    Category    = 'Licence hygiene'
    Severity    = 'High'
    Description = 'Enabled member accounts with at least one licence that have not signed in for **{InactiveDays}** days (same inactivity logic as ARG.ENT.001: last successful sign-in, accounts that never signed in count from their creation date). The findings list the licences assigned to each account.'
    Rationale   = 'Licences assigned to people who no longer use them are recurring cost with no business value, and the accounts keep access nobody reviews.'
    Remediation = @{
        Steps      = "1. Confirm the users are no longer active.`n2. Block sign-in, then remove or reassign the licences (or remove the users from the licensing group).`n3. Reduce the subscription quantity at renewal if the seats are not needed."
        PowerShell = "# Sample only - review before running. Removes all licences from one user.`nConnect-MgGraph -Scopes 'User.ReadWrite.All'`n`$skus = (Get-MgUserLicenseDetail -UserId '<ObjectId>').SkuId`nSet-MgUserLicense -UserId '<ObjectId>' -AddLicenses @() -RemoveLicenses `$skus"
        PortalUrl  = 'https://admin.microsoft.com/'
    }
    References  = @(
        @{ Title = 'Manage inactive user accounts in Microsoft Entra ID'; Url = 'https://learn.microsoft.com/en-us/entra/identity/monitoring-health/howto-manage-inactive-user-accounts' }
        @{ Title = 'Assign or unassign licenses for users in the Microsoft 365 admin center'; Url = 'https://learn.microsoft.com/en-us/microsoft-365/admin/manage/assign-licenses-to-users' }
    )
    Requires    = @{
        Services    = @('Graph')
        GraphScopes = @('User.Read.All', 'AuditLog.Read.All')
        Licenses    = @('AAD_PREMIUM')
        DataSets    = @('Users', 'SubscribedSkus')
    }
    Parameters  = @{ InactiveDays = 90 }
    Tags        = @('Lifecycle', 'Licensing', 'Cost')
    Test        = {
        param($Context)
        $days = [int]$Context.Parameters.InactiveDays
        $threshold = $Context.Now.AddDays(-$days)
        $users = @($Context.Data['Users'])
        $skus = @($Context.Data['SubscribedSkus'])
        if (-not (Test-ArgusSignInActivity -User $users)) {
            return New-ArgusResult -Status Skipped -SkipReason 'Sign-in activity is not available for this tenant or account (Entra ID P1 and AuditLog.Read.All are needed).'
        }

        $evaluated = @($users | Where-Object {
                (Get-ArgusProperty $_ 'userType') -eq 'Member' -and (Get-ArgusProperty $_ 'accountEnabled') -eq $true -and
                @(Get-ArgusProperty $_ 'assignedLicenses' @()).Count -gt 0
            })
        $findings = foreach ($user in $evaluated) {
            $created = ConvertTo-ArgusUtcDate (Get-ArgusProperty $user 'createdDateTime')
            if ($created -and $created -gt $threshold) { continue }
            $last = Get-ArgusUserLastSignIn -User $user
            if ($last -and $last -ge $threshold) { continue }
            $skuIds = @(Get-ArgusProperty $user 'assignedLicenses' @() | ForEach-Object { Get-ArgusProperty $_ 'skuId' })
            [pscustomobject]@{
                DisplayName       = Get-ArgusProperty $user 'displayName' ''
                UserPrincipalName = Get-ArgusProperty $user 'userPrincipalName' ''
                Licences          = @(Get-ArgusSkuName -SkuId $skuIds -SubscribedSku $skus)
                LastSignIn        = Format-ArgusDate $last 'Never'
                DaysInactive      = if ($last) { [int]($Context.Now - $last).TotalDays } elseif ($created) { [int]($Context.Now - $created).TotalDays } else { $null }
                Created           = Format-ArgusDate $created
                ObjectId          = Get-ArgusProperty $user 'id' ''
            }
        }
        $findings = @($findings | Sort-Object DaysInactive -Descending)
        $status = if ($findings.Count -gt 0) { 'Failed' } else { 'Passed' }
        New-ArgusResult -Status $status -Findings $findings -EvaluatedCount $evaluated.Count `
            -Summary '{AffectedCount} of {EvaluatedCount} enabled licensed users have not signed in for {InactiveDays}+ days.'
    }
}
