Register-ArgusCheck @{
    Id          = 'ARG.APP.004'
    Title       = 'Client secrets with a lifetime above {MaxLifetimeMonths} months'
    Area        = 'Applications'
    Category    = 'Credential hygiene'
    Severity    = 'Low'
    Description = 'Valid client secrets whose lifetime (`endDateTime` minus `startDateTime`) exceeds **{MaxLifetimeMonths}** months. The admin center limits new secrets to 24 months, but secrets created through the API or before that limit can last much longer. Expired secrets are covered by ARG.APP.003.'
    Rationale   = 'Long-lived secrets are rarely rotated and outlive the people and documentation that explain them. Microsoft recommends less than 12 months, or certificates and managed identities instead.'
    Remediation = @{
        Steps      = "1. Replace the secret with a certificate or a managed identity where possible; otherwise create a secret with a shorter lifetime.`n2. Update the service that uses it, then delete the long-lived secret.`n3. Consider an application management policy that limits secret lifetime for new credentials."
        PowerShell = "# Sample only - review before running. Adds a 6-month secret; store the returned value securely.`nConnect-MgGraph -Scopes 'Application.ReadWrite.All'`nAdd-MgApplicationPassword -ApplicationId '<ObjectId>' -PasswordCredential @{ DisplayName = 'rotated'; EndDateTime = (Get-Date).AddMonths(6) }"
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
    Parameters  = @{ MaxLifetimeMonths = 24 }
    Tags        = @('Applications', 'Credentials')
    Test        = {
        param($Context)
        $maxDays = [double]$Context.Parameters.MaxLifetimeMonths * 30.44
        $valid = @(Get-ArgusAppCredential -Application @($Context.Data['Applications']) -Type Secret | Where-Object { $_.End -and $_.End -gt $Context.Now })
        $findings = @($valid | Where-Object { $_.Start -and ($_.End - $_.Start).TotalDays -gt ($maxDays + 1) } | ForEach-Object {
                [pscustomobject]@{
                    AppName        = $_.AppName
                    AppId          = $_.AppId
                    CredentialName = $_.CredentialName
                    Created        = Format-ArgusDate $_.Start
                    Expires        = Format-ArgusDate $_.End
                    LifetimeMonths = [int][math]::Round(($_.End - $_.Start).TotalDays / 30.44)
                    KeyId          = $_.KeyId
                    ObjectId       = $_.ObjectId
                }
            } | Sort-Object LifetimeMonths -Descending)
        $status = if ($findings.Count -gt 0) { 'Failed' } else { 'Passed' }
        New-ArgusResult -Status $status -Findings $findings -EvaluatedCount $valid.Count `
            -Summary '{AffectedCount} of {EvaluatedCount} valid client secrets have a lifetime longer than {MaxLifetimeMonths} months.'
    }
}
