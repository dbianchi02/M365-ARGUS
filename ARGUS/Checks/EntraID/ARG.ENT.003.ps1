Register-ArgusCheck @{
    Id          = 'ARG.ENT.003'
    Title       = 'Guest invitations are restricted'
    Area        = 'EntraID'
    Category    = 'External identities'
    Severity    = 'Medium'
    Description = 'Reads who can invite guests (`authorizationPolicy.allowInvitesFrom`): **none** or **adminsAndGuestInviters** pass; **adminsGuestInvitersAndAllMembers** (all members can invite) needs review; **everyone** (guests can invite other guests too) fails.'
    Rationale   = 'Who can bring external people into the tenant is a governance decision. Letting guests invite other guests removes the organisation from that decision.'
    Remediation = @{
        Steps      = "1. In the Microsoft Entra admin center, go to External Identities > External collaboration settings.`n2. Under Guest invite settings, choose 'Only users assigned to specific admin roles can invite guest users', or at least prevent guests from inviting.`n3. Give the Guest Inviter role to the people who need to invite partners."
        PowerShell = "# Sample only - review before running.`nConnect-MgGraph -Scopes 'Policy.ReadWrite.Authorization'`nUpdate-MgPolicyAuthorizationPolicy -AllowInvitesFrom 'adminsAndGuestInviters'"
        PortalUrl  = 'https://entra.microsoft.com/'
    }
    References  = @(
        @{ Title = 'Configure external collaboration settings'; Url = 'https://learn.microsoft.com/en-us/entra/external-id/external-collaboration-settings-configure' }
    )
    Requires    = @{
        Services    = @('Graph')
        GraphScopes = @('Policy.Read.All')
        DataSets    = @('AuthorizationPolicy')
    }
    Tags        = @('Guests', 'Policy')
    Test        = {
        param($Context)
        $value = [string](Get-ArgusProperty $Context.Data['AuthorizationPolicy'] 'allowInvitesFrom' '')
        switch ($value) {
            'none' { New-ArgusResult -Status Passed -Summary 'Nobody can invite guests (allowInvitesFrom = none).' }
            'adminsAndGuestInviters' { New-ArgusResult -Status Passed -Summary 'Only admins and users with the Guest Inviter role can invite guests.' }
            'adminsGuestInvitersAndAllMembers' { New-ArgusResult -Status Investigate -Summary 'All member users can invite guests (allowInvitesFrom = adminsGuestInvitersAndAllMembers). Acceptable in some organisations: confirm it is intended.' }
            'everyone' { New-ArgusResult -Status Failed -Summary 'Everyone, including guests, can invite guests (allowInvitesFrom = everyone).' }
            default { New-ArgusResult -Status Investigate -Summary "Guest invitation setting could not be interpreted (allowInvitesFrom = '$value')." }
        }
    }
}
