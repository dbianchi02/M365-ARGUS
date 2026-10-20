Register-ArgusCheck @{
    Id              = 'ARG.ENT.008'
    Title           = 'Global Administrator count outside {MinCount} to {MaxCount}'
    Area            = 'EntraID'
    Category        = 'Privileged access'
    Severity        = 'High'
    Description     = 'Counts the distinct holders of the Global Administrator role: active assignments and, with Entra ID P2, eligible (PIM) assignments. Members of role-assignable groups that hold the role are counted individually. Fails when the count is below **{MinCount}** or above **{MaxCount}**. Global exclusions are not applied: emergency-access accounts must be counted.'
    Rationale   = 'Too few Global Administrators risks losing control of the tenant; too many makes the most powerful role hard to govern. Keep two emergency-access accounts plus a small number of named administrators, and delegate the rest to least-privileged roles.'
    Remediation = @{
        Steps      = "1. Keep two cloud-only emergency-access accounts with permanent Global Administrator assignments.`n2. Move day-to-day administration to least-privileged roles (User, Exchange, SharePoint, Teams Administrator...).`n3. With Entra ID P2, make the remaining Global Administrator assignments eligible in PIM instead of permanent."
        PowerShell = "# Sample only - review before running. Lists current Global Administrator assignments.`nConnect-MgGraph -Scopes 'RoleManagement.Read.Directory'`nGet-MgRoleManagementDirectoryRoleAssignment -Filter `"roleDefinitionId eq '62e90394-69f5-4237-9190-012177145e10'`" -ExpandProperty principal"
        PortalUrl  = 'https://entra.microsoft.com/'
    }
    References      = @(
        @{ Title = 'Best practices for Microsoft Entra roles'; Url = 'https://learn.microsoft.com/en-us/entra/identity/role-based-access-control/best-practices' }
        @{ Title = 'Manage emergency access admin accounts'; Url = 'https://learn.microsoft.com/en-us/entra/identity/role-based-access-control/security-emergency-access' }
    )
    Requires        = @{
        Services    = @('Graph')
        GraphScopes = @('RoleManagement.Read.Directory', 'GroupMember.Read.All')
        DataSets    = @('DirectoryRoles')
    }
    Parameters      = @{ MinCount = 2; MaxCount = 4 }
    Tags            = @('Roles', 'Privileged access')
    ApplyExclusions = $false
    Test            = {
        param($Context)
        $globalAdmin = '62e90394-69f5-4237-9190-012177145e10'
        $roles = $Context.Data['DirectoryRoles']
        $members = @(Get-ArgusRoleMember -DirectoryRoles $roles -RoleTemplateId $globalAdmin)

        # One row per holder; a holder with both an active and an eligible assignment is counted once.
        $holders = @($members | Group-Object PrincipalId | ForEach-Object {
                $first = $_.Group[0]
                [pscustomobject]@{
                    DisplayName       = $first.DisplayName
                    UserPrincipalName = $first.UserPrincipalName
                    PrincipalType     = $first.PrincipalType
                    Assignment        = (@($_.Group.Assignment | Sort-Object -Unique) -join ', ')
                    Via               = (@($_.Group.Via | Sort-Object -Unique) -join ', ')
                    ObjectId          = $first.PrincipalId
                }
            } | Sort-Object DisplayName)

        $min = [int]$Context.Parameters.MinCount
        $max = [int]$Context.Parameters.MaxCount
        $count = $holders.Count
        $scope = if (Get-ArgusProperty $roles 'EligibleAvailable' $false) { 'active and eligible assignments' } else { 'active assignments; eligible PIM assignments not evaluated (Entra ID P2 not detected)' }
        $status = if ($count -lt $min -or $count -gt $max) { 'Failed' } else { 'Passed' }
        New-ArgusResult -Status $status -Findings $holders -AffectedCount $count -EvaluatedCount $count `
            -Summary ("$count Global Administrator" + $(if ($count -eq 1) { '' } else { 's' }) + " ($scope); the recommended range is {MinCount} to {MaxCount}.")
    }
}
