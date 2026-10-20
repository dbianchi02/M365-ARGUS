Register-ArgusCheck @{
    Id          = 'ARG.ENT.009'
    Title       = 'Directory roles assigned to guests'
    Area        = 'EntraID'
    Category    = 'Privileged access'
    Severity    = 'High'
    Description = 'Any Microsoft Entra directory role (active, or eligible with Entra ID P2) held by a guest account, directly or through a role-assignable group.'
    Rationale   = 'Administrative roles should be held by accounts the organisation controls. A guest account follows the lifecycle of another tenant: when the person leaves their company, nobody here is notified.'
    Remediation = @{
        Steps      = "1. Confirm why the guest needs the role (often a supplier or a former consultant).`n2. Remove the role assignment from the guest.`n3. If the access is still needed, create an internal account for the person, or use a partner relationship (GDAP) for service providers."
        PowerShell = "# Sample only - review before running. Removes one role assignment.`nConnect-MgGraph -Scopes 'RoleManagement.ReadWrite.Directory'`nRemove-MgRoleManagementDirectoryRoleAssignment -UnifiedRoleAssignmentId '<AssignmentId>'"
        PortalUrl  = 'https://entra.microsoft.com/'
    }
    References  = @(
        @{ Title = 'Best practices for Microsoft Entra roles'; Url = 'https://learn.microsoft.com/en-us/entra/identity/role-based-access-control/best-practices' }
        @{ Title = 'Default user permissions (guests)'; Url = 'https://learn.microsoft.com/en-us/entra/fundamentals/users-default-permissions' }
    )
    Requires    = @{
        Services    = @('Graph')
        GraphScopes = @('RoleManagement.Read.Directory', 'GroupMember.Read.All')
        DataSets    = @('DirectoryRoles')
    }
    Tags        = @('Roles', 'Guests', 'Privileged access')
    Test        = {
        param($Context)
        $members = @(Get-ArgusRoleMember -DirectoryRoles $Context.Data['DirectoryRoles'])
        $findings = @($members | Where-Object { $_.UserType -eq 'Guest' } | ForEach-Object {
                [pscustomobject]@{
                    DisplayName       = $_.DisplayName
                    UserPrincipalName = $_.UserPrincipalName
                    Role              = $_.RoleName
                    Assignment        = $_.Assignment
                    Via               = $_.Via
                    ObjectId          = $_.PrincipalId
                }
            } | Sort-Object DisplayName, Role)
        $status = if ($findings.Count -gt 0) { 'Failed' } else { 'Passed' }
        $summary = if ($findings.Count -gt 0) { '{AffectedCount} directory role assignments are held by guests.' } else { 'No directory role is held by a guest ({EvaluatedCount} role holders evaluated).' }
        New-ArgusResult -Status $status -Findings $findings -EvaluatedCount $members.Count -Summary $summary
    }
}
