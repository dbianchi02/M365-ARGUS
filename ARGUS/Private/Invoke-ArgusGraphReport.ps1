function Invoke-ArgusGraphReport {
    <#
    .SYNOPSIS
        Downloads a Microsoft 365 usage report (v1.0, CSV) and returns its rows as objects.

    .DESCRIPTION
        v1.0 report functions such as getTeamsTeamActivityDetail(period='D180') answer with a 302
        redirect to a short-lived CSV download. The CSV is saved to a temporary file, parsed with
        Import-Csv and the file is deleted immediately (it contains tenant data).
        Column names are the CSV headers (for example 'Team Id', 'Last Activity Date').
        Requires Reports.Read.All and, for delegated access, a reports-capable role (Reports Reader,
        or an admin role); Global Reader only sees tenant-level totals.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [ValidatePattern('^get[A-Za-z0-9]+$')]
        [string] $Name,

        [Parameter()]
        [ValidateSet('D7', 'D30', 'D90', 'D180')]
        [string] $Period = 'D180',

        # Report root: 'reports' (Microsoft 365 usage) or 'copilot/reports' (Microsoft 365 Copilot usage, CSV in v1.0).
        [Parameter()]
        [ValidateSet('reports', 'copilot/reports')]
        [string] $Root = 'reports'
    )

    $file = Join-Path ([System.IO.Path]::GetTempPath()) ('argus-report-{0}.csv' -f [guid]::NewGuid().ToString('N'))
    try {
        Invoke-ArgusGraphRequest -Uri "/$Root/$Name(period='$Period')" -OutputFilePath $file
        if (Test-Path -LiteralPath $file) {
            Import-Csv -LiteralPath $file
        }
    }
    finally {
        Remove-Item -LiteralPath $file -Force -ErrorAction SilentlyContinue
    }
}
