function Import-ArgusCheck {
    <#
    .SYNOPSIS
        Discovers and registers the check files found under one or more folders.

    .DESCRIPTION
        Dot-sources every ARG.*.ps1 file found recursively under -Path. Each file is expected to call
        Register-ArgusCheck once. Returns the registered check definitions sorted by area order and Id.

        A file that fails validation, registers nothing, or reuses an Id already registered (in this call
        or in -ExistingId) produces a non-terminating error and is skipped; the other files still load.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [string[]] $Path,

        [Parameter()]
        [string[]] $ExistingId = @()
    )

    $checks = [System.Collections.Generic.List[object]]::new()
    $seen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($id in $ExistingId) { $null = $seen.Add($id) }

    foreach ($folder in $Path) {
        if (-not (Test-Path -LiteralPath $folder -PathType Container)) {
            Write-Error -Message "Check folder '$folder' does not exist." -Category ObjectNotFound -TargetObject $folder
            continue
        }

        $files = Get-ChildItem -LiteralPath $folder -Filter 'ARG.*.ps1' -File -Recurse | Sort-Object FullName
        foreach ($file in $files) {
            $previousTarget = $script:ArgusRegistrationTarget
            $script:ArgusRegistrationTarget = [System.Collections.Generic.List[object]]::new()
            try {
                $null = . $file.FullName
                $registered = @($script:ArgusRegistrationTarget)
            }
            catch {
                Write-Error -Message "Failed to load check file '$($file.FullName)': $($_.Exception.Message)" -Category InvalidData -TargetObject $file.FullName
                continue
            }
            finally {
                $script:ArgusRegistrationTarget = $previousTarget
            }

            if ($registered.Count -eq 0) {
                Write-Error -Message "Check file '$($file.FullName)' did not call Register-ArgusCheck." -Category InvalidData -TargetObject $file.FullName
                continue
            }

            foreach ($check in $registered) {
                if (-not $seen.Add($check.Id)) {
                    Write-Error -Message "Duplicate check Id '$($check.Id)' in '$($file.FullName)'; the file is ignored." -Category ResourceExists -TargetObject $file.FullName
                    continue
                }
                $check.Source = $file.FullName
                $checks.Add($check)
            }
        }
    }

    $areaOrder = @($script:ArgusAreas.Keys)
    $checks | Sort-Object -Property @{ Expression = { $areaOrder.IndexOf($_.Area) } }, Id
}
