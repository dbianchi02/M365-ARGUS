Register-ArgusCheck @{
    Id          = 'ARG.GRP.007'
    Title       = 'Public Microsoft 365 groups'
    Area        = 'GroupsTeams'
    Category    = 'Group governance'
    Severity    = 'Medium'
    Description = 'Microsoft 365 (Unified) groups with `visibility` = Public. Anyone in the organisation can join a public group, or its team, and read its conversations, files and site without approval. The Team column shows whether a team is connected.'
    Rationale   = 'Public groups are fine for organisation-wide communities, but projects, departments and customer work usually hold content that should be limited to members. Reviewing them keeps visibility a deliberate choice.'
    Remediation = @{
        Steps      = "1. Review each public group with its owners and confirm that the content is meant for the whole organisation.`n2. Switch the others to Private (members are kept; non-members lose access).`n3. Consider sensitivity labels for groups to set privacy by classification."
        PowerShell = "# Sample only - review before running. Makes one group private.`nConnect-MgGraph -Scopes 'Group.ReadWrite.All'`nUpdate-MgGroup -GroupId '<GroupId>' -Visibility 'Private'"
        PortalUrl  = 'https://admin.microsoft.com/Adminportal/Home#/groups'
    }
    References  = @(
        @{ Title = 'Overview of Microsoft 365 Groups for administrators'; Url = 'https://learn.microsoft.com/en-us/microsoft-365/admin/create-groups/office-365-groups' }
        @{ Title = 'Use sensitivity labels with Microsoft Teams, Microsoft 365 groups, and SharePoint sites'; Url = 'https://learn.microsoft.com/en-us/purview/sensitivity-labels-teams-groups-sites' }
    )
    Requires    = @{
        Services    = @('Graph')
        GraphScopes = @('Group.Read.All')
        DataSets    = @('Groups')
    }
    Tags        = @('Groups', 'Teams')
    Test        = {
        param($Context)
        $unified = @($Context.Data['Groups'] | Where-Object { $_.IsUnified })
        $findings = @($unified | Where-Object { (Get-ArgusProperty $_ 'visibility' '') -eq 'Public' } | ForEach-Object {
                [pscustomobject]@{
                    DisplayName = Get-ArgusProperty $_ 'displayName' ''
                    Mail        = Get-ArgusProperty $_ 'mail' ''
                    Team        = if ($_.IsTeam) { 'Yes' } else { 'No' }
                    Owners      = $_.OwnerCount
                    Created     = Format-ArgusDate (Get-ArgusProperty $_ 'createdDateTime')
                    GroupId     = Get-ArgusProperty $_ 'id' ''
                }
            } | Sort-Object DisplayName)
        if ($findings.Count -eq 0) {
            return New-ArgusResult -Status Passed -EvaluatedCount $unified.Count -Summary 'None of the {EvaluatedCount} Microsoft 365 groups is public.'
        }
        $teams = @($findings | Where-Object Team -EQ 'Yes').Count
        New-ArgusResult -Status Failed -Findings $findings -EvaluatedCount $unified.Count `
            -Summary "{AffectedCount} of {EvaluatedCount} Microsoft 365 groups are public ($teams are Teams)."
    }
}
