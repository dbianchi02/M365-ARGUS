Register-ArgusCheck @{
    Id          = 'ARG.GRP.006'
    Title       = 'Teams with guests and no owner'
    Area        = 'GroupsTeams'
    Category    = 'Ownership'
    Severity    = 'High'
    Description = 'Teams (Microsoft 365 groups with a team) that have no owner and at least one guest member. Members of the ownerless Teams are read with JSON batching (`GET /groups/<id>/members/microsoft.graph.user`, first 999 members).'
    Rationale   = 'Guests in a team without owners keep access to its chats, files and site, and nobody reviews or removes them. These Teams are the first to fix among ownerless groups (ARG.GRP.004).'
    Remediation = @{
        Steps      = "1. Assign at least two owners to each team.`n2. Ask the new owners to review the guest members and remove the ones who no longer need access.`n3. Consider access reviews for guests in Teams (Microsoft Entra ID Governance)."
        PortalUrl  = 'https://admin.teams.microsoft.com/teams/manage'
    }
    References  = @(
        @{ Title = 'Guest access in Microsoft Teams'; Url = 'https://learn.microsoft.com/en-us/microsoftteams/guest-access' }
        @{ Title = 'Manage guest access with access reviews'; Url = 'https://learn.microsoft.com/en-us/entra/id-governance/manage-guest-access-with-access-reviews' }
    )
    Requires    = @{
        Services    = @('Graph')
        GraphScopes = @('Group.Read.All', 'GroupMember.Read.All')
        DataSets    = @('Groups')
    }
    Tags        = @('Teams', 'Guests', 'Ownership')
    Test        = {
        param($Context)
        $teams = @($Context.Data['Groups'] | Where-Object { $_.IsTeam })
        $ownerless = @($teams | Where-Object { $_.OwnerCount -eq 0 })
        if ($ownerless.Count -eq 0) {
            return New-ArgusResult -Status Passed -EvaluatedCount $teams.Count -Summary 'All {EvaluatedCount} Teams have at least one owner.'
        }

        $requests = @($ownerless | ForEach-Object {
                $id = [string](Get-ArgusProperty $_ 'id' '')
                @{ Id = $id; Url = "/groups/$id/members/microsoft.graph.user?`$select=id,userType,userPrincipalName&`$top=999" }
            })
        $members = @{}
        $unread = 0
        foreach ($response in @(Invoke-ArgusGraphBatch -Request $requests)) {
            if ($response.Status -eq 200) { $members[$response.Id] = @(Get-ArgusProperty $response.Body 'value' @()) } else { $unread++ }
        }

        $findings = @($ownerless | ForEach-Object {
                $id = [string](Get-ArgusProperty $_ 'id' '')
                if (-not $members.ContainsKey($id)) { return }
                $guests = @($members[$id] | Where-Object { (Get-ArgusProperty $_ 'userType' '') -eq 'Guest' })
                if ($guests.Count -eq 0) { return }
                [pscustomobject]@{
                    DisplayName = Get-ArgusProperty $_ 'displayName' ''
                    Guests      = $guests.Count
                    Members     = $members[$id].Count
                    GuestUsers  = @($guests | ForEach-Object { Get-ArgusProperty $_ 'userPrincipalName' '' })
                    Visibility  = Get-ArgusProperty $_ 'visibility' ''
                    GroupId     = $id
                }
            } | Sort-Object Guests -Descending)

        $note = if ($unread) { " Members of $unread ownerless Teams could not be read." } else { '' }
        if ($findings.Count -eq 0) {
            return New-ArgusResult -Status Passed -EvaluatedCount $teams.Count -Summary ("None of the $($ownerless.Count) ownerless Teams has guest members." + $note)
        }
        New-ArgusResult -Status Failed -Findings $findings -EvaluatedCount $teams.Count `
            -Summary ("{AffectedCount} of {EvaluatedCount} Teams have guest members and no owner." + $note)
    }
}
