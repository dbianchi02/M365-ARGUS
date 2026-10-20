function Get-ArgusRoleMember {
    <#
    .SYNOPSIS
        Flattens directory role assignments into one row per role holder, expanding role-assignable groups.

    .DESCRIPTION
        Uses the DirectoryRoles data set (active assignments and, with Entra ID P2, eligible PIM
        assignments). When a role is assigned to a group, the group's transitive members are read with
        JSON batching (GET /groups/{id}/transitiveMembers) and reported with Via = 'Group: <name>'.
        Rows: RoleName, RoleTemplateId, PrincipalId, PrincipalType (User, Group member user, ServicePrincipal...),
        DisplayName, UserPrincipalName, UserType, Assignment (Active/Eligible), Via.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [object] $DirectoryRoles,

        [Parameter()]
        [string[]] $RoleTemplateId
    )

    $definitions = @{}
    foreach ($definition in @(Get-ArgusProperty $DirectoryRoles 'Definitions' @())) {
        $definitions[[string]$definition.id] = $definition
    }

    $entries = [System.Collections.Generic.List[object]]::new()
    foreach ($assignment in @(Get-ArgusProperty $DirectoryRoles 'Assignments' @())) { $entries.Add(@{ Item = $assignment; Kind = 'Active' }) }
    foreach ($assignment in @(Get-ArgusProperty $DirectoryRoles 'Eligible' @())) { $entries.Add(@{ Item = $assignment; Kind = 'Eligible' }) }

    $typeName = {
        param($Principal)
        $odataType = [string](Get-ArgusProperty $Principal '@odata.type' '')
        switch -Wildcard ($odataType) {
            '*user' { 'User' }
            '*group' { 'Group' }
            '*servicePrincipal' { 'ServicePrincipal' }
            default { if ($odataType) { $odataType.Split('.')[-1] } else { 'Unknown' } }
        }
    }

    $rows = [System.Collections.Generic.List[object]]::new()
    $groupAssignments = [System.Collections.Generic.List[object]]::new()
    foreach ($entry in $entries) {
        $assignment = $entry.Item
        $roleId = [string](Get-ArgusProperty $assignment 'roleDefinitionId' '')
        $definition = $definitions[$roleId]
        $templateId = if ($definition) { [string](Get-ArgusProperty $definition 'templateId' $roleId) } else { $roleId }
        if ($RoleTemplateId -and $templateId -notin $RoleTemplateId -and $roleId -notin $RoleTemplateId) { continue }
        $roleName = if ($definition) { [string](Get-ArgusProperty $definition 'displayName' $roleId) } else { $roleId }
        $principal = Get-ArgusProperty $assignment 'principal'
        $type = & $typeName $principal
        $row = [pscustomobject]@{
            RoleName          = $roleName
            RoleTemplateId    = $templateId
            PrincipalId       = [string](Get-ArgusProperty $assignment 'principalId' '')
            PrincipalType     = $type
            DisplayName       = [string](Get-ArgusProperty $principal 'displayName' '')
            UserPrincipalName = [string](Get-ArgusProperty $principal 'userPrincipalName' '')
            UserType          = [string](Get-ArgusProperty $principal 'userType' '')
            Assignment        = $entry.Kind
            Via               = 'Direct'
        }
        if ($type -eq 'Group') { $groupAssignments.Add($row) } else { $rows.Add($row) }
    }

    if ($groupAssignments.Count -gt 0) {
        $groupIds = @($groupAssignments | ForEach-Object { $_.PrincipalId } | Sort-Object -Unique)
        $requests = @($groupIds | ForEach-Object { @{ Id = $_; Url = "/groups/$_/transitiveMembers?`$select=id,displayName,userPrincipalName,userType" } })
        $members = @{}
        foreach ($response in @(Invoke-ArgusGraphBatch -Request $requests)) {
            $members[$response.Id] = if ($response.Status -eq 200) { @(Get-ArgusProperty $response.Body 'value' @()) } else { $null }
        }
        foreach ($groupRow in $groupAssignments) {
            $groupMembers = $members[$groupRow.PrincipalId]
            if ($null -eq $groupMembers) {
                # Members could not be read: keep the group itself so it is still counted and visible.
                $rows.Add($groupRow)
                continue
            }
            foreach ($member in $groupMembers) {
                $rows.Add([pscustomobject]@{
                        RoleName          = $groupRow.RoleName
                        RoleTemplateId    = $groupRow.RoleTemplateId
                        PrincipalId       = [string](Get-ArgusProperty $member 'id' '')
                        PrincipalType     = & $typeName $member
                        DisplayName       = [string](Get-ArgusProperty $member 'displayName' '')
                        UserPrincipalName = [string](Get-ArgusProperty $member 'userPrincipalName' '')
                        UserType          = [string](Get-ArgusProperty $member 'userType' '')
                        Assignment        = $groupRow.Assignment
                        Via               = 'Group: ' + $groupRow.DisplayName
                    })
            }
        }
    }

    $rows
}
