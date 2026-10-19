function New-ArgusResult {
    <#
    .SYNOPSIS
        Builds the result object returned by a check's Test scriptblock.

    .DESCRIPTION
        Status is one of Passed, Failed, Investigate, Skipped, Error, NotRun.
        Skipped requires -SkipReason, Error requires -ErrorMessage.

        Summary may contain placeholders resolved by the runner after global exclusions are applied:
        {AffectedCount}, {EvaluatedCount}, {ExcludedCount} and any check parameter (for example {InactiveDays}).
        Numbers are formatted with thousands separators.

        Findings must be flat objects with the same properties; FindingColumns sets the column order
        (defaults to the properties of the first finding). AffectedCount defaults to the number of findings.
        Duration is set by the runner.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Pure object constructor, changes no state.')]
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Passed', 'Failed', 'Investigate', 'Skipped', 'Error', 'NotRun')]
        [string] $Status,

        [Parameter()]
        [AllowEmptyString()]
        [string] $Summary = '',

        [Parameter()]
        [Nullable[int]] $AffectedCount,

        [Parameter()]
        [Nullable[int]] $EvaluatedCount,

        [Parameter()]
        [AllowNull()]
        [AllowEmptyCollection()]
        [object[]] $Findings = @(),

        [Parameter()]
        [string[]] $FindingColumns,

        [Parameter()]
        [string] $SkipReason,

        [Parameter()]
        [string] $ErrorMessage
    )

    if ($Status -eq 'Skipped' -and [string]::IsNullOrWhiteSpace($SkipReason)) {
        throw 'New-ArgusResult: a Skipped result requires -SkipReason.'
    }
    if ($Status -eq 'Error' -and [string]::IsNullOrWhiteSpace($ErrorMessage)) {
        throw 'New-ArgusResult: an Error result requires -ErrorMessage.'
    }

    $rows = @($Findings | Where-Object { $null -ne $_ })
    if (-not $FindingColumns -and $rows.Count -gt 0) {
        $FindingColumns = @($rows[0].PSObject.Properties.Name)
    }

    [pscustomobject]@{
        PSTypeName     = 'Argus.Result'
        Status         = $Status
        Summary        = $Summary
        AffectedCount  = if ($null -ne $AffectedCount) { $AffectedCount } else { $rows.Count }
        EvaluatedCount = if ($null -ne $EvaluatedCount) { $EvaluatedCount } else { $null }
        Findings       = $rows
        FindingColumns = [string[]]@($FindingColumns | Where-Object { $_ })
        SkipReason     = if ($SkipReason) { $SkipReason } else { $null }
        ErrorMessage   = if ($ErrorMessage) { $ErrorMessage } else { $null }
        Duration       = 0.0
    }
}
