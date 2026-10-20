Register-ArgusCheck @{
    Id          = 'ARG.SPO.002'
    Title       = 'Tenant external sharing level'
    Area        = 'SharePoint'
    Category    = 'Sharing'
    Severity    = 'Medium'
    Description = 'Reads the organisation-level sharing setting for SharePoint and OneDrive (`admin/sharepoint/settings.sharingCapability`). **Anyone** (`externalUserAndGuestSharing`: links that do not require sign-in) is reported as Investigate; New and existing guests, Existing guests only and Only people in your organisation pass. The findings also show the domain restriction mode and whether guests can reshare. Individual sites can only be more restrictive than this setting.'
    Rationale   = 'Anyone links can be forwarded to people outside the organisation without any record of who opened them. Many organisations allow them on purpose for a few sites; the tenant-wide level should be a conscious decision with site-level restrictions where needed.'
    Remediation = @{
        Steps      = "1. Decide which external sharing level the organisation needs.`n2. If Anyone links are required only for some sites, lower the organisation level to New and existing guests and allow Anyone only on those sites, or keep Anyone with link expiration and View-only defaults.`n3. Review the domain allow/block list and guest resharing."
        PortalUrl  = 'https://admin.microsoft.com/sharepoint?page=sharing&modern=true'
    }
    References  = @(
        @{ Title = 'Manage sharing settings for SharePoint and OneDrive'; Url = 'https://learn.microsoft.com/en-us/sharepoint/turn-external-sharing-on-or-off' }
        @{ Title = 'sharepointSettings resource type'; Url = 'https://learn.microsoft.com/en-us/graph/api/resources/sharepointsettings' }
    )
    Requires    = @{
        Services    = @('Graph')
        GraphScopes = @('SharePointTenantSettings.Read.All')
        DataSets    = @('SharePointTenantSettings')
    }
    Tags        = @('SharePoint', 'OneDrive', 'Sharing')
    Test        = {
        param($Context)
        $settings = $Context.Data['SharePointTenantSettings']
        $capability = [string](Get-ArgusProperty $settings 'sharingCapability' '')
        $labels = @{
            disabled                        = 'Only people in your organisation'
            existingExternalUserSharingOnly = 'Existing guests only'
            externalUserSharingOnly         = 'New and existing guests'
            externalUserAndGuestSharing     = 'Anyone (links without sign-in)'
        }
        $label = if ($labels.ContainsKey($capability)) { $labels[$capability] } else { $capability }
        $row = @([pscustomobject]@{
                SharingCapability            = $capability
                Level                        = $label
                DomainRestriction            = Get-ArgusProperty $settings 'sharingDomainRestrictionMode' ''
                GuestsCanReshare             = Get-ArgusProperty $settings 'isResharingByExternalUsersEnabled' ''
                GuestMustMatchInvitedAccount = Get-ArgusProperty $settings 'isRequireAcceptingUserToMatchInvitedUserEnabled' ''
            })
        if (-not $capability) {
            return New-ArgusResult -Status Investigate -Summary 'The SharePoint sharing setting could not be read.'
        }
        if ($capability -eq 'externalUserAndGuestSharing') {
            return New-ArgusResult -Status Investigate -Findings $row -Summary "External sharing allows Anyone links at organisation level ($label). Confirm this is intended and which sites need it."
        }
        New-ArgusResult -Status Passed -Findings $row -AffectedCount 0 -Summary "External sharing at organisation level: $label."
    }
}
