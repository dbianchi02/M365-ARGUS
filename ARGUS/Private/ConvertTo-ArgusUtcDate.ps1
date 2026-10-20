function ConvertTo-ArgusUtcDate {
    <#
    .SYNOPSIS
        Converts a Graph/Exchange/CSV date value to a UTC [datetime], or $null when empty or invalid.

    .DESCRIPTION
        Handles [datetime] (any Kind), [datetimeoffset] and ISO 8601 / 'yyyy-MM-dd' strings, so checks
        do not depend on how a response was deserialised.
    #>
    [CmdletBinding()]
    [OutputType([datetime])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [AllowNull()]
        [AllowEmptyString()]
        [object] $Value
    )

    if ($null -eq $Value) { return $null }
    if ($Value -is [datetime]) {
        if ($Value.Kind -eq [System.DateTimeKind]::Unspecified) { return [datetime]::SpecifyKind($Value, [System.DateTimeKind]::Utc) }
        return $Value.ToUniversalTime()
    }
    if ($Value -is [datetimeoffset]) { return $Value.UtcDateTime }

    $text = ([string]$Value).Trim()
    if (-not $text) { return $null }
    $parsed = [datetimeoffset]::MinValue
    $styles = [System.Globalization.DateTimeStyles]::AssumeUniversal -bor [System.Globalization.DateTimeStyles]::AllowWhiteSpaces
    if ([datetimeoffset]::TryParse($text, [cultureinfo]::InvariantCulture, $styles, [ref]$parsed)) {
        return $parsed.UtcDateTime
    }
    $null
}
