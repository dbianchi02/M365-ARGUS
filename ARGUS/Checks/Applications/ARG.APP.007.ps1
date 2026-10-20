Register-ArgusCheck @{
    Id          = 'ARG.APP.007'
    Title       = 'Certificates with a lifetime above {MaxLifetimeDays} days'
    Area        = 'Applications'
    Category    = 'Credential hygiene'
    Severity    = 'Low'
    Description = 'Valid authentication certificates (`keyCredentials` with usage **Verify**) whose lifetime (`endDateTime` minus `startDateTime`) exceeds **{MaxLifetimeDays}** days. Expired certificates are covered by ARG.APP.006.'
    Rationale   = 'Microsoft recommends limiting application certificate lifetime to 180 days and automating renewal. Long-lived certificates are rarely rotated and stay valid long after the people who deployed them have moved on.'
    Remediation = @{
        Steps      = "1. Issue certificates from Azure Key Vault with automatic renewal and a lifetime within the policy (Microsoft recommends 180 days or less).`n2. Upload the new certificate, deploy it to the service, then remove the long-lived one.`n3. Consider an application management policy that limits certificate lifetime (asymmetricKeyLifetime) for new credentials."
        PortalUrl  = 'https://entra.microsoft.com/'
    }
    References  = @(
        @{ Title = 'Enforce secret and certificate standards with application management policies'; Url = 'https://learn.microsoft.com/en-us/entra/identity/enterprise-apps/tutorial-enforce-secret-standards' }
        @{ Title = 'Add and manage app credentials in Microsoft Entra ID'; Url = 'https://learn.microsoft.com/en-us/entra/identity-platform/how-to-add-credentials' }
    )
    Requires    = @{
        Services    = @('Graph')
        GraphScopes = @('Application.Read.All')
        DataSets    = @('Applications')
    }
    Parameters  = @{ MaxLifetimeDays = 180 }
    Tags        = @('Applications', 'Credentials')
    Test        = {
        param($Context)
        $maxDays = [double]$Context.Parameters.MaxLifetimeDays
        $valid = @(Get-ArgusAppCredential -Application @($Context.Data['Applications']) -Type Certificate -Usage Verify | Where-Object { $_.End -and $_.End -gt $Context.Now })
        $findings = @($valid | Where-Object { $_.Start -and ($_.End - $_.Start).TotalDays -gt ($maxDays + 1) } | ForEach-Object {
                [pscustomobject]@{
                    AppName         = $_.AppName
                    AppId           = $_.AppId
                    CertificateName = $_.CredentialName
                    ValidFrom       = Format-ArgusDate $_.Start
                    Expires         = Format-ArgusDate $_.End
                    LifetimeDays    = [int][math]::Round(($_.End - $_.Start).TotalDays)
                    KeyId           = $_.KeyId
                    ObjectId        = $_.ObjectId
                }
            } | Sort-Object LifetimeDays -Descending)
        $status = if ($findings.Count -gt 0) { 'Failed' } else { 'Passed' }
        New-ArgusResult -Status $status -Findings $findings -EvaluatedCount $valid.Count `
            -Summary '{AffectedCount} of {EvaluatedCount} valid authentication certificates have a lifetime longer than {MaxLifetimeDays} days.'
    }
}
