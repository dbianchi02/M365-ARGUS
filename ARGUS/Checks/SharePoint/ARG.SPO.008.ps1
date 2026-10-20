Register-ArgusCheck @{
    Id          = 'ARG.SPO.008'
    Title       = 'Orphaned SharePoint sites'
    Area        = 'SharePoint'
    Category    = 'Ownership'
    Severity    = 'High'
    Description = 'Group-connected sites whose Microsoft 365 group has no owner (site URL read with JSON batching, `GET /groups/<id>/sites/root`). When SharePoint is connected through PnP.PowerShell, sites without a Microsoft 365 group (classic team sites, communication sites) are also evaluated: a site is orphaned when its primary site collection administrator (`Owner` in `Get-PnPTenantSite`) is empty, disabled or no longer exists. Without PnP those sites are not evaluated and the summary says so.'
    Rationale   = 'Nobody manages permissions, sharing or content of a site without a responsible owner, and access requests go unanswered. Orphaned sites are also the hardest to clean up later.'
    Remediation = @{
        Steps      = "1. For group-connected sites, add owners to the Microsoft 365 group (see ARG.GRP.004).`n2. For other sites, set a new primary site collection administrator in the SharePoint admin center (Active sites > Permissions).`n3. Delete or archive sites that are no longer needed."
        PowerShell = "# Sample only - review before running. Sets the primary administrator of a site without a group.`nConnect-PnPOnline -Url 'https://<tenant>-admin.sharepoint.com' -Interactive -ClientId '<ClientId>'`nSet-PnPTenantSite -Identity '<SiteUrl>' -Owners @('<UserPrincipalName>')"
        PortalUrl  = 'https://admin.microsoft.com/sharepoint?page=siteManagement&modern=true'
    }
    References  = @(
        @{ Title = 'Manage site admins in the SharePoint admin center'; Url = 'https://learn.microsoft.com/en-us/sharepoint/manage-site-collection-administrators' }
        @{ Title = 'Manage ownerless Microsoft 365 groups and teams'; Url = 'https://learn.microsoft.com/en-us/microsoft-365/admin/create-groups/ownerless-groups-teams' }
    )
    Requires    = @{
        Services         = @('Graph')
        GraphScopes      = @('Group.Read.All', 'Sites.Read.All')
        DataSets         = @('Groups')
        OptionalDataSets = @('SharePointSites', 'Users')
    }
    Tags        = @('SharePoint', 'Ownership')
    Test        = {
        param($Context)
        $unified = @($Context.Data['Groups'] | Where-Object { $_.IsUnified })
        $ownerless = @($unified | Where-Object { $_.OwnerCount -eq 0 })
        $findings = [System.Collections.Generic.List[object]]::new()

        if ($ownerless.Count -gt 0) {
            $requests = @($ownerless | ForEach-Object { $id = [string](Get-ArgusProperty $_ 'id' ''); @{ Id = $id; Url = "/groups/$id/sites/root?`$select=webUrl,displayName" } })
            $sites = @{}
            foreach ($response in @(Invoke-ArgusGraphBatch -Request $requests)) {
                if ($response.Status -eq 200) { $sites[$response.Id] = [string](Get-ArgusProperty $response.Body 'webUrl' '') }
            }
            foreach ($group in $ownerless) {
                $id = [string](Get-ArgusProperty $group 'id' '')
                if (-not $sites[$id]) { continue }   # group without a provisioned site
                $findings.Add([pscustomobject]@{
                        SiteUrl = $sites[$id]
                        Title   = Get-ArgusProperty $group 'displayName' ''
                        Type    = if ($group.IsTeam) { 'Team site (Teams)' } else { 'Group-connected team site' }
                        Reason  = 'Microsoft 365 group has no owner'
                        Owner   = ''
                        GroupId = $id
                    })
            }
        }

        $evaluated = $unified.Count
        $note = ' Sites without a Microsoft 365 group were not evaluated (connect SharePoint with PnP.PowerShell to include them).'
        if ($Context.Data.ContainsKey('SharePointSites')) {
            $note = ''
            $users = @{}
            foreach ($user in @($Context.Data['Users'])) {
                $upn = [string](Get-ArgusProperty $user 'userPrincipalName' '')
                if ($upn) { $users[$upn.ToLowerInvariant()] = $user }
            }
            $haveUsers = $Context.Data.ContainsKey('Users')
            $skipTemplates = 'SPSPERS*', 'SPSMSITEHOST*', 'RedirectSite*', 'APPCATALOG*', 'SRCHCEN*', 'POINTPUBLISHINGHUB*', 'POINTPUBLISHINGTOPIC*', 'TEAMCHANNEL*', 'GROUP*'
            foreach ($site in @($Context.Data['SharePointSites'])) {
                $template = [string](Get-ArgusProperty $site 'Template' '')
                $groupId = [string](Get-ArgusProperty $site 'GroupId' '')
                if (($groupId -and $groupId -ne [guid]::Empty.ToString()) -or @($skipTemplates | Where-Object { $template -like $_ }).Count) { continue }
                $evaluated++
                $owner = [string](Get-ArgusProperty $site 'Owner' '')
                $reason = if (-not $owner) { 'No primary site collection administrator' }
                elseif ($owner -notlike '*@*' -or -not $haveUsers) { $null }
                elseif (-not $users.ContainsKey($owner.ToLowerInvariant())) { 'Primary administrator no longer exists' }
                elseif ((Get-ArgusProperty $users[$owner.ToLowerInvariant()] 'accountEnabled') -ne $true) { 'Primary administrator is disabled' }
                else { $null }
                if (-not $reason) { continue }
                $findings.Add([pscustomobject]@{
                        SiteUrl = Get-ArgusProperty $site 'Url' ''
                        Title   = Get-ArgusProperty $site 'Title' ''
                        Type    = "Site without group ($template)"
                        Reason  = $reason
                        Owner   = $owner
                        GroupId = ''
                    })
            }
        }

        $sorted = @($findings | Sort-Object Type, SiteUrl)
        if ($sorted.Count -eq 0) {
            return New-ArgusResult -Status Passed -EvaluatedCount $evaluated -Summary ('No orphaned site found ({EvaluatedCount} sites and groups evaluated).' + $note)
        }
        New-ArgusResult -Status Failed -Findings $sorted -EvaluatedCount $evaluated `
            -Summary ('{AffectedCount} of {EvaluatedCount} sites have no responsible owner.' + $note)
    }
}
