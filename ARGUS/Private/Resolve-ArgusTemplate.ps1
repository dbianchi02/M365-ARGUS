function Resolve-ArgusTemplate {
    <#
    .SYNOPSIS
        Replaces {Name} placeholders in a check title or summary.

    .DESCRIPTION
        Integers and decimals are formatted with thousands separators (invariant culture, e.g. 1,204).
        Placeholders without a value are left unchanged.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'Values', Justification = 'Used inside the regex MatchEvaluator scriptblock.')]
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [AllowNull()]
        [string] $Template,

        [Parameter(Mandatory)]
        [System.Collections.IDictionary] $Values
    )

    if ([string]::IsNullOrEmpty($Template)) { return $Template }

    [regex]::Replace($Template, '\{(\w+)\}', {
            param($match)
            $name = $match.Groups[1].Value
            $key = @($Values.Keys | Where-Object { $_ -eq $name }) | Select-Object -First 1
            if ($null -eq $key) { return $match.Value }
            $value = $Values[$key]
            if ($value -is [int] -or $value -is [long] -or $value -is [short] -or $value -is [byte]) {
                return ([long]$value).ToString('N0', [cultureinfo]::InvariantCulture)
            }
            if ($value -is [double] -or $value -is [decimal] -or $value -is [single]) {
                return ([decimal]$value).ToString('#,0.##', [cultureinfo]::InvariantCulture)
            }
            return [string]$value
        })
}
