Register-ArgusCheck @{
    Id          = 'ARG.ENT.002'
    Title       = 'Licensed users without manager or department'
    Area        = 'EntraID'
    Category    = 'Identity lifecycle'
    Severity    = 'Low'
    Description = 'Enabled member users with at least one licence whose `manager` or `department` is empty in Microsoft Entra ID (`GET /users?$expand=manager`). Accounts without licences (service, shared and emergency accounts) are not evaluated; use the global exclusions for licensed accounts that are not people.'
    Rationale   = 'Manager and department drive access reviews, approval workflows, dynamic groups, the organisation chart and the people Copilot considers relevant. Missing values usually mean the HR provisioning or the joiner process skipped a step, and they make every later governance step manual.'
    Remediation = @{
        Steps      = "1. Fix the source: when users are synchronised or provisioned from HR, complete manager and department there.`n2. For cloud-only users, set them in the Microsoft Entra admin center (Users > user > Properties > Job information).`n3. Make both attributes mandatory in the joiner process."
        PowerShell = "# Sample only - review before running.`nConnect-MgGraph -Scopes 'User.ReadWrite.All'`nUpdate-MgUser -UserId '<user>' -Department '<department>'`nSet-MgUserManagerByRef -UserId '<user>' -BodyParameter @{ '@odata.id' = 'https://graph.microsoft.com/v1.0/users/<manager id>' }"
        PortalUrl  = 'https://entra.microsoft.com/#view/Microsoft_AAD_UsersAndTenants/UserManagementMenuBlade/~/AllUsers'
    }
    References  = @(
        @{ Title = 'Add or update a user''s profile information'; Url = 'https://learn.microsoft.com/en-us/entra/fundamentals/how-to-manage-user-profile-info' }
        @{ Title = 'List manager'; Url = 'https://learn.microsoft.com/en-us/graph/api/user-list-manager' }
    )
    Requires    = @{
        Services    = @('Graph')
        GraphScopes = @('User.Read.All')
        DataSets    = @('Users', 'UserManagers')
    }
    Tags        = @('Users', 'Lifecycle', 'DataQuality')
    Test        = {
        param($Context)
        $relations = $Context.Data['UserManagers']
        $people = @($Context.Data['Users'] | Where-Object {
                (Get-ArgusProperty $_ 'userType' '') -eq 'Member' -and (Get-ArgusProperty $_ 'accountEnabled') -eq $true -and
                @(Get-ArgusProperty $_ 'assignedLicenses' @()).Count -gt 0
            })
        $findings = @($people | ForEach-Object {
                $id = [string](Get-ArgusProperty $_ 'id' '')
                $info = if ($relations -and $relations.Contains($id)) { $relations[$id] } else { $null }
                $manager = [string](Get-ArgusProperty $info 'Manager' '')
                $department = [string](Get-ArgusProperty $info 'Department' '')
                if ($manager -and $department) { return }
                [pscustomobject]@{
                    DisplayName       = Get-ArgusProperty $_ 'displayName' ''
                    UserPrincipalName = Get-ArgusProperty $_ 'userPrincipalName' ''
                    Missing           = (@($(if (-not $manager) { 'Manager' }), $(if (-not $department) { 'Department' })) | Where-Object { $_ }) -join ', '
                    Manager           = $manager
                    Department        = $department
                    ObjectId          = $id
                }
            } | Sort-Object Missing, UserPrincipalName)
        $status = if ($findings.Count -gt 0) { 'Failed' } else { 'Passed' }
        New-ArgusResult -Status $status -Findings $findings -EvaluatedCount $people.Count `
            -Summary '{AffectedCount} of {EvaluatedCount} licensed users have no manager or no department.'
    }
}
