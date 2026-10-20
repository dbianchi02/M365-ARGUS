function Get-ArgusProperty {
    <#
    .SYNOPSIS
        Reads a (nested) property from a Graph object, returning $Default when any part is missing.

    .DESCRIPTION
        Graph responses omit properties that were not selected, and strict mode throws on missing
        properties. Use a dotted path for nested values, e.g. 'signInActivity.lastSuccessfulSignInDateTime'.
        Collection values are enumerated: use @(Get-ArgusProperty $x 'items' @()) to always get an array.
    #>
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [AllowNull()]
        [object] $InputObject,

        [Parameter(Mandatory, Position = 1)]
        [string] $Name,

        [Parameter(Position = 2)]
        [AllowNull()]
        [object] $Default = $null
    )

    # A property whose name itself contains a dot (e.g. '@odata.type') wins over path navigation.
    if ($null -ne $InputObject -and $InputObject -isnot [System.Collections.IDictionary] -and $InputObject.PSObject.Properties[$Name]) {
        $value = $InputObject.PSObject.Properties[$Name].Value
        if ($null -eq $value) { return $Default }
        return $value
    }

    $current = $InputObject
    foreach ($part in $Name.Split('.')) {
        if ($null -eq $current) { return $Default }
        if ($current -is [System.Collections.IDictionary]) {
            if (-not $current.Contains($part)) { return $Default }
            $current = $current[$part]
            continue
        }
        $property = $current.PSObject.Properties[$part]
        if ($null -eq $property) { return $Default }
        $current = $property.Value
    }
    if ($null -eq $current) { return $Default }
    # Arrays are enumerated like any PowerShell output: wrap the call in @() to get a collection.
    $current
}
