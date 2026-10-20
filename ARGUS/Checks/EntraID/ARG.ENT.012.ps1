Register-ArgusCheck @{
    Id          = 'ARG.ENT.012'
    Title       = 'LinkedIn account connections disabled'
    Area        = 'EntraID'
    Category    = 'User settings'
    Severity    = 'Low'
    Description = 'The LinkedIn account connections setting (Microsoft Entra admin center > Users > User settings) lets users connect their work account to LinkedIn in Microsoft apps. It is enabled by default, except for organisations provisioned in Germany or France. Microsoft Graph has no documented API to read this setting, so ARGUS cannot evaluate it: the result is always Investigate and the setting must be checked manually. Expected value: **No** (or Selected group, if a business need was approved).'
    Rationale   = 'Once a user consents, Microsoft apps exchange profile and connection data between the work account and LinkedIn. Whether to allow it is an organisation decision about data sharing with a third-party service, and it should be explicit rather than left at the default.'
    Remediation = @{
        Steps      = "1. Open the Microsoft Entra admin center > Users > User settings.`n2. Under LinkedIn account connections, check the current value.`n3. Select No, or Selected group with a group of approved users, and save.`n4. Record the decision; ARGUS will keep reporting this check as Investigate because the value cannot be read."
        PortalUrl  = 'https://entra.microsoft.com/#view/Microsoft_AAD_UsersAndTenants/UserManagementMenuBlade/~/UserSettings'
    }
    References  = @(
        @{ Title = 'Admin consent for LinkedIn account connections'; Url = 'https://learn.microsoft.com/en-us/entra/identity/users/linkedin-integration' }
        @{ Title = 'LinkedIn account connections data sharing and consent'; Url = 'https://learn.microsoft.com/en-us/entra/identity/users/linkedin-user-consent' }
    )
    Requires    = @{
        Services = @('Graph')
    }
    Tags        = @('User settings', 'Manual')
    Test        = {
        # No param($Context): the setting is not readable through Graph, so no tenant data is used.
        New-ArgusResult -Status Investigate `
            -Summary 'Manual verification required: the LinkedIn account connections setting cannot be read through Microsoft Graph. Check it in the Microsoft Entra admin center (Users > User settings); it should be No, or limited to a selected group.'
    }
}
