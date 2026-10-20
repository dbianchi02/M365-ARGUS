Register-ArgusCheck @{
    Id          = 'ARG.APP.005'
    Title       = 'Certificates expiring within {DaysAhead} days'
    Area        = 'Applications'
    Category    = 'Credential hygiene'
    Severity    = 'Medium'
    Description = 'Certificates (`keyCredentials` with usage **Verify**, used by the app to authenticate) that expire within the next **{DaysAhead}** days. A certificate counts as **replaced** when the same app already has another certificate valid beyond that window; the check fails only for certificates without a replacement.'
    Rationale   = 'An expired certificate stops app-only integrations (automation, connectors, scripts). Planned renewal avoids outages.'
    Remediation = @{
        Steps      = "1. Ask the application owner which service uses the certificate.`n2. Issue a new certificate (ideally from Azure Key Vault with automatic renewal), upload it to the app registration and deploy it to the service.`n3. Remove the old certificate once nothing uses it."
        PortalUrl  = 'https://entra.microsoft.com/'
    }
    References  = @(
        @{ Title = 'Add and manage app credentials in Microsoft Entra ID'; Url = 'https://learn.microsoft.com/en-us/entra/identity-platform/how-to-add-credentials' }
        @{ Title = 'Enforce secret and certificate standards with application management policies'; Url = 'https://learn.microsoft.com/en-us/entra/identity/enterprise-apps/tutorial-enforce-secret-standards' }
    )
    Requires    = @{
        Services    = @('Graph')
        GraphScopes = @('Application.Read.All')
        DataSets    = @('Applications')
    }
    Parameters  = @{ DaysAhead = 30 }
    Tags        = @('Applications', 'Credentials')
    Test        = {
        param($Context)
        $window = $Context.Now.AddDays([int]$Context.Parameters.DaysAhead)
        $valid = @(Get-ArgusAppCredential -Application @($Context.Data['Applications']) -Type Certificate -Usage Verify | Where-Object { $_.End -and $_.End -gt $Context.Now })
        $findings = @($valid | Where-Object { $_.End -le $window } | ForEach-Object {
                $credential = $_
                $replaced = [bool]($valid | Where-Object { $_.ObjectId -eq $credential.ObjectId -and $_.KeyId -ne $credential.KeyId -and $_.End -gt $window })
                [pscustomobject]@{
                    AppName         = $credential.AppName
                    AppId           = $credential.AppId
                    CertificateName = $credential.CredentialName
                    Expires         = Format-ArgusDate $credential.End
                    DaysLeft        = [int][math]::Floor(($credential.End - $Context.Now).TotalDays)
                    Replaced        = if ($replaced) { 'Yes' } else { 'No' }
                    KeyId           = $credential.KeyId
                    ObjectId        = $credential.ObjectId
                }
            } | Sort-Object DaysLeft)
        $open = @($findings | Where-Object Replaced -EQ 'No').Count
        if ($findings.Count -eq 0) {
            return New-ArgusResult -Status Passed -EvaluatedCount $valid.Count -Summary 'No certificate expires within {DaysAhead} days ({EvaluatedCount} valid certificates evaluated).'
        }
        $status = if ($open -gt 0) { 'Failed' } else { 'Passed' }
        New-ArgusResult -Status $status -Findings $findings -EvaluatedCount $valid.Count `
            -Summary ("{AffectedCount} of {EvaluatedCount} certificates expire within {DaysAhead} days; $open without a replacement certificate.")
    }
}
