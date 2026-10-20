function Write-ArgusBanner {
    <#
    .SYNOPSIS
        Prints the ARGUS start banner: ASCII wordmark, version (Preview for prerelease builds), author and copyright.
    .DESCRIPTION
        Version, author and copyright come from the module manifest, so the banner follows every release.
        Pure ASCII, so it renders the same in every console on Windows, macOS and Linux.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Console banner is the documented exception to the no Write-Host rule.')]
    [CmdletBinding()]
    [OutputType([void])]
    param()

    $wordmark = @(
        '     _    ____   ____ _   _ ____  '
        '    / \  |  _ \ / ___| | | / ___| '
        '   / _ \ | |_) | |  _| | | \___ \ '
        '  / ___ \|  _ <| |_| | |_| |___) |'
        ' /_/   \_\_| \_\\____|\___/|____/ '
    )
    $manifest = $script:ArgusManifest
    $preview = [bool]$manifest.PrivateData.PSData.Prerelease

    Write-Host ''
    foreach ($line in $wordmark) { Write-Host $line -ForegroundColor Cyan }
    Write-Host '  Automated Report & Governance Utility Suite' -ForegroundColor Gray
    Write-Host ''
    Write-Host "  Version  $script:ArgusVersion" -NoNewline
    if ($preview) { Write-Host '  [Preview]' -ForegroundColor DarkYellow } else { Write-Host '' }
    Write-Host "  Author   $($manifest.Author)"
    Write-Host "  $($manifest.Copyright)" -ForegroundColor Gray
    Write-Host '  Read-only governance assessment. Free to use, modify and distribute under the MIT License;' -ForegroundColor DarkGray
    Write-Host '  provided "as is", without warranty of any kind. Review findings before acting on them.' -ForegroundColor DarkGray
    Write-Host ''
}
