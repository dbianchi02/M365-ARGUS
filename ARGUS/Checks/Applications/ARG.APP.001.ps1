Register-ArgusCheck @{
    Id          = 'ARG.APP.001'
    Title       = 'App registrations without owners'
    Area        = 'Applications'
    Category    = 'Application governance'
    Severity    = 'Medium'
    Description = 'App registrations with no owner. The findings show how many secrets and certificates each app holds: an ownerless app with credentials is the first to review.'
    Rationale   = 'Without an owner nobody is accountable for the app''s permissions, credentials and lifecycle, and nobody notices when it is no longer needed.'
    Remediation = @{
        Steps      = "1. Identify who uses the application (sign-in logs, credentials, API permissions help).`n2. Assign at least one owner (two is better) in App registrations > Owners.`n3. Delete applications that nobody claims after a grace period."
        PowerShell = "# Sample only - review before running. Adds an owner to one app registration.`nConnect-MgGraph -Scopes 'Application.ReadWrite.All'`nNew-MgApplicationOwnerByRef -ApplicationId '<ObjectId>' -BodyParameter @{ '@odata.id' = 'https://graph.microsoft.com/v1.0/directoryObjects/<OwnerObjectId>' }"
        PortalUrl  = 'https://entra.microsoft.com/'
    }
    References  = @(
        @{ Title = 'Security best practices for application properties (app ownership)'; Url = 'https://learn.microsoft.com/en-us/entra/identity-platform/security-best-practices-for-app-registration' }
        @{ Title = 'Assign enterprise application owners'; Url = 'https://learn.microsoft.com/en-us/entra/identity/enterprise-apps/assign-app-owners' }
    )
    Requires    = @{
        Services    = @('Graph')
        GraphScopes = @('Application.Read.All')
        DataSets    = @('Applications')
    }
    Tags        = @('Applications', 'Ownership')
    Test        = {
        param($Context)
        $apps = @($Context.Data['Applications'] | Where-Object { $_ })
        $findings = @($apps | Where-Object { [int](Get-ArgusProperty $_ 'OwnerCount' 0) -eq 0 } | ForEach-Object {
                [pscustomobject]@{
                    AppName        = Get-ArgusProperty $_ 'displayName' ''
                    AppId          = Get-ArgusProperty $_ 'appId' ''
                    Created        = Format-ArgusDate (Get-ArgusProperty $_ 'createdDateTime')
                    SignInAudience = Get-ArgusProperty $_ 'signInAudience' ''
                    Secrets        = @(Get-ArgusProperty $_ 'passwordCredentials' @()).Count
                    Certificates   = @(Get-ArgusProperty $_ 'keyCredentials' @()).Count
                    ObjectId       = Get-ArgusProperty $_ 'id' ''
                }
            } | Sort-Object @{ Expression = { $_.Secrets + $_.Certificates }; Descending = $true }, AppName)
        $status = if ($findings.Count -gt 0) { 'Failed' } else { 'Passed' }
        New-ArgusResult -Status $status -Findings $findings -EvaluatedCount $apps.Count `
            -Summary '{AffectedCount} of {EvaluatedCount} app registrations have no owner.'
    }
}
