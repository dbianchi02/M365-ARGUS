Register-ArgusCheck @{
    Id          = 'ARG.APP.006'
    Title       = 'Expired certificates still present'
    Area        = 'Applications'
    Category    = 'Credential hygiene'
    Severity    = 'Low'
    Description = 'Certificates (`keyCredentials`, any usage) whose `endDateTime` is in the past but that are still attached to the app registration.'
    Rationale   = 'Expired certificates are clutter that hides which credentials are really in use and makes credential reviews harder.'
    Remediation = @{
        Steps      = "1. Confirm the expired certificate is no longer deployed anywhere.`n2. Delete it from the app registration (Certificates & secrets > Certificates)."
        PortalUrl  = 'https://entra.microsoft.com/'
    }
    References  = @(
        @{ Title = 'Add and manage app credentials in Microsoft Entra ID'; Url = 'https://learn.microsoft.com/en-us/entra/identity-platform/how-to-add-credentials' }
    )
    Requires    = @{
        Services    = @('Graph')
        GraphScopes = @('Application.Read.All')
        DataSets    = @('Applications')
    }
    Tags        = @('Applications', 'Credentials')
    Test        = {
        param($Context)
        $all = @(Get-ArgusAppCredential -Application @($Context.Data['Applications']) -Type Certificate)
        $findings = @($all | Where-Object { $_.End -and $_.End -le $Context.Now } | ForEach-Object {
                [pscustomobject]@{
                    AppName         = $_.AppName
                    AppId           = $_.AppId
                    CertificateName = $_.CredentialName
                    Expired         = Format-ArgusDate $_.End
                    DaysExpired     = [int][math]::Floor(($Context.Now - $_.End).TotalDays)
                    KeyId           = $_.KeyId
                    ObjectId        = $_.ObjectId
                }
            } | Sort-Object DaysExpired -Descending)
        $apps = @($findings | Select-Object -ExpandProperty AppId -Unique).Count
        $status = if ($findings.Count -gt 0) { 'Failed' } else { 'Passed' }
        New-ArgusResult -Status $status -Findings $findings -EvaluatedCount $all.Count `
            -Summary ("{AffectedCount} of {EvaluatedCount} certificates are expired but still present on $apps app registration" + $(if ($apps -eq 1) { '' } else { 's' }) + '.')
    }
}
