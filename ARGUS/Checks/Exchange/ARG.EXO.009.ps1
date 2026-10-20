Register-ArgusCheck @{
    Id          = 'ARG.EXO.009'
    Title       = 'Distribution groups without owner'
    Area        = 'Exchange'
    Category    = 'Ownership'
    Severity    = 'Low'
    Description = 'Distribution groups and mail-enabled security groups (Exchange Online, `Get-DistributionGroup`) with an empty `ManagedBy` list, so only Exchange administrators can manage them.'
    Rationale   = 'Without an owner, membership and delivery restrictions of a distribution list are not maintained, nobody can approve join requests, and the list keeps sending mail to people who left or changed role.'
    Remediation = @{
        Steps      = "1. Identify a responsible person for each group (for example the team or department lead).`n2. Set the owners in the Exchange admin center (Recipients > Groups > Settings), at least two per group.`n3. Remove groups that are no longer used."
        PowerShell = "# Sample only - review before running. Sets the owners of one distribution group.`nConnect-ExchangeOnline`nSet-DistributionGroup -Identity '<PrimarySmtpAddress>' -ManagedBy '<owner1@contoso.com>','<owner2@contoso.com>'"
        PortalUrl  = 'https://admin.exchange.microsoft.com/#/groups'
    }
    References  = @(
        @{ Title = 'Create and manage distribution list groups in Exchange Online'; Url = 'https://learn.microsoft.com/en-us/exchange/recipients-in-exchange-online/manage-distribution-groups/manage-distribution-groups' }
        @{ Title = 'Get-DistributionGroup'; Url = 'https://learn.microsoft.com/en-us/powershell/module/exchangepowershell/get-distributiongroup' }
    )
    Requires    = @{
        Services = @('Graph', 'Exchange')
        DataSets = @('DistributionGroups')
    }
    Tags        = @('Exchange', 'Groups', 'Ownership')
    Test        = {
        param($Context)
        $groups = @($Context.Data['DistributionGroups'] | Where-Object { $_ })
        $findings = @($groups | Where-Object { @(Get-ArgusProperty $_ 'ManagedBy' @() | Where-Object { $_ }).Count -eq 0 } | ForEach-Object {
                [pscustomobject]@{
                    DisplayName        = Get-ArgusProperty $_ 'DisplayName' ''
                    PrimarySmtpAddress = Get-ArgusProperty $_ 'PrimarySmtpAddress' ''
                    Type               = Get-ArgusProperty $_ 'RecipientTypeDetails' ''
                    GroupId            = Get-ArgusProperty $_ 'ExternalDirectoryObjectId' ''
                }
            } | Sort-Object DisplayName)
        $status = if ($findings.Count -gt 0) { 'Failed' } else { 'Passed' }
        New-ArgusResult -Status $status -Findings $findings -EvaluatedCount $groups.Count `
            -Summary '{AffectedCount} of {EvaluatedCount} distribution and mail-enabled security groups have no owner.'
    }
}
