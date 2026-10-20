Register-ArgusCheck @{
    Id          = 'ARG.APP.003'
    Title       = 'Expired client secrets still present'
    Area        = 'Applications'
    Category    = 'Credential hygiene'
    Severity    = 'Low'
    Description = 'Client secrets (`passwordCredentials`) whose `endDateTime` is in the past but that are still attached to the app registration.'
    Rationale   = 'Expired secrets are clutter that hides which credentials are really in use and makes credential reviews harder.'
    Remediation = @{
        Steps      = "1. Confirm the expired secret is not referenced in any documentation or runbook as current.`n2. Delete the expired secret from the app registration (Certificates & secrets)."
        PowerShell = "# Sample only - review before running.`nConnect-MgGraph -Scopes 'Application.ReadWrite.All'`nRemove-MgApplicationPassword -ApplicationId '<ObjectId>' -KeyId '<KeyId>'"
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
        $all = @(Get-ArgusAppCredential -Application @($Context.Data['Applications']) -Type Secret)
        $findings = @($all | Where-Object { $_.End -and $_.End -le $Context.Now } | ForEach-Object {
                [pscustomobject]@{
                    AppName        = $_.AppName
                    AppId          = $_.AppId
                    CredentialName = $_.CredentialName
                    Expired        = Format-ArgusDate $_.End
                    DaysExpired    = [int][math]::Floor(($Context.Now - $_.End).TotalDays)
                    KeyId          = $_.KeyId
                    ObjectId       = $_.ObjectId
                }
            } | Sort-Object DaysExpired -Descending)
        $apps = @($findings | Select-Object -ExpandProperty AppId -Unique).Count
        $status = if ($findings.Count -gt 0) { 'Failed' } else { 'Passed' }
        New-ArgusResult -Status $status -Findings $findings -EvaluatedCount $all.Count `
            -Summary ("{AffectedCount} of {EvaluatedCount} client secrets are expired but still present on $apps app registration" + $(if ($apps -eq 1) { '' } else { 's' }) + '.')
    }
}
