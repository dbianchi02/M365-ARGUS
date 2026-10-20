Register-ArgusCheck @{
    Id          = 'ARG.COP.002'
    Title       = 'Users cannot sign up for self-service trials (Copilot Studio, Power Platform)'
    Area        = 'Copilot'
    Category    = 'Licence governance'
    Severity    = 'Medium'
    Description = 'Reads `authorizationPolicy.allowedToSignUpEmailBasedSubscriptions`. When it is true, users can sign themselves up for email-based ("viral") subscriptions such as the Copilot Studio and Power Apps trials, and start building agents and apps without an assigned licence. `allowEmailVerifiedUsersToJoinOrganization` is shown for context.'
    Rationale   = 'Self-service sign-ups put agent and app creation outside any licence, environment or data policy decision. Agents built on trial licences are hard to inventory and often stop working, or keep running, after the trial ends.'
    Remediation = @{
        Steps      = "1. Decide who may build agents with Copilot Studio and assign them licences or a governed environment.`n2. Turn off self-service sign-up by setting allowedToSignUpEmailBasedSubscriptions to false in the authorization policy (PowerShell below).`n3. In the Power Platform admin center, also review who can create environments and trial environments."
        PowerShell = "# Sample only - review before running.`nConnect-MgGraph -Scopes 'Policy.ReadWrite.Authorization'`nUpdate-MgPolicyAuthorizationPolicy -AllowedToSignUpEmailBasedSubscriptions:`$false"
        PortalUrl  = 'https://admin.powerplatform.microsoft.com/'
    }
    References  = @(
        @{ Title = 'authorizationPolicy resource type'; Url = 'https://learn.microsoft.com/en-us/graph/api/resources/authorizationpolicy' }
        @{ Title = 'Copilot Studio licensing and subscriptions: self-service trials'; Url = 'https://learn.microsoft.com/en-us/microsoft-copilot-studio/requirements-licensing-subscriptions' }
    )
    Requires    = @{
        Services    = @('Graph')
        GraphScopes = @('Policy.Read.All')
        DataSets    = @('AuthorizationPolicy')
    }
    Tags        = @('Copilot', 'Licensing', 'Policy')
    Test        = {
        param($Context)
        $policy = $Context.Data['AuthorizationPolicy']
        $signUp = Get-ArgusProperty $policy 'allowedToSignUpEmailBasedSubscriptions'
        if ($null -eq $signUp) { return New-ArgusResult -Status Investigate -Summary 'The self-service sign-up setting could not be read.' }
        $join = Get-ArgusProperty $policy 'allowEmailVerifiedUsersToJoinOrganization'
        $finding = [pscustomobject]@{
            Setting = 'allowedToSignUpEmailBasedSubscriptions'
            Value   = [string]$signUp
            Related = "allowEmailVerifiedUsersToJoinOrganization = $join"
        }
        if ($signUp) {
            return New-ArgusResult -Status Failed -Findings @($finding) -EvaluatedCount 1 -Summary 'Users can sign up for self-service trials such as Copilot Studio (allowedToSignUpEmailBasedSubscriptions = true).'
        }
        New-ArgusResult -Status Passed -EvaluatedCount 1 -AffectedCount 0 -Summary 'Self-service sign-up for email-based subscriptions is turned off.'
    }
}
