Register-ArgusCheck @{
    Id          = 'ARG.COP.009'
    Title       = 'Users can register agent identity blueprints'
    Area        = 'Copilot'
    Category    = 'Agent governance'
    Severity    = 'Medium'
    UsesBeta    = $true
    Description = 'Reads `authorizationPolicy.defaultUserRolePermissions.allowedToCreateAgentIdentityBlueprints` ("Users can register agent identity blueprints" in Entra ID > Users > User settings) from the beta endpoint (`GET /beta/policies/authorizationPolicy`); v1.0 does not return it and Learn does not document it yet. Fails when every user without an admin role can create agent identity blueprints, the default from the November 2026 rollout. The setting is independent of "Users can register applications" (ARG.ENT.010). Skipped when the tenant does not return the property yet.'
    Rationale   = 'An agent identity blueprint is the template and credential holder for the agent identities created from it. Blueprints created by any user have no reviewed owner, purpose or permission scope, and every agent built on them inherits that gap. Restricting creation to administrators keeps agent identities inventoried and governed.'
    Remediation = @{
        Steps      = "1. In the Microsoft Entra admin center, go to Entra ID > Users > User settings.`n2. Set 'Users can register agent identity blueprints' to No and save.`n3. Let administrators (or a dedicated role) create blueprints, and review the existing ones (GET /applications/microsoft.graph.agentIdentityBlueprint) for owner and purpose."
        PowerShell = "# Sample only - review before running.`nConnect-MgGraph -Scopes 'Policy.ReadWrite.Authorization'`n`$body = @{ defaultUserRolePermissions = @{ allowedToCreateAgentIdentityBlueprints = `$false } }`nInvoke-MgGraphRequest -Method PATCH -Uri 'https://graph.microsoft.com/beta/policies/authorizationPolicy/authorizationPolicy' -Body (`$body | ConvertTo-Json)"
        PortalUrl  = 'https://entra.microsoft.com/'
    }
    References  = @(
        @{ Title = 'Overview of agent identities in Microsoft Entra'; Url = 'https://learn.microsoft.com/en-us/entra/agent-id/agent-identities' }
        @{ Title = 'Best practices for Microsoft Entra Agent ID'; Url = 'https://learn.microsoft.com/en-us/entra/agent-id/best-practices-agent-id' }
        @{ Title = 'agentIdentityBlueprint resource type'; Url = 'https://learn.microsoft.com/en-us/graph/api/resources/agentidentityblueprint' }
    )
    Requires    = @{
        Services    = @('Graph')
        GraphScopes = @('Policy.Read.All')
        DataSets    = @('AuthorizationPolicyBeta')
    }
    Tags        = @('Copilot', 'Agents', 'Policy')
    Test        = {
        param($Context)
        $policy = $Context.Data['AuthorizationPolicyBeta']
        $unavailable = Get-ArgusProperty $policy 'ArgusUnavailable'
        if ($unavailable) { return New-ArgusResult -Status Skipped -SkipReason $unavailable }
        $allowed = Get-ArgusProperty $policy 'defaultUserRolePermissions.allowedToCreateAgentIdentityBlueprints'
        if ($null -eq $allowed) {
            return New-ArgusResult -Status Skipped -SkipReason 'The tenant does not return allowedToCreateAgentIdentityBlueprints yet (the setting rolls out from November 2026).'
        }
        if ($allowed) { return New-ArgusResult -Status Failed -Summary 'All users can register agent identity blueprints (allowedToCreateAgentIdentityBlueprints = true).' }
        New-ArgusResult -Status Passed -Summary 'Only administrators can register agent identity blueprints.'
    }
}
