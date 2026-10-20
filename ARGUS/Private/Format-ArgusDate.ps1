function Format-ArgusDate {
    <#
    .SYNOPSIS
        Formats a date for findings tables ('yyyy-MM-dd', UTC), or returns $Empty for no value.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [AllowNull()]
        [AllowEmptyString()]
        [object] $Value,

        [Parameter(Position = 1)]
        [string] $Empty = ''
    )

    $date = ConvertTo-ArgusUtcDate $Value
    if ($null -eq $date) { return $Empty }
    $date.ToString('yyyy-MM-dd', [cultureinfo]::InvariantCulture)
}
