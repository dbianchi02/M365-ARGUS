# Fake check used only by tests: always throws.
Register-ArgusCheck @{
    Id          = 'ARG.LIC.903'
    Title       = 'Fake check that throws'
    Area        = 'Licensing'
    Category    = 'Test fixtures'
    Severity    = 'Low'
    Description = 'Fake check used by the Pester tests. It always throws an exception.'
    Rationale   = 'Exercises the **Error** path: the run must continue.'
    Remediation = @{ Steps = '1. Nothing to do.' }
    Requires    = @{}
    Tags        = @('Fake')
    Test        = {
        param($Context)
        throw 'Simulated failure while reading fake data.'
    }
}
