# Fake check used only by tests: always Investigate.
Register-ArgusCheck @{
    Id          = 'ARG.GRP.904'
    Title       = 'Fake setting that needs manual review'
    Area        = 'GroupsTeams'
    Category    = 'Test fixtures'
    Severity    = 'Medium'
    Description = 'Fake check used by the Pester tests. It always returns Investigate.'
    Rationale   = 'Exercises the **Investigate** path and its partial scoring credit.'
    Remediation = @{ Steps = '1. Review the setting with the customer.' }
    Requires    = @{}
    Tags        = @('Fake', 'Groups')
    Test        = {
        param($Context)
        New-ArgusResult -Status Investigate -Summary 'Group creation is unrestricted; acceptable in some organisations.'
    }
}
