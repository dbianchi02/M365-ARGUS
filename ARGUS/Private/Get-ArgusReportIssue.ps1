function Get-ArgusReportIssue {
    <#
    .SYNOPSIS
        Returns why a Microsoft 365 usage report cannot be evaluated per object, or $null when it can.

    .DESCRIPTION
        Concealed names (admin/reportSettings.displayConcealedNames = true) replace names, UPNs and
        URLs with hashes. An empty report usually means the delegated account only sees tenant totals
        (Global Reader) and needs Reports Reader. Report checks return Investigate with this text.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter()]
        [AllowNull()]
        [object] $ReportSettings,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]] $Row,

        [Parameter(Mandatory)]
        [string] $ObjectName
    )

    if ((Get-ArgusProperty $ReportSettings 'displayConcealedNames' $false) -eq $true) {
        return "Usage reports return concealed names (admin/reportSettings.displayConcealedNames = true), so $ObjectName cannot be identified. Turn the setting off in the Microsoft 365 admin center (Settings > Org settings > Reports) to evaluate this check."
    }
    if (@($Row | Where-Object { $_ }).Count -eq 0) {
        return "The usage report returned no rows. With delegated sign-in the account needs the Reports Reader role (Global Reader only sees tenant totals), or the tenant has no $ObjectName."
    }
    $null
}
