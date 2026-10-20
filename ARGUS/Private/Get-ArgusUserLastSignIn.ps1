function Get-ArgusUserLastSignIn {
    <#
    .SYNOPSIS
        Returns the last sign-in of a user (UTC) from signInActivity, or $null if it never signed in.

    .DESCRIPTION
        Uses lastSuccessfulSignInDateTime (interactive or non-interactive, populated since December 2023).
        When it is empty, falls back to the most recent of lastSignInDateTime and
        lastNonInteractiveSignInDateTime, which also cover older activity (they record attempts).
    #>
    [CmdletBinding()]
    [OutputType([datetime])]
    param(
        [Parameter(Mandatory)]
        [object] $User
    )

    $successful = ConvertTo-ArgusUtcDate (Get-ArgusProperty $User 'signInActivity.lastSuccessfulSignInDateTime')
    if ($successful) { return $successful }

    $candidates = @(
        ConvertTo-ArgusUtcDate (Get-ArgusProperty $User 'signInActivity.lastSignInDateTime')
        ConvertTo-ArgusUtcDate (Get-ArgusProperty $User 'signInActivity.lastNonInteractiveSignInDateTime')
    ) | Where-Object { $_ }
    if (@($candidates).Count -eq 0) { return $null }
    @($candidates | Sort-Object -Descending)[0]
}
