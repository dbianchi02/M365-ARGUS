function Merge-ArgusHashtable {
    <#
    .SYNOPSIS
        Deep-merges an override dictionary over a base dictionary.

    .DESCRIPTION
        Returns a new case-insensitive hashtable; inputs are not modified.
        Nested dictionaries are merged key by key. Any other value in the override (scalars, arrays, null)
        replaces the base value: arrays are replaced, never concatenated, so a user config can clear a list.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        [System.Collections.IDictionary] $Base,

        [Parameter(Mandatory)]
        [AllowNull()]
        [System.Collections.IDictionary] $Override
    )

    $copy = {
        param($Value)
        if ($Value -is [System.Collections.IDictionary]) {
            $result = @{}
            foreach ($key in $Value.Keys) { $result[$key] = & $copy $Value[$key] }
            return $result
        }
        if ($Value -is [System.Collections.IList]) {
            return , @(foreach ($item in $Value) { & $copy $item })
        }
        return $Value
    }

    $merged = if ($null -eq $Base) { @{} } else { & $copy $Base }
    if ($null -eq $Override) { return $merged }

    foreach ($key in $Override.Keys) {
        $value = $Override[$key]
        if ($value -is [System.Collections.IDictionary] -and $merged[$key] -is [System.Collections.IDictionary]) {
            $merged[$key] = Merge-ArgusHashtable -Base $merged[$key] -Override $value
        }
        else {
            $merged[$key] = & $copy $value
        }
    }
    $merged
}
