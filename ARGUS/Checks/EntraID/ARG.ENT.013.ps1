Register-ArgusCheck @{
    Id          = 'ARG.ENT.013'
    Title       = 'Security groups without owners'
    Area        = 'EntraID'
    Category    = 'Group governance'
    Severity    = 'Low'
    Description = 'Cloud security groups with assigned membership and no owner. Dynamic groups, role-assignable groups, mail-enabled security groups (managed in Exchange) and groups synchronised from on-premises Active Directory are not evaluated.'
    Rationale   = 'Without an owner, nobody is accountable for who is in the group and what the group grants access to.'
    Remediation = @{
        Steps      = "1. Identify the business owner of each group (what it grants access to tells you who).`n2. Add at least one owner (two is better).`n3. Delete groups that are no longer used."
        PowerShell = "# Sample only - review before running. Adds an owner to one group.`nConnect-MgGraph -Scopes 'Group.ReadWrite.All'`nNew-MgGroupOwnerByRef -GroupId '<GroupId>' -BodyParameter @{ '@odata.id' = 'https://graph.microsoft.com/v1.0/users/<OwnerObjectId>' }"
        PortalUrl  = 'https://entra.microsoft.com/'
    }
    References  = @(
        @{ Title = 'How to manage groups (owners)'; Url = 'https://learn.microsoft.com/en-us/entra/fundamentals/how-to-manage-groups' }
    )
    Requires    = @{
        Services    = @('Graph')
        GraphScopes = @('Group.Read.All')
        DataSets    = @('Groups')
    }
    Tags        = @('Groups', 'Ownership')
    Test        = {
        param($Context)
        $evaluated = @($Context.Data['Groups'] | Where-Object {
                (Get-ArgusProperty $_ 'securityEnabled') -eq $true -and -not (Get-ArgusProperty $_ 'IsUnified' $false) -and
                -not (Get-ArgusProperty $_ 'IsDynamic' $false) -and -not (Get-ArgusProperty $_ 'isAssignableToRole' $false) -and
                -not (Get-ArgusProperty $_ 'mailEnabled' $false) -and -not (Get-ArgusProperty $_ 'onPremisesSyncEnabled' $false)
            })
        $findings = @($evaluated | Where-Object { [int](Get-ArgusProperty $_ 'OwnerCount' 0) -eq 0 } | ForEach-Object {
                [pscustomobject]@{
                    DisplayName = Get-ArgusProperty $_ 'displayName' ''
                    Description = Get-ArgusProperty $_ 'description' ''
                    Created     = Format-ArgusDate (Get-ArgusProperty $_ 'createdDateTime')
                    GroupId     = Get-ArgusProperty $_ 'id' ''
                }
            } | Sort-Object DisplayName)
        $status = if ($findings.Count -gt 0) { 'Failed' } else { 'Passed' }
        New-ArgusResult -Status $status -Findings $findings -EvaluatedCount $evaluated.Count `
            -Summary '{AffectedCount} of {EvaluatedCount} cloud security groups have no owner.'
    }
}
