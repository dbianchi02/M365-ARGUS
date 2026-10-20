Register-ArgusCheck @{
    Id          = 'ARG.COP.007'
    Title       = 'Copilot enhanced personalization (memory) is a deliberate choice'
    Area        = 'Copilot'
    Category    = 'AI data processing'
    Severity    = 'Low'
    UsesBeta    = $true
    Description = 'Reads the enhanced personalization control (`GET /beta/copilot/settings/people/enhancedpersonalization`). When `isEnabledInOrganization` is true and no `disabledForGroup` is set, Copilot memory and personalized recommendations are on for everybody: To review. Passed when the control is off, or on with a group excluded.'
    Rationale   = 'Enhanced personalization lets Copilot use each user''s Teams chats, emails, meeting transcripts, usage signals and profile to remember preferences across conversations. The data stays within the user''s scope, but it is a new processing purpose that privacy notices and works-council agreements may need to cover.'
    Remediation = @{
        Steps      = "1. Decide with privacy and HR whether Copilot memory is allowed for everyone, nobody, or everyone except a group.`n2. To turn it off for a group, set disabledForGroup to that group's object ID; to turn it off for the organisation, set isEnabledInOrganization to false (PowerShell below).`n3. Update the privacy notice for Copilot users accordingly."
        PowerShell = "# Sample only - review before running.`nConnect-MgGraph -Scopes 'PeopleSettings.ReadWrite.All'`nInvoke-MgGraphRequest -Method PATCH -Uri 'https://graph.microsoft.com/beta/copilot/settings/people/enhancedpersonalization' -Body @{ disabledForGroup = '<group-object-id>' }"
        PortalUrl  = 'https://admin.microsoft.com/'
    }
    References  = @(
        @{ Title = 'Microsoft Copilot enhanced personalization control'; Url = 'https://learn.microsoft.com/en-us/graph/control-enhanced-personalization-privacy' }
        @{ Title = 'Get enhancedPersonalizationSetting'; Url = 'https://learn.microsoft.com/en-us/graph/api/enhancedpersonalizationsetting-get?view=graph-rest-beta' }
    )
    Requires    = @{
        Services    = @('Graph')
        GraphScopes = @('PeopleSettings.Read.All')
        DataSets    = @('CopilotPersonalization')
    }
    Tags        = @('Copilot', 'AI', 'GDPR', 'Privacy')
    Test        = {
        param($Context)
        $setting = $Context.Data['CopilotPersonalization']
        $unavailable = Get-ArgusProperty $setting 'ArgusUnavailable'
        if ($unavailable) { return New-ArgusResult -Status Skipped -SkipReason $unavailable }
        $enabled = Get-ArgusProperty $setting 'isEnabledInOrganization'
        if ($null -eq $enabled) { return New-ArgusResult -Status Investigate -Summary 'The enhanced personalization setting could not be read.' }
        $group = [string](Get-ArgusProperty $setting 'disabledForGroup' '')
        if (-not $enabled) {
            return New-ArgusResult -Status Passed -EvaluatedCount 1 -AffectedCount 0 -Summary 'Enhanced personalization (Copilot memory) is turned off for the organisation.'
        }
        if ($group) {
            return New-ArgusResult -Status Passed -EvaluatedCount 1 -AffectedCount 0 -Summary "Enhanced personalization is on, except for the members of group $group."
        }
        $finding = [pscustomobject]@{ Setting = 'isEnabledInOrganization'; Value = 'True'; DisabledForGroup = 'None' }
        New-ArgusResult -Status Investigate -Findings @($finding) -EvaluatedCount 1 `
            -Summary 'Enhanced personalization (Copilot memory) is on for every user; confirm it is covered by the privacy notice.'
    }
}
