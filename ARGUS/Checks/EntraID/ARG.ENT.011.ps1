Register-ArgusCheck @{
    Id          = 'ARG.ENT.011'
    Title       = 'Users can create tenants'
    Area        = 'EntraID'
    Category    = 'Tenant governance'
    Severity    = 'Low'
    Description = 'Reads `authorizationPolicy.defaultUserRolePermissions.allowedToCreateTenants` ("Restrict non-admin users from creating tenants" in User settings). Fails when non-admin users can create Microsoft Entra tenants.'
    Rationale   = 'A tenant created by a user becomes a separate directory where that user is Global Administrator, outside the organisation''s governance and visibility.'
    Remediation = @{
        Steps      = "1. In the Microsoft Entra admin center, go to Users > User settings.`n2. Set 'Restrict non-admin users from creating tenants' to Yes.`n3. Assign the Tenant Creator role to anyone who legitimately needs to create tenants."
        PowerShell = "# Sample only - review before running.`nConnect-MgGraph -Scopes 'Policy.ReadWrite.Authorization'`nUpdate-MgPolicyAuthorizationPolicy -DefaultUserRolePermissions @{ AllowedToCreateTenants = `$false }"
        PortalUrl  = 'https://entra.microsoft.com/'
    }
    References  = @(
        @{ Title = 'Default user permissions (restrict tenant creation)'; Url = 'https://learn.microsoft.com/en-us/entra/fundamentals/users-default-permissions' }
    )
    Requires    = @{
        Services    = @('Graph')
        GraphScopes = @('Policy.Read.All')
        DataSets    = @('AuthorizationPolicy')
    }
    Tags        = @('Policy', 'Tenant')
    Test        = {
        param($Context)
        $allowed = Get-ArgusProperty $Context.Data['AuthorizationPolicy'] 'defaultUserRolePermissions.allowedToCreateTenants'
        if ($null -eq $allowed) { return New-ArgusResult -Status Investigate -Summary 'The tenant creation setting could not be read.' }
        if ($allowed) { return New-ArgusResult -Status Failed -Summary 'Non-admin users can create Microsoft Entra tenants (allowedToCreateTenants = true).' }
        New-ArgusResult -Status Passed -Summary 'Non-admin users cannot create tenants.'
    }
}
