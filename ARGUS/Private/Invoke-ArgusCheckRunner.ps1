function Invoke-ArgusCheckRunner {
    <#
    .SYNOPSIS
        Runs a set of check definitions and returns one result record per check.

    .DESCRIPTION
        For each check, in order:
        1. filters (-Area, -Id, -Tag, -ExcludeId) and config 'Enabled' -> NotRun with the reason;
        2. Requires (services, scopes, licences) -> Skipped with the reason, before execution;
        3. data sets of the remaining checks are prefetched once (Get-ArgusData); a check whose data set
           failed to load -> Error;
        4. the Test scriptblock runs isolated in try/catch -> Error with the message on exception;
        5. global exclusions are removed from the findings (unless ApplyExclusions = $false), counts are
           adjusted, and placeholders in Title / Summary are resolved.
        Checks run sequentially (v0.1).
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]] $Check,

        [Parameter(Mandatory)]
        [System.Collections.IDictionary] $Config,

        [Parameter(Mandatory)]
        [pscustomobject] $Environment,

        [Parameter()]
        [string[]] $Area,

        [Parameter()]
        [string[]] $Id,

        [Parameter()]
        [string[]] $ExcludeId,

        [Parameter()]
        [string[]] $Tag,

        [Parameter()]
        [datetime] $Now = [datetime]::UtcNow
    )

    $matchesAny = { param($Value, $Patterns) [bool]($Patterns | Where-Object { $Value -like $_ }) }

    $knownIds = @($Check | ForEach-Object { $_.Id })
    foreach ($configuredId in $Config.Checks.Keys) {
        if ($configuredId -notin $knownIds) {
            Write-Warning "Configuration contains settings for unknown check '$configuredId'; they are ignored."
        }
    }

    # 1-2. Selection and prerequisites
    $plan = foreach ($definition in $Check) {
        $setting = Resolve-ArgusCheckSetting -Check $definition -Config $Config
        $notRunReason = if ($Area -and $definition.Area -notin $Area) { 'Not selected by the -Area filter.' }
        elseif ($Id -and -not (& $matchesAny $definition.Id $Id)) { 'Not selected by the -Id filter.' }
        elseif ($Tag -and -not ($definition.Tags | Where-Object { $_ -in $Tag })) { 'Not selected by the -Tag filter.' }
        elseif ($ExcludeId -and (& $matchesAny $definition.Id $ExcludeId)) { 'Excluded with -ExcludeId.' }
        elseif (-not $setting.Enabled) { 'Disabled in configuration.' }

        [string[]] $skipReasons = @()
        if (-not $notRunReason) { $skipReasons = @(Test-ArgusRequirement -Check $definition -Environment $Environment) }
        [pscustomobject]@{ Check = $definition; Setting = $setting; NotRunReason = $notRunReason; SkipReasons = $skipReasons }
    }
    $plan = @($plan)
    $runnable = @($plan | Where-Object { -not $_.NotRunReason -and $_.SkipReasons.Count -eq 0 })

    # 3. Prefetch data sets once
    $data = @{}
    $dataErrors = @{}
    $dataSetNames = @($runnable | ForEach-Object { $_.Check.Requires.DataSets } | Where-Object { $_ } | Sort-Object -Unique)
    for ($i = 0; $i -lt $dataSetNames.Count; $i++) {
        $name = $dataSetNames[$i]
        Write-Progress -Id 1 -Activity 'ARGUS: loading tenant data' -Status $name -PercentComplete (100 * $i / $dataSetNames.Count)
        try {
            $data[$name] = Get-ArgusData -Name $name -ErrorAction Stop
        }
        catch {
            $dataErrors[$name] = $_.Exception.Message
        }
    }
    Write-Progress -Id 1 -Activity 'ARGUS: loading tenant data' -Completed

    # Optional data sets: loaded only when their service is connected; a failure is a note, not an error.
    $serviceOf = @{}
    foreach ($dataSet in Get-ArgusDataSetDefinition) { $serviceOf[$dataSet.Name] = $dataSet.Service }
    $optionalNames = @($runnable | ForEach-Object { $_.Check.Requires.OptionalDataSets } | Where-Object { $_ -and -not $data.ContainsKey($_) } | Sort-Object -Unique)
    foreach ($name in $optionalNames) {
        $service = $serviceOf[$name]
        if ($service -and $service -notin @($Environment.ConnectedServices)) { continue }
        try {
            $data[$name] = Get-ArgusData -Name $name -ErrorAction Stop
        }
        catch {
            Add-ArgusDataSetNote -Name $name -Text "Optional data set not loaded: $($_.Exception.Message)"
        }
    }

    $hasExclusions = [bool]($Config.Exclusions.Values | ForEach-Object { $_ } | Where-Object { $_ })

    # 4-5. Execute
    for ($i = 0; $i -lt $plan.Count; $i++) {
        $item = $plan[$i]
        $definition = $item.Check
        $parameters = $item.Setting.Parameters
        Write-Progress -Id 2 -Activity 'ARGUS: running checks' -Status "$($definition.Id) $($definition.Title)" -PercentComplete (100 * $i / [math]::Max(1, $plan.Count))

        $result = $null
        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        $failedDataSets = @($definition.Requires.DataSets | Where-Object { $dataErrors.ContainsKey($_) })

        if ($item.NotRunReason) {
            $result = New-ArgusResult -Status NotRun -SkipReason $item.NotRunReason
        }
        elseif ($item.SkipReasons.Count -gt 0) {
            $result = New-ArgusResult -Status Skipped -SkipReason (($item.SkipReasons -join '; ') + '.')
        }
        elseif ($failedDataSets.Count -gt 0) {
            $messages = $failedDataSets | ForEach-Object { "Data set '$_' could not be loaded: $($dataErrors[$_])" }
            $result = New-ArgusResult -Status Error -ErrorMessage ($messages -join ' ')
        }
        else {
            $checkData = @{}
            foreach ($name in $definition.Requires.DataSets) { $checkData[$name] = $data[$name] }
            foreach ($name in $definition.Requires.OptionalDataSets) { if ($data.ContainsKey($name)) { $checkData[$name] = $data[$name] } }
            $context = [pscustomobject]@{
                CheckId     = $definition.Id
                Config      = $Config
                Data        = $checkData
                Parameters  = $parameters.Clone()
                Now         = $Now
                Environment = $Environment
            }
            $previousPreference = $ErrorActionPreference
            try {
                # Non-terminating errors inside a check become terminating, so they surface as Error.
                $ErrorActionPreference = 'Stop'
                $output = @(& $definition.Test $context)
                $returned = @($output | Where-Object { $null -ne $_ -and $_.PSObject.TypeNames -contains 'Argus.Result' })
                if ($returned.Count -ne 1) {
                    throw "The check must return exactly one result created with New-ArgusResult (returned $($returned.Count))."
                }
                $result = $returned[0]
            }
            catch {
                $result = New-ArgusResult -Status Error -ErrorMessage $_.Exception.Message
            }
            finally {
                $ErrorActionPreference = $previousPreference
            }
        }
        $stopwatch.Stop()

        # Global exclusions
        $excludedCount = 0
        if ($hasExclusions -and $definition.ApplyExclusions -and @($result.Findings).Count -gt 0) {
            $kept = @($result.Findings | Where-Object { -not (Test-ArgusExcluded -InputObject $_ -Exclusions $Config.Exclusions) })
            $excludedCount = @($result.Findings).Count - $kept.Count
            if ($excludedCount -gt 0) {
                $result.Findings = $kept
                $result.AffectedCount = [math]::Max(0, $result.AffectedCount - $excludedCount)
                if ($null -ne $result.EvaluatedCount) {
                    $result.EvaluatedCount = [math]::Max(0, $result.EvaluatedCount - $excludedCount)
                }
                if ($result.Status -in 'Failed', 'Investigate' -and $kept.Count -eq 0 -and $result.AffectedCount -eq 0) {
                    $result.Status = 'Passed'
                }
            }
        }

        $values = @{}
        foreach ($key in $parameters.Keys) { $values[$key] = $parameters[$key] }
        $values['AffectedCount'] = $result.AffectedCount
        $values['EvaluatedCount'] = $result.EvaluatedCount
        $values['ExcludedCount'] = $excludedCount

        $summary = Resolve-ArgusTemplate -Template $result.Summary -Values $values
        if ($excludedCount -gt 0 -and $result.Summary -notmatch '\{ExcludedCount\}') {
            $summary = ("$summary " + (Resolve-ArgusTemplate -Template '{ExcludedCount} object(s) excluded by configuration.' -Values $values)).Trim()
        }

        [pscustomobject]@{
            PSTypeName      = 'Argus.CheckResult'
            Id              = $definition.Id
            Title           = Resolve-ArgusTemplate -Template $definition.Title -Values $parameters
            Area            = $definition.Area
            AreaDisplayName = $script:ArgusAreas[$definition.Area].DisplayName
            Category        = $definition.Category
            Severity        = $item.Setting.Severity
            Status          = $result.Status
            Summary         = $summary
            AffectedCount   = $result.AffectedCount
            EvaluatedCount  = $result.EvaluatedCount
            ExcludedCount   = $excludedCount
            Findings        = @($result.Findings)
            FindingColumns  = @($result.FindingColumns)
            SkipReason      = $result.SkipReason
            ErrorMessage    = $result.ErrorMessage
            Duration        = [math]::Round($stopwatch.Elapsed.TotalSeconds, 3)
            Parameters      = $parameters
            Description     = Resolve-ArgusTemplate -Template $definition.Description -Values $parameters
            Rationale       = $definition.Rationale
            Remediation     = $definition.Remediation
            References      = @($definition.References)
            Requires        = $definition.Requires
            Tags            = @($definition.Tags)
            UsesBeta        = $definition.UsesBeta
            IsCustom        = -not ($definition.Source -and $definition.Source.StartsWith($script:ArgusModuleRoot, [System.StringComparison]::OrdinalIgnoreCase))
        }
    }
    Write-Progress -Id 2 -Activity 'ARGUS: running checks' -Completed
}
