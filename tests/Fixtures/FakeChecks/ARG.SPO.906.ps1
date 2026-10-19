# Fake check used only by tests: excluded with -ExcludeId in the sample run, so it is NotRun.
Register-ArgusCheck @{
    Id          = 'ARG.SPO.906'
    Title       = 'Fake check excluded from the run'
    Area        = 'SharePoint'
    Category    = 'Test fixtures'
    Severity    = 'Low'
    Description = 'Fake check used by the Pester tests and the sample results. Excluded with -ExcludeId.'
    Rationale   = 'Exercises the **NotRun** status.'
    Remediation = @{ Steps = '1. Nothing to do.' }
    Requires    = @{}
    Tags        = @('Fake')
    Test        = {
        param($Context)
        New-ArgusResult -Status Passed -Summary 'Should never run in the sample.'
    }
}
