function Get-ArgusMailboxSize {
    <#
    .SYNOPSIS
        Returns the primary mailbox size in GB (Get-EXOMailboxStatistics TotalItemSize), or $null when unknown.

    .DESCRIPTION
        Exchange Online returns TotalItemSize as text such as "1.2 GB (1,288,490,189 bytes)" when the
        value is deserialised, so the byte count in brackets is parsed. Read-only.
    #>
    [CmdletBinding()]
    [OutputType([double])]
    param(
        [Parameter(Mandatory)]
        [string] $Identity
    )

    try {
        $statistics = Get-EXOMailboxStatistics -Identity $Identity -ErrorAction Stop
    }
    catch {
        Write-Verbose "Mailbox statistics not available for ${Identity}: $($_.Exception.Message)"
        return $null
    }
    $text = [string](Get-ArgusProperty $statistics 'TotalItemSize' '')
    $match = [regex]::Match($text, '\(([\d,.\s]+)\s*bytes\)')
    if (-not $match.Success) { return $null }
    $bytes = [double]($match.Groups[1].Value -replace '[^\d]', '')
    [math]::Round($bytes / 1GB, 1)
}
