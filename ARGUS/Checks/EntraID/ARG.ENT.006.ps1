Register-ArgusCheck @{
    Id          = 'ARG.ENT.006'
    Title       = 'Guests without a sponsor'
    Area        = 'EntraID'
    Category    = 'External identities'
    Severity    = 'Medium'
    Description = 'Enabled guest users with no sponsor (`GET /users?$expand=sponsors`). Sponsors are the users or groups responsible for the guest''s access and information; Microsoft Entra sets the inviter as sponsor for new invitations, so guests without one were usually invited before sponsors existed, lost a sponsor that left, or were invited by sharing a SharePoint file (a known case where no sponsor is set). Skipped when the account cannot read sponsors.'
    Rationale   = 'Without a sponsor nobody is accountable for the guest: access reviews have no reviewer, and the guest stays after the collaboration ends. A sponsor (a person or, better, a group) makes guest lifecycle decisions possible.'
    Remediation = @{
        Steps      = "1. For each guest, find the team or project that collaborates with them (group memberships, the inviter in the audit log).`n2. Add a sponsor in the Microsoft Entra admin center (Users > guest > Sponsors), preferably a group.`n3. Remove guests that nobody wants to sponsor, and use sponsors as reviewers in guest access reviews."
        PowerShell = "# Sample only - review before running.`nConnect-MgGraph -Scopes 'User.ReadWrite.All'`nNew-MgUserSponsorByRef -UserId '<guest id>' -BodyParameter @{ '@odata.id' = 'https://graph.microsoft.com/v1.0/users/<sponsor id>' }"
        PortalUrl  = 'https://entra.microsoft.com/#view/Microsoft_AAD_UsersAndTenants/UserManagementMenuBlade/~/AllUsers'
    }
    References  = @(
        @{ Title = 'Add sponsors to a guest user'; Url = 'https://learn.microsoft.com/en-us/entra/external-id/b2b-sponsors' }
        @{ Title = 'List sponsors'; Url = 'https://learn.microsoft.com/en-us/graph/api/user-list-sponsors' }
    )
    Requires    = @{
        Services    = @('Graph')
        GraphScopes = @('User.Read.All')
        DataSets    = @('Users', 'GuestSponsors')
    }
    Tags        = @('Guests', 'Ownership')
    Test        = {
        param($Context)
        $sponsors = $Context.Data['GuestSponsors']
        $unavailable = Get-ArgusProperty $sponsors 'ArgusUnavailable'
        if ($unavailable) { return New-ArgusResult -Status Skipped -SkipReason $unavailable }
        $guests = @($Context.Data['Users'] | Where-Object { (Get-ArgusProperty $_ 'userType' '') -eq 'Guest' -and (Get-ArgusProperty $_ 'accountEnabled') -eq $true })
        $findings = @($guests | Where-Object {
                $id = [string](Get-ArgusProperty $_ 'id' '')
                -not ($sponsors -and $sponsors.Contains($id) -and @($sponsors[$id]).Count -gt 0)
            } | ForEach-Object {
                [pscustomobject]@{
                    DisplayName       = Get-ArgusProperty $_ 'displayName' ''
                    UserPrincipalName = Get-ArgusProperty $_ 'userPrincipalName' ''
                    Mail              = Get-ArgusProperty $_ 'mail' ''
                    Created           = Format-ArgusDate (Get-ArgusProperty $_ 'createdDateTime' '')
                    ObjectId          = Get-ArgusProperty $_ 'id' ''
                }
            } | Sort-Object Created, UserPrincipalName)
        $status = if ($findings.Count -gt 0) { 'Failed' } else { 'Passed' }
        New-ArgusResult -Status $status -Findings $findings -EvaluatedCount $guests.Count `
            -Summary '{AffectedCount} of {EvaluatedCount} enabled guests have no sponsor.'
    }
}
