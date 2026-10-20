function Test-ArgusSignInActivity {
    <#
    .SYNOPSIS
        Returns $true when the Users data set was loaded with signInActivity.

    .DESCRIPTION
        Uses the note recorded by the Users loader; without a note (e.g. data provided directly),
        checks whether the user objects carry a signInActivity property.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]] $User
    )

    $note = $script:ArgusDataSetNotes['Users']
    if ($note) { return $note -eq 'signInActivity included.' }
    if ($User.Count -eq 0) { return $true }
    [bool]($User | Where-Object { $_ -and $_.PSObject.Properties['signInActivity'] } | Select-Object -First 1)
}
