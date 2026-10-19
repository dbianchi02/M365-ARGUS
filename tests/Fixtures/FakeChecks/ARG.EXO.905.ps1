# Fake check used only by tests: requires Exchange Online, so it is Skipped when not connected.
Register-ArgusCheck @{
    Id          = 'ARG.EXO.905'
    Title       = 'Fake check that needs Exchange Online'
    Area        = 'Exchange'
    Category    = 'Test fixtures'
    Severity    = 'Low'
    Description = 'Fake check used by the Pester tests. It requires an Exchange Online connection.'
    Rationale   = 'Exercises the **Skipped** path (prerequisite not met).'
    Remediation = @{ Steps = '1. Connect with `Connect-Argus -Service Graph, Exchange`.' }
    Requires    = @{ Services = @('Exchange') }
    Tags        = @('Fake')
    Test        = {
        param($Context)
        New-ArgusResult -Status Passed -Summary 'Should never run without Exchange Online.'
    }
}
