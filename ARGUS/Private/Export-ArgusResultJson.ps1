function Export-ArgusResultJson {
    <#
    .SYNOPSIS
        Writes the results document to a UTF-8 (no BOM) JSON file and returns the file.
    #>
    [CmdletBinding()]
    [OutputType([System.IO.FileInfo])]
    param(
        [Parameter(Mandatory)]
        [pscustomobject] $Document,

        [Parameter(Mandatory)]
        [string] $Path
    )

    $json = $Document | ConvertTo-Json -Depth 10
    $fullPath = [System.IO.Path]::GetFullPath($Path, (Get-Location).ProviderPath)
    [System.IO.File]::WriteAllText($fullPath, $json, [System.Text.UTF8Encoding]::new($false))
    Get-Item -LiteralPath $fullPath
}
