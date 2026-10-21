#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.5.0' }

BeforeAll {
    Get-Module ARGUS | Remove-Module -Force
    Import-Module (Join-Path $PSScriptRoot '../../ARGUS/ARGUS.psd1') -Force -ErrorAction Stop
    $script:fakeChecks = Join-Path $PSScriptRoot '../Fixtures/FakeChecks'
}

AfterAll {
    Get-Module ARGUS | Remove-Module -Force
}

Describe 'Get-ArgusCheck' {
    It 'lists custom checks with metadata and without the Test scriptblock' {
        $checks = @(Get-ArgusCheck -CustomCheckPath $script:fakeChecks)
        $checks.Count | Should -BeGreaterOrEqual 6
        $check = $checks | Where-Object Id -EQ 'ARG.APP.902'
        $check.PSObject.TypeNames | Should -Contain 'Argus.CheckInfo'
        $check.Parameters.DaysAhead | Should -Be 30
        $check.PSObject.Properties.Name | Should -Not -Contain 'Test'
    }

    It 'filters by <Name>' -ForEach @(
        @{ Name = 'area'; Filter = @{ Area = 'Licensing' }; Expected = @('ARG.LIC.903') }
        @{ Name = 'severity'; Filter = @{ Severity = 'High' }; Expected = @('ARG.APP.902') }
        @{ Name = 'Id wildcard'; Filter = @{ Id = 'ARG.GRP.*' }; Expected = @('ARG.GRP.904') }
        @{ Name = 'tag'; Filter = @{ Tag = 'Credentials' }; Expected = @('ARG.APP.902') }
    ) {
        # Scoped to the fake checks (ARG.*.9xx) so built-in checks don't affect the expectation.
        $ids = @(Get-ArgusCheck -CustomCheckPath $script:fakeChecks @Filter | Where-Object Id -Like 'ARG.*.9*' | ForEach-Object Id)
        $ids | Should -Be $Expected
    }
}

Describe 'New-ArgusConfig' {
    It 'writes a valid configuration file' {
        $path = Join-Path $TestDrive 'cfg/argus.json'
        $file = New-ArgusConfig -Path $path
        $file.FullName | Should -Be ([System.IO.Path]::GetFullPath($path))
        $json = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json -AsHashtable
        $json.Scoring.Weights.Critical | Should -Be 10
        $json.Keys | Should -Contain 'Checks'
        InModuleScope ARGUS -Parameters @{ Path = $path } {
            { Get-ArgusConfig -Path $Path } | Should -Not -Throw
        }
    }

    It 'refuses to overwrite without -Force' {
        $path = Join-Path $TestDrive 'existing.json'
        Set-Content -LiteralPath $path -Value '{}'
        { New-ArgusConfig -Path $path } | Should -Throw '*already exists*'
        { New-ArgusConfig -Path $path -Force } | Should -Not -Throw
        (Get-Content -LiteralPath $path -Raw) | Should -BeLike '*Scoring*'
    }

    It 'supports -WhatIf' {
        $path = Join-Path $TestDrive 'whatif.json'
        New-ArgusConfig -Path $path -WhatIf
        Test-Path -LiteralPath $path | Should -BeFalse
    }
}

Describe 'Invoke-Argus' {
    BeforeAll {
        Mock Write-ArgusRunSummary -ModuleName ARGUS { }
    }

    BeforeEach {
        $script:out = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
    }

    It 'writes a versioned JSON results file with every status' {
        $document = Invoke-Argus -CustomCheckPath $script:fakeChecks -ExcludeId 'ARG.SPO.906' -OutputFormat Json -OutputPath $script:out -NoBrowser -PassThru -WarningAction SilentlyContinue

        $file = @(Get-ChildItem -LiteralPath $script:out -Filter '*.json')
        $file.Count | Should -Be 1
        $file[0].Name | Should -Match '^ARGUS-Report-tenant-\d{8}-\d{4}\.json$'

        $json = Get-Content -LiteralPath $file[0].FullName -Raw | ConvertFrom-Json
        $json.SchemaVersion | Should -Be '1.0'
        $json.Tool.Name | Should -Be 'ARGUS'
        $json.Tool.Version | Should -Be '1.0.0-preview1'
        ($json.Results.Status | Sort-Object -Unique) | Should -Be @('Error', 'Failed', 'Investigate', 'NotRun', 'Passed', 'Skipped')
        $json.Run.Filters.ExcludeId | Should -Be @('ARG.SPO.906')
        $json.Score.Counts.Total | Should -Be $json.Results.Count
        ($json.Results | Where-Object Id -EQ 'ARG.APP.902').Findings.Count | Should -Be 3
        $document.SchemaVersion | Should -Be '1.0'
    }

    It 'returns nothing without -PassThru' {
        $output = Invoke-Argus -CustomCheckPath $script:fakeChecks -OutputFormat Json -OutputPath $script:out -NoBrowser -WarningAction SilentlyContinue
        $output | Should -BeNullOrEmpty
    }

    It 'prints the banner with version, author and copyright from the manifest' {
        $manifest = Import-PowerShellDataFile -Path (Join-Path $PSScriptRoot '../../ARGUS/ARGUS.psd1')
        $info = Invoke-Argus -CustomCheckPath $script:fakeChecks -OutputFormat Json -OutputPath $script:out -NoBrowser -WarningAction SilentlyContinue 6>&1
        $text = ($info | ForEach-Object { [string]$_ }) -join "`n"
        $text | Should -Match ([regex]::Escape("Version  $($manifest.ModuleVersion)"))
        $text | Should -Match ([regex]::Escape("Author   $($manifest.Author)"))
        $text | Should -Match ([regex]::Escape($manifest.Copyright))
        if ($manifest.PrivateData.PSData.Prerelease) { $text | Should -Match '\[Preview\]' }
    }

    It 'omits the banner with -NoBanner' {
        $info = Invoke-Argus -CustomCheckPath $script:fakeChecks -OutputFormat Json -OutputPath $script:out -NoBrowser -NoBanner -WarningAction SilentlyContinue 6>&1
        (($info | ForEach-Object { [string]$_ }) -join "`n") | Should -Not -Match 'Governance Utility Suite'
    }

    It 'applies the configuration file (exclusions and disabled checks)' {
        $config = Join-Path $TestDrive 'config.json'
        Set-Content -LiteralPath $config -Value '{ "Exclusions": { "AppIds": ["11111111-1111-1111-1111-111111111111"] }, "Checks": { "ARG.ENT.901": { "Enabled": false } } }'
        $document = Invoke-Argus -CustomCheckPath $script:fakeChecks -ConfigPath $config -OutputFormat Json -OutputPath $script:out -NoBrowser -PassThru -WarningAction SilentlyContinue

        ($document.Results | Where-Object Id -EQ 'ARG.ENT.901').Status | Should -Be 'NotRun'
        $app = $document.Results | Where-Object Id -EQ 'ARG.APP.902'
        $app.ExcludedCount | Should -Be 1
        $app.AffectedCount | Should -Be 2
        $document.Run.ConfigFile | Should -Be 'config.json'
        $document.Run.ExclusionCounts.AppIds | Should -Be 1
    }

    It 'writes one CSV per failed check and neutralises spreadsheet formulas' {
        $null = Invoke-Argus -CustomCheckPath $script:fakeChecks -OutputFormat Csv -OutputPath $script:out -NoBrowser -WarningAction SilentlyContinue
        $csv = @(Get-ChildItem -LiteralPath $script:out -Filter '*.csv')
        $csv.Count | Should -Be 1
        $csv[0].Name | Should -BeLike '*-ARG.APP.902.csv'
        $rows = @(Import-Csv -LiteralPath $csv[0].FullName)
        $rows.Count | Should -Be 3
        $rows[2].DisplayName | Should -BeLike "'=HYPERLINK*"
        $rows[1].DisplayName | Should -Be '<script>alert(1)</script>'
        @(Get-ChildItem -LiteralPath $script:out -Filter '*.json').Count | Should -Be 0
    }

    It 'warns when not connected and skips checks that need Graph' {
        $null = Invoke-Argus -CustomCheckPath $script:fakeChecks -OutputFormat Json -OutputPath $script:out -NoBrowser -WarningVariable warnings -WarningAction SilentlyContinue
        ($warnings | Out-String) | Should -BeLike '*Not connected to Microsoft Graph*'
    }

    It 'overrides MaxFindingsInHtml from the parameter' {
        $document = Invoke-Argus -CustomCheckPath $script:fakeChecks -OutputFormat Json -OutputPath $script:out -NoBrowser -PassThru -MaxFindingsInHtml 42 -WarningAction SilentlyContinue
        $document.Run.MaxFindingsInHtml | Should -Be 42
    }

    It 'prints the console summary' {
        $null = Invoke-Argus -CustomCheckPath $script:fakeChecks -OutputFormat Json -OutputPath $script:out -NoBrowser -WarningAction SilentlyContinue
        Should -Invoke Write-ArgusRunSummary -ModuleName ARGUS -Times 1 -Exactly
    }
}
