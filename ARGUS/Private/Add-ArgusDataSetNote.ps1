function Add-ArgusDataSetNote {
    <#
    .SYNOPSIS
        Records a note about how a data set was loaded (for example "signInActivity not available").
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory)]
        [string] $Name,

        [Parameter(Mandatory)]
        [string] $Text
    )

    $script:ArgusDataSetNotes[$Name] = $Text
    Write-Verbose "$Name`: $Text"
}
