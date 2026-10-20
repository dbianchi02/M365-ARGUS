Register-ArgusCheck @{
    Id          = 'ARG.APP.002'
    Title       = 'Client secrets expiring within {DaysAhead} days'
    Area        = 'Applications'
    Category    = 'Credential hygiene'
    Severity    = 'Medium'
    Description = 'Client secrets (`passwordCredentials`) of app registrations that expire within the next **{DaysAhead}** days. A secret counts as **replaced** when the same app already has another secret valid beyond that window; the check fails only for secrets without a replacement.'
    Rationale   = 'An expired secret stops the integration that uses it. Planned rotation, owned by someone, avoids outages discovered by users.'
    Remediation = @{
        Steps      = "1. Ask the application owner which service uses the secret.`n2. Add a new secret (or, better, a certificate or managed identity), update the service, and test it.`n3. Delete the old secret once nothing uses it."
        PowerShell = "# Sample only - review before running. Removes an old secret after the service was updated.`nConnect-MgGraph -Scopes 'Application.ReadWrite.All'`nRemove-MgApplicationPassword -ApplicationId '<ObjectId>' -KeyId '<KeyId>'"
        PortalUrl  = 'https://entra.microsoft.com/'
    }
    References  = @(
        @{ Title = 'Add and manage app credentials in Microsoft Entra ID'; Url = 'https://learn.microsoft.com/en-us/entra/identity-platform/how-to-add-credentials' }
        @{ Title = 'Security best practices for application properties'; Url = 'https://learn.microsoft.com/en-us/entra/identity-platform/security-best-practices-for-app-registration' }
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
        $valid = @(Get-ArgusAppCredential -Application @($Context.Data['Applications']) -Type Secret | Where-Object { $_.End -and $_.End -gt $Context.Now })
        $findings = @($valid | Where-Object { $_.End -le $window } | ForEach-Object {
                $credential = $_
                $replaced = [bool]($valid | Where-Object { $_.ObjectId -eq $credential.ObjectId -and $_.KeyId -ne $credential.KeyId -and $_.End -gt $window })
                [pscustomobject]@{
                    AppName        = $credential.AppName
                    AppId          = $credential.AppId
                    CredentialName = $credential.CredentialName
                    Expires        = Format-ArgusDate $credential.End
                    DaysLeft       = [int][math]::Floor(($credential.End - $Context.Now).TotalDays)
                    Replaced       = if ($replaced) { 'Yes' } else { 'No' }
                    KeyId          = $credential.KeyId
                    ObjectId       = $credential.ObjectId
                }
            } | Sort-Object DaysLeft)
        $open = @($findings | Where-Object Replaced -EQ 'No').Count
        if ($findings.Count -eq 0) {
            return New-ArgusResult -Status Passed -EvaluatedCount $valid.Count -Summary 'No client secret expires within {DaysAhead} days ({EvaluatedCount} valid secrets evaluated).'
        }
        $status = if ($open -gt 0) { 'Failed' } else { 'Passed' }
        New-ArgusResult -Status $status -Findings $findings -EvaluatedCount $valid.Count `
            -Summary ("{AffectedCount} of {EvaluatedCount} client secrets expire within {DaysAhead} days; $open without a replacement secret.")
    }
}
