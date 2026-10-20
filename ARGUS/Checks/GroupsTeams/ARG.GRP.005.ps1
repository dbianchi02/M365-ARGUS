Register-ArgusCheck @{
    Id          = 'ARG.GRP.005'
    Title       = 'Microsoft 365 groups and Teams with a single owner'
    Area        = 'GroupsTeams'
    Category    = 'Ownership'
    Severity    = 'Low'
    Description = 'Microsoft 365 (Unified) groups, including Teams, with exactly one owner. The Owner column shows who it is and OwnerEnabled whether that account is still enabled; groups whose only owner is disabled are listed first.'
    Rationale   = 'A single owner is a single point of failure: when that person leaves or changes role the group becomes ownerless. Microsoft recommends at least two owners.'
    Remediation = @{
        Steps      = "1. Ask each owner to add a second owner (a colleague or a team lead).`n2. Start with the groups whose only owner is disabled.`n3. Make two owners a requirement of your group request process."
        PortalUrl  = 'https://admin.microsoft.com/Adminportal/Home#/groups'
    }
    References  = @(
        @{ Title = 'Add or remove members from Microsoft 365 groups using the admin center'; Url = 'https://learn.microsoft.com/en-us/microsoft-365/admin/create-groups/add-or-remove-members-from-groups' }
        @{ Title = 'Manage ownerless Microsoft 365 groups and teams'; Url = 'https://learn.microsoft.com/en-us/microsoft-365/admin/create-groups/ownerless-groups-teams' }
    )
    Requires    = @{
        Services         = @('Graph')
        GraphScopes      = @('Group.Read.All')
        DataSets         = @('Groups')
        OptionalDataSets = @('Users')
    }
    Tags        = @('Groups', 'Teams', 'Ownership')
    Test        = {
        param($Context)
        $enabled = @{}
        if ($Context.Data.ContainsKey('Users')) {
            foreach ($user in @($Context.Data['Users'])) { $enabled[[string](Get-ArgusProperty $user 'id' '')] = (Get-ArgusProperty $user 'accountEnabled') -eq $true }
        }
        $unified = @($Context.Data['Groups'] | Where-Object { $_.IsUnified })
        $findings = @($unified | Where-Object { $_.OwnerCount -eq 1 } | ForEach-Object {
                $owner = @(Get-ArgusProperty $_ 'owners' @())[0]
                $ownerId = [string](Get-ArgusProperty $owner 'id' '')
                $ownerName = [string](Get-ArgusProperty $owner 'userPrincipalName' '')
                if (-not $ownerName) { $ownerName = [string](Get-ArgusProperty $owner 'displayName' $ownerId) }
                $ownerEnabled = if (-not $enabled.ContainsKey($ownerId)) { 'Unknown' } elseif ($enabled[$ownerId]) { 'Yes' } else { 'No' }
                [pscustomobject]@{
                    DisplayName  = Get-ArgusProperty $_ 'displayName' ''
                    Team         = if ($_.IsTeam) { 'Yes' } else { 'No' }
                    Owner        = $ownerName
                    OwnerEnabled = $ownerEnabled
                    Created      = Format-ArgusDate (Get-ArgusProperty $_ 'createdDateTime')
                    GroupId      = Get-ArgusProperty $_ 'id' ''
                }
            } | Sort-Object @{ Expression = { $_.OwnerEnabled -eq 'No' }; Descending = $true }, DisplayName)
        if ($findings.Count -eq 0) {
            return New-ArgusResult -Status Passed -EvaluatedCount $unified.Count -Summary 'No Microsoft 365 group has a single owner ({EvaluatedCount} evaluated).'
        }
        $disabled = @($findings | Where-Object OwnerEnabled -EQ 'No').Count
        New-ArgusResult -Status Failed -Findings $findings -EvaluatedCount $unified.Count `
            -Summary "{AffectedCount} of {EvaluatedCount} Microsoft 365 groups have exactly one owner ($disabled with a disabled owner)."
    }
}
