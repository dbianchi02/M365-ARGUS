Register-ArgusCheck @{
    Id          = 'ARG.ENT.010'
    Title       = 'Users can register applications'
    Area        = 'EntraID'
    Category    = 'Application governance'
    Severity    = 'Medium'
    Description = 'Reads `authorizationPolicy.defaultUserRolePermissions.allowedToCreateApps` ("Users can register applications" in User settings). Fails when every user can create app registrations.'
    Rationale   = 'App registrations created by anyone end up without an owner, a purpose or a credential policy. Restricting creation to the Application Developer role keeps the application estate governable.'
    Remediation = @{
        Steps      = "1. In the Microsoft Entra admin center, go to Users > User settings.`n2. Set 'Users can register applications' to No.`n3. Assign the Application Developer role to the people who need to register applications."
        PowerShell = "# Sample only - review before running.`nConnect-MgGraph -Scopes 'Policy.ReadWrite.Authorization'`nUpdate-MgPolicyAuthorizationPolicy -DefaultUserRolePermissions @{ AllowedToCreateApps = `$false }"
        PortalUrl  = 'https://entra.microsoft.com/'
    }
    References  = @(
        @{ Title = 'Delegate application management permissions'; Url = 'https://learn.microsoft.com/en-us/entra/identity/role-based-access-control/delegate-app-roles' }
        @{ Title = 'Default user permissions'; Url = 'https://learn.microsoft.com/en-us/entra/fundamentals/users-default-permissions' }
    )
    Requires    = @{
        Services    = @('Graph')
        GraphScopes = @('Policy.Read.All')
        DataSets    = @('AuthorizationPolicy')
    }
    Tags        = @('Applications', 'Policy')
    Test        = {
        param($Context)
        $allowed = Get-ArgusProperty $Context.Data['AuthorizationPolicy'] 'defaultUserRolePermissions.allowedToCreateApps'
        if ($null -eq $allowed) { return New-ArgusResult -Status Investigate -Summary 'The app registration setting could not be read.' }
        if ($allowed) { return New-ArgusResult -Status Failed -Summary 'All users can register applications (allowedToCreateApps = true).' }
        New-ArgusResult -Status Passed -Summary 'Only administrators and Application Developers can register applications.'
    }
}
