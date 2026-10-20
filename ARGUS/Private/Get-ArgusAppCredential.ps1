function Get-ArgusAppCredential {
    <#
    .SYNOPSIS
        Flattens the client secrets or certificates of app registrations into one row per credential.

    .DESCRIPTION
        Reads passwordCredentials (Type Secret) or keyCredentials (Type Certificate) from the Applications
        data set. Only metadata is available from Graph (never secret values). Dates are UTC [datetime].
        For certificates, -Usage filters on keyCredential usage ('Verify' = used by the app to authenticate).
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]] $Application,

        [Parameter(Mandatory)]
        [ValidateSet('Secret', 'Certificate')]
        [string] $Type,

        [Parameter()]
        [string] $Usage
    )

    $property = if ($Type -eq 'Secret') { 'passwordCredentials' } else { 'keyCredentials' }
    foreach ($app in $Application) {
        if ($null -eq $app) { continue }
        foreach ($credential in @(Get-ArgusProperty $app $property @())) {
            if ($Usage -and [string](Get-ArgusProperty $credential 'usage' '') -ne $Usage) { continue }
            [pscustomobject]@{
                AppName        = [string](Get-ArgusProperty $app 'displayName' '')
                AppId          = [string](Get-ArgusProperty $app 'appId' '')
                ObjectId       = [string](Get-ArgusProperty $app 'id' '')
                Type           = $Type
                CredentialName = [string](Get-ArgusProperty $credential 'displayName' '')
                Hint           = [string](Get-ArgusProperty $credential 'hint' '')
                KeyId          = [string](Get-ArgusProperty $credential 'keyId' '')
                Start          = ConvertTo-ArgusUtcDate (Get-ArgusProperty $credential 'startDateTime')
                End            = ConvertTo-ArgusUtcDate (Get-ArgusProperty $credential 'endDateTime')
            }
        }
    }
}
