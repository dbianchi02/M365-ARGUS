# Fake check used only by tests: always Passed.
Register-ArgusCheck @{
    Id          = 'ARG.ENT.901'
    Title       = 'Fake check that passes'
    Area        = 'EntraID'
    Category    = 'Test fixtures'
    Severity    = 'Medium'
    Description = 'Fake check used by the Pester tests. It always passes.'
    Rationale   = 'Exercises the **Passed** path of the runner.'
    Remediation = @{
        Steps      = "1. Nothing to do.`n2. This is a test fixture."
        PowerShell = '# Sample only - not executed by ARGUS'
        PortalUrl  = 'https://entra.microsoft.com/'
    }
    References  = @(@{ Title = 'ARGUS specification'; Url = 'https://github.com/dbianchi02/M365-ARGUS' })
    Requires    = @{ Services = @(); GraphScopes = @(); DataSets = @() }
    Parameters  = @{}
    Tags        = @('Fake', 'Users')
    Test        = {
        param($Context)
        New-ArgusResult -Status Passed -Summary 'All {EvaluatedCount} fake users are compliant.' -EvaluatedCount 1204
    }
}
