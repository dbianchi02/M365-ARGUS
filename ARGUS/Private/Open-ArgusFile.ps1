function Open-ArgusFile {
    <#
    .SYNOPSIS
        Opens a local file with the default application (browser for .html) on Windows, macOS or Linux.

    .DESCRIPTION
        Failures are reported as a warning: opening the report is a convenience and must never fail a run.
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory)]
        [string] $Path
    )

    try {
        if ($IsWindows) {
            Start-Process -FilePath $Path
        }
        elseif ($IsMacOS) {
            Start-Process -FilePath 'open' -ArgumentList @($Path)
        }
        elseif (Get-Command -Name 'xdg-open' -CommandType Application -ErrorAction SilentlyContinue) {
            Start-Process -FilePath 'xdg-open' -ArgumentList @($Path)
        }
        else {
            Write-Warning "No default browser launcher found. Open the report manually: $Path"
        }
    }
    catch {
        Write-Warning "Could not open '$Path': $($_.Exception.Message)"
    }
}
