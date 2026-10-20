Register-ArgusCheck @{
    Id          = 'ARG.EXO.010'
    Title       = 'Empty distribution groups'
    Area        = 'Exchange'
    Category    = 'Lifecycle'
    Severity    = 'Low'
    Description = 'Distribution groups and mail-enabled security groups (`Get-DistributionGroup`) without members, read through Microsoft Graph (`GET /groups/<id>/members?$top=1`, sent in `$batch`). Groups whose members could not be read are left out of the evaluation. Dynamic distribution groups are not included.'
    Rationale   = 'An empty distribution group still accepts mail, which then reaches nobody, and clutters the address book. Empty groups are usually left over from projects or reorganisations and can be removed.'
    Remediation = @{
        Steps      = "1. Check with the owner (ManagedBy) whether the group is still needed.`n2. Add the intended members, or delete the group.`n3. Before deleting, check that no mail flow rule, connector or application sends to the address."
        PortalUrl  = 'https://admin.exchange.microsoft.com/#/groups'
    }
    References  = @(
        @{ Title = 'Manage distribution groups in Exchange Online'; Url = 'https://learn.microsoft.com/en-us/exchange/recipients-in-exchange-online/manage-distribution-groups/manage-distribution-groups' }
        @{ Title = 'List group members'; Url = 'https://learn.microsoft.com/en-us/graph/api/group-list-members' }
    )
    Requires    = @{
        Services    = @('Graph', 'Exchange')
        GraphScopes = @('GroupMember.Read.All')
        DataSets    = @('DistributionGroups', 'DistributionGroupMembers')
    }
    Tags        = @('Exchange', 'Groups', 'Lifecycle')
    Test        = {
        param($Context)
        $members = $Context.Data['DistributionGroupMembers']
        $evaluated = @($Context.Data['DistributionGroups'] | Where-Object {
                $id = [string](Get-ArgusProperty $_ 'ExternalDirectoryObjectId' '')
                $id -and $members -and $members.Contains($id) -and $null -ne $members[$id]
            })
        $findings = @($evaluated | Where-Object { $members[[string]$_.ExternalDirectoryObjectId] -eq $false } | ForEach-Object {
                [pscustomobject]@{
                    DisplayName        = Get-ArgusProperty $_ 'DisplayName' ''
                    PrimarySmtpAddress = Get-ArgusProperty $_ 'PrimarySmtpAddress' ''
                    Type               = Get-ArgusProperty $_ 'RecipientTypeDetails' ''
                    ManagedBy          = (@(Get-ArgusProperty $_ 'ManagedBy' @()) -join ', ')
                    GroupId            = Get-ArgusProperty $_ 'ExternalDirectoryObjectId' ''
                }
            } | Sort-Object DisplayName)
        $status = if ($findings.Count -gt 0) { 'Failed' } else { 'Passed' }
        New-ArgusResult -Status $status -Findings $findings -EvaluatedCount $evaluated.Count `
            -Summary '{AffectedCount} of {EvaluatedCount} distribution and mail-enabled security groups have no members.'
    }
}
