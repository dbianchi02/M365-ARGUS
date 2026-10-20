Register-ArgusCheck @{
    Id          = 'ARG.GRP.004'
    Title       = 'Microsoft 365 groups and Teams without owners'
    Area        = 'GroupsTeams'
    Category    = 'Ownership'
    Severity    = 'High'
    Description = 'Microsoft 365 (Unified) groups, including the ones connected to Teams, with no owner.'
    Rationale   = 'Nobody manages membership, guests or content of an ownerless group, nobody receives its expiration notices, and nobody can approve access requests. Microsoft recommends at least two owners per group.'
    Remediation = @{
        Steps      = "1. Identify a responsible person for each group (for example among the most active members).`n2. Add at least two owners.`n3. Archive or delete groups that are no longer needed.`n4. Consider the Microsoft 365 ownerless group policy, which asks active members to become owners."
        PowerShell = "# Sample only - review before running. Adds an owner to one group.`nConnect-MgGraph -Scopes 'Group.ReadWrite.All'`nNew-MgGroupOwnerByRef -GroupId '<GroupId>' -BodyParameter @{ '@odata.id' = 'https://graph.microsoft.com/v1.0/users/<UserId>' }"
        PortalUrl  = 'https://admin.microsoft.com/Adminportal/Home#/groups'
    }
    References  = @(
        @{ Title = 'Manage ownerless Microsoft 365 groups and teams'; Url = 'https://learn.microsoft.com/en-us/microsoft-365/admin/create-groups/ownerless-groups-teams' }
        @{ Title = 'Add or remove members from Microsoft 365 groups using the admin center'; Url = 'https://learn.microsoft.com/en-us/microsoft-365/admin/create-groups/add-or-remove-members-from-groups' }
    )
    Requires    = @{
        Services    = @('Graph')
        GraphScopes = @('Group.Read.All')
        DataSets    = @('Groups')
    }
    Tags        = @('Groups', 'Teams', 'Ownership')
    Test        = {
        param($Context)
        $unified = @($Context.Data['Groups'] | Where-Object { $_.IsUnified })
        $findings = @($unified | Where-Object { $_.OwnerCount -eq 0 } | ForEach-Object {
                [pscustomobject]@{
                    DisplayName = Get-ArgusProperty $_ 'displayName' ''
                    Mail        = Get-ArgusProperty $_ 'mail' ''
                    Team        = if ($_.IsTeam) { 'Yes' } else { 'No' }
                    Visibility  = Get-ArgusProperty $_ 'visibility' ''
                    Created     = Format-ArgusDate (Get-ArgusProperty $_ 'createdDateTime')
                    GroupId     = Get-ArgusProperty $_ 'id' ''
                }
            } | Sort-Object DisplayName)
        if ($findings.Count -eq 0) {
            return New-ArgusResult -Status Passed -EvaluatedCount $unified.Count -Summary 'All {EvaluatedCount} Microsoft 365 groups have at least one owner.'
        }
        $teams = @($findings | Where-Object Team -EQ 'Yes').Count
        New-ArgusResult -Status Failed -Findings $findings -EvaluatedCount $unified.Count `
            -Summary "{AffectedCount} of {EvaluatedCount} Microsoft 365 groups have no owner ($teams are Teams)."
    }
}
