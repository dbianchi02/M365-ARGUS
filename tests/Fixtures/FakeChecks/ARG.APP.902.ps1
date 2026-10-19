# Fake check used only by tests: always Failed, with findings.
Register-ArgusCheck @{
    Id          = 'ARG.APP.902'
    Title       = 'Fake secrets expiring within {DaysAhead} days'
    Area        = 'Applications'
    Category    = 'Test fixtures'
    Severity    = 'High'
    Description = 'Fake check used by the Pester tests. It always fails with three findings.'
    Rationale   = 'Exercises the **Failed** path, findings, exclusions and parameter placeholders.'
    Remediation = @{
        Steps      = "1. Open **App registrations**.`n2. Rotate the secret."
        PowerShell = '# Sample only - not executed by ARGUS'
        PortalUrl  = 'https://entra.microsoft.com/#view/Microsoft_AAD_RegisteredApps/ApplicationsListBlade'
    }
    References  = @(@{ Title = 'ARGUS specification'; Url = 'https://github.com/dbianchi02/M365-ARGUS' })
    Requires    = @{ Services = @(); DataSets = @() }
    Parameters  = @{ DaysAhead = 30 }
    Tags        = @('Fake', 'Credentials')
    Test        = {
        param($Context)
        $base = [datetime]::new(2026, 1, 1, 0, 0, 0, [System.DateTimeKind]::Utc)
        $findings = @(
            [pscustomobject]@{ DisplayName = 'Fake App One'; AppId = '11111111-1111-1111-1111-111111111111'; SecretEnd = $base.AddDays(5) }
            [pscustomobject]@{ DisplayName = '<script>alert(1)</script>'; AppId = '22222222-2222-2222-2222-222222222222'; SecretEnd = $base.AddDays(12) }
            [pscustomobject]@{ DisplayName = '=HYPERLINK("http://example.invalid")'; AppId = '33333333-3333-3333-3333-333333333333'; SecretEnd = $base.AddDays(29) }
        )
        New-ArgusResult -Status Failed -Summary '{AffectedCount} of {EvaluatedCount} fake apps have a secret expiring within {DaysAhead} days.' `
            -EvaluatedCount 40 -Findings $findings -FindingColumns 'DisplayName', 'AppId', 'SecretEnd'
    }
}
