function Export-ArgusFindingCsv {
    <#
    .SYNOPSIS
        Writes the findings of one check result to a CSV file and returns the file.

    .DESCRIPTION
        Columns follow FindingColumns. Values starting with =, +, -, @, tab or carriage return are
        prefixed with a single quote, so tenant-controlled strings (display names, titles) can't be
        interpreted as formulas when the CSV is opened in a spreadsheet application.
    #>
    [CmdletBinding()]
    [OutputType([System.IO.FileInfo])]
    param(
        [Parameter(Mandatory)]
        [pscustomobject] $Result,

        [Parameter(Mandatory)]
        [string] $Path
    )

    $columns = @($Result.FindingColumns)
    if ($columns.Count -eq 0 -and @($Result.Findings).Count -gt 0) {
        $columns = @(@($Result.Findings)[0].PSObject.Properties.Name)
    }

    $rows = foreach ($finding in $Result.Findings) {
        $row = [ordered]@{}
        foreach ($column in $columns) {
            $property = $finding.PSObject.Properties[$column]
            $value = if ($null -eq $property -or $null -eq $property.Value) { '' }
            elseif ($property.Value -is [datetime]) { $property.Value.ToString('o') }
            elseif ($property.Value -is [System.Collections.IEnumerable] -and $property.Value -isnot [string]) { (@($property.Value) -join '; ') }
            else { [string]$property.Value }
            if ($value -match '^[=+\-@\t\r]') { $value = "'$value" }
            $row[$column] = $value
        }
        [pscustomobject]$row
    }

    $fullPath = [System.IO.Path]::GetFullPath($Path, (Get-Location).ProviderPath)
    @($rows) | Export-Csv -LiteralPath $fullPath -NoTypeInformation -Encoding utf8BOM
    Get-Item -LiteralPath $fullPath
}
