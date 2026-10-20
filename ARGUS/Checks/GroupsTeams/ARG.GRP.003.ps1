Register-ArgusCheck @{
    Id          = 'ARG.GRP.003'
    Title       = 'Group expiration policy configured'
    Area        = 'GroupsTeams'
    Category    = 'Lifecycle'
    Severity    = 'Medium'
    Description = 'Reads `groupLifecyclePolicies`. Fails when no expiration policy exists or when it applies to no group (`managedGroupTypes` = None); a policy that applies only to selected groups is Investigate. Groups with recent activity are renewed automatically, so active owners are not disturbed.'
    Rationale   = 'Without an expiration policy, Microsoft 365 groups and Teams that are no longer used stay forever with their content, guests and permissions. Expiration asks owners to confirm that the group is still needed.'
    Remediation = @{
        Steps      = "1. In the Microsoft Entra admin center open Groups > Expiration.`n2. Set a lifetime (for example 365 days), an e-mail address for ownerless groups, and apply it to All groups.`n3. Make sure groups have owners first (ARG.GRP.004), otherwise expiry notices only go to the fallback address."
        PortalUrl  = 'https://entra.microsoft.com/#view/Microsoft_AAD_IAM/GroupsManagementMenuBlade/~/Lifecycle'
    }
    References  = @(
        @{ Title = 'Microsoft 365 group expiration policy'; Url = 'https://learn.microsoft.com/en-us/microsoft-365/solutions/microsoft-365-groups-expiration-policy' }
        @{ Title = 'Configure the expiration policy for Microsoft 365 groups'; Url = 'https://learn.microsoft.com/en-us/entra/identity/users/groups-lifecycle' }
    )
    Requires    = @{
        Services    = @('Graph')
        GraphScopes = @('Directory.Read.All')
        DataSets    = @('GroupLifecyclePolicies')
    }
    Tags        = @('Groups', 'Lifecycle')
    Test        = {
        param($Context)
        $policy = @($Context.Data['GroupLifecyclePolicies'] | Where-Object { $_ }) | Select-Object -First 1
        if (-not $policy) {
            return New-ArgusResult -Status Failed -Summary 'No Microsoft 365 group expiration policy is configured.'
        }
        $scope = [string](Get-ArgusProperty $policy 'managedGroupTypes' '')
        $days = Get-ArgusProperty $policy 'groupLifetimeInDays' $null
        $settings = @([pscustomobject]@{
                AppliesTo                   = $scope
                LifetimeDays                = $days
                AlternateNotificationEmails = Get-ArgusProperty $policy 'alternateNotificationEmails' ''
            })
        switch ($scope) {
            'All' { New-ArgusResult -Status Passed -Findings $settings -AffectedCount 0 -Summary "An expiration policy applies to all Microsoft 365 groups (lifetime $days days)." }
            'Selected' { New-ArgusResult -Status Investigate -Findings $settings -Summary "The expiration policy (lifetime $days days) applies only to selected groups: confirm that the other groups are excluded on purpose." }
            default { New-ArgusResult -Status Failed -Findings $settings -Summary 'An expiration policy exists but applies to no group (managedGroupTypes = None).' }
        }
    }
}
