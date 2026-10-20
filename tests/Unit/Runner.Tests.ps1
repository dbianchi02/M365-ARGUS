#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.5.0' }

BeforeAll {
    Get-Module ARGUS | Remove-Module -Force
    Import-Module (Join-Path $PSScriptRoot '../../ARGUS/ARGUS.psd1') -Force -ErrorAction Stop
    . (Join-Path $PSScriptRoot 'TestHelpers.ps1')
}

AfterAll {
    Get-Module ARGUS | Remove-Module -Force
}

Describe 'Invoke-ArgusCheckRunner' {
    Context 'execution' {
        It 'returns Passed, Failed and Error and continues after an exception' {
            InModuleScope ARGUS {
                $checks = @(
                    Get-TestCheck -Override @{ Id = 'ARG.ENT.001'; Test = { param($Context) throw 'boom' } }
                    Get-TestCheck -Override @{ Id = 'ARG.ENT.007'; Test = { param($Context) New-ArgusResult -Status Failed -Findings @([pscustomobject]@{ A = 1 }) } }
                    Get-TestCheck -Override @{ Id = 'ARG.ENT.005' }
                )
                $results = @(Invoke-ArgusCheckRunner -Check $checks -Config (Get-ArgusConfig) -Environment (Get-TestEnvironment))
                $results.Status | Should -Be @('Error', 'Failed', 'Passed')
                $results[0].ErrorMessage | Should -Be 'boom'
                $results[1].AffectedCount | Should -Be 1
                $results | ForEach-Object { $_.PSObject.TypeNames | Should -Contain 'Argus.CheckResult' }
            }
        }

        It 'turns non-terminating errors inside a check into Error' {
            InModuleScope ARGUS {
                $check = Get-TestCheck -Override @{ Test = { param($Context) Write-Error 'soft failure'; New-ArgusResult -Status Passed } }
                $result = Invoke-ArgusCheckRunner -Check @($check) -Config (Get-ArgusConfig) -Environment (Get-TestEnvironment)
                $result.Status | Should -Be 'Error'
                $result.ErrorMessage | Should -Be 'soft failure'
            }
        }

        It 'returns Error when a check does not return exactly one result (<Name>)' -ForEach @(
            @{ Name = 'nothing'; Body = '' }
            @{ Name = 'a string'; Body = "'done'" }
            @{ Name = 'two results'; Body = 'New-ArgusResult -Status Passed; New-ArgusResult -Status Passed' }
        ) {
            InModuleScope ARGUS -Parameters @{ Body = $Body } {
                $check = Get-TestCheck -Override @{ Test = [scriptblock]::Create("param(`$Context) $Body") }
                $result = Invoke-ArgusCheckRunner -Check @($check) -Config (Get-ArgusConfig) -Environment (Get-TestEnvironment)
                $result.Status | Should -Be 'Error'
                $result.ErrorMessage | Should -BeLike '*exactly one result*'
            }
        }

        It 'measures the duration' {
            InModuleScope ARGUS {
                $check = Get-TestCheck -Override @{ Test = { param($Context) Start-Sleep -Milliseconds 50; New-ArgusResult -Status Passed } }
                $result = Invoke-ArgusCheckRunner -Check @($check) -Config (Get-ArgusConfig) -Environment (Get-TestEnvironment)
                $result.Duration | Should -BeOfType [double]
                $result.Duration | Should -BeGreaterOrEqual 0.04
            }
        }

        It 'passes Now, Parameters, Config and Environment in the context' {
            InModuleScope ARGUS {
                $now = [datetime]::new(2026, 1, 15, 0, 0, 0, [System.DateTimeKind]::Utc)
                $check = Get-TestCheck -Override @{
                    Parameters = @{ InactiveDays = 90 }
                    Test       = {
                        param($Context)
                        New-ArgusResult -Status Passed -Summary ('{0}|{1}|{2}|{3}' -f $Context.Now.ToString('yyyy-MM-dd'), $Context.Parameters.InactiveDays, $Context.Config.Scoring.Weights.High, ($Context.Environment.ConnectedServices -join ','))
                    }
                }
                $result = Invoke-ArgusCheckRunner -Check @($check) -Config (Get-ArgusConfig) -Environment (Get-TestEnvironment) -Now $now
                $result.Summary | Should -Be '2026-01-15|90|5|Graph'
            }
        }

        It 'resolves Title and Summary placeholders with effective parameters and counts' {
            InModuleScope ARGUS {
                $check = Get-TestCheck -Override @{
                    Title      = 'Users inactive for more than {InactiveDays} days'
                    Parameters = @{ InactiveDays = 90 }
                    Test       = { param($Context) New-ArgusResult -Status Failed -Summary '{AffectedCount} of {EvaluatedCount} users inactive for {InactiveDays}+ days.' -AffectedCount 37 -EvaluatedCount 1204 }
                }
                $config = Get-ArgusConfig
                $config.Checks['ARG.ENT.001'] = @{ Parameters = @{ InactiveDays = 120 }; Severity = 'High' }
                $result = Invoke-ArgusCheckRunner -Check @($check) -Config $config -Environment (Get-TestEnvironment)
                $result.Title | Should -Be 'Users inactive for more than 120 days'
                $result.Summary | Should -Be '37 of 1,204 users inactive for 120+ days.'
                $result.Severity | Should -Be 'High'
                $result.Parameters.InactiveDays | Should -Be 120
            }
        }

        It 'does not expose the Test scriptblock in results' {
            InModuleScope ARGUS {
                $result = Invoke-ArgusCheckRunner -Check @(Get-TestCheck) -Config (Get-ArgusConfig) -Environment (Get-TestEnvironment)
                $result.PSObject.Properties.Name | Should -Not -Contain 'Test'
                $result.AreaDisplayName | Should -Be 'Entra ID'
            }
        }

        It 'warns about config entries for unknown checks' {
            InModuleScope ARGUS {
                $config = Get-ArgusConfig
                $config.Checks['ARG.ENT.999'] = @{ Enabled = $false }
                $null = Invoke-ArgusCheckRunner -Check @(Get-TestCheck) -Config $config -Environment (Get-TestEnvironment) -WarningVariable warnings -WarningAction SilentlyContinue
                ($warnings | Out-String) | Should -BeLike "*unknown check 'ARG.ENT.999'*"
            }
        }
    }

    Context 'filters' {
        BeforeAll {
            InModuleScope ARGUS {
                $script:filterChecks = @(
                    Get-TestCheck -Override @{ Id = 'ARG.ENT.001'; Tags = @('Users') }
                    Get-TestCheck -Override @{ Id = 'ARG.ENT.007'; Tags = @('Guests') }
                    Get-TestCheck -Override @{ Id = 'ARG.APP.002'; Area = 'Applications'; Tags = @('Credentials') }
                )
            }
        }

        It '<Name>' -ForEach @(
            @{ Name = 'selects by area'; Filter = @{ Area = 'Applications' }; Expected = @('NotRun', 'NotRun', 'Passed'); Reason = '*-Area filter*' }
            @{ Name = 'selects by Id with wildcards'; Filter = @{ Id = 'ARG.ENT.*' }; Expected = @('Passed', 'Passed', 'NotRun'); Reason = '*-Id filter*' }
            @{ Name = 'selects by tag'; Filter = @{ Tag = 'Guests' }; Expected = @('NotRun', 'Passed', 'NotRun'); Reason = '*-Tag filter*' }
            @{ Name = 'excludes by Id'; Filter = @{ ExcludeId = 'ARG.ENT.00*' }; Expected = @('NotRun', 'NotRun', 'Passed'); Reason = '*-ExcludeId*' }
            @{ Name = 'combines filters'; Filter = @{ Area = 'EntraID'; ExcludeId = 'ARG.ENT.007' }; Expected = @('Passed', 'NotRun', 'NotRun'); Reason = '*' }
        ) {
            InModuleScope ARGUS -Parameters @{ Filter = $Filter; Expected = $Expected; Reason = $Reason } {
                $results = @(Invoke-ArgusCheckRunner -Check $script:filterChecks -Config (Get-ArgusConfig) -Environment (Get-TestEnvironment) @Filter)
                $results.Status | Should -Be $Expected
                $results | Where-Object Status -EQ 'NotRun' | ForEach-Object { $_.SkipReason | Should -BeLike $Reason }
            }
        }

        It 'marks checks disabled in configuration as NotRun' {
            InModuleScope ARGUS {
                $config = Get-ArgusConfig
                $config.Checks['ARG.ENT.007'] = @{ Enabled = $false }
                $results = @(Invoke-ArgusCheckRunner -Check $script:filterChecks -Config $config -Environment (Get-TestEnvironment))
                $results[1].Status | Should -Be 'NotRun'
                $results[1].SkipReason | Should -Be 'Disabled in configuration.'
            }
        }

        It 'does not execute NotRun checks' {
            InModuleScope ARGUS {
                $check = Get-TestCheck -Override @{ Test = { param($Context) throw 'must not run' } }
                $result = Invoke-ArgusCheckRunner -Check @($check) -Config (Get-ArgusConfig) -Environment (Get-TestEnvironment) -ExcludeId 'ARG.ENT.001'
                $result.Status | Should -Be 'NotRun'
            }
        }
    }

    Context 'prerequisites' {
        It 'skips <Name> before execution' -ForEach @(
            @{ Name = 'a missing service'; Requires = @{ Services = @('Graph', 'Exchange') }; Env = @{ Services = @('Graph') }; Reason = 'Not connected to Exchange Online.' }
            @{ Name = 'Graph not connected'; Requires = @{ Services = @('Graph') }; Env = @{ Services = @() }; Reason = 'Not connected to Microsoft Graph.' }
            @{ Name = 'a missing scope'; Requires = @{ GraphScopes = @('User.Read.All', 'AuditLog.Read.All') }; Env = @{ Scopes = @('User.Read.All') }; Reason = 'Missing scope AuditLog.Read.All.' }
            @{ Name = 'a missing licence'; Requires = @{ Licenses = @('AAD_PREMIUM') }; Env = @{ Licenses = @() }; Reason = 'Entra ID P1 licence (AAD_PREMIUM) not detected.' }
            @{ Name = 'several missing prerequisites'; Requires = @{ Services = @('SharePoint'); Licenses = @('AAD_PREMIUM_P2') }; Env = @{ Licenses = @('AAD_PREMIUM') }; Reason = 'Not connected to SharePoint Online (PnP.PowerShell); Entra ID P2 licence (AAD_PREMIUM_P2) not detected.' }
        ) {
            InModuleScope ARGUS -Parameters @{ Requires = $Requires; Env = $Env; Reason = $Reason } {
                $check = Get-TestCheck -Override @{ Requires = $Requires; Test = { param($Context) throw 'must not run' } }
                $environment = Get-TestEnvironment @Env
                $result = Invoke-ArgusCheckRunner -Check @($check) -Config (Get-ArgusConfig) -Environment $environment
                $result.Status | Should -Be 'Skipped'
                $result.SkipReason | Should -Be $Reason
            }
        }

        It 'runs when <Name>' -ForEach @(
            @{ Name = 'granted scopes are unknown'; Requires = @{ GraphScopes = @('AuditLog.Read.All') }; Env = @{} }
            @{ Name = 'licences are unknown'; Requires = @{ Licenses = @('AAD_PREMIUM') }; Env = @{} }
            @{ Name = 'a ReadWrite scope covers the Read scope'; Requires = @{ GraphScopes = @('User.Read.All') }; Env = @{ Scopes = @('User.ReadWrite.All') } }
            @{ Name = 'Entra ID P2 implies P1'; Requires = @{ Licenses = @('AAD_PREMIUM') }; Env = @{ Licenses = @('AAD_PREMIUM_P2') } }
        ) {
            InModuleScope ARGUS -Parameters @{ Requires = $Requires; Env = $Env } {
                $check = Get-TestCheck -Override @{ Requires = $Requires }
                $environment = Get-TestEnvironment @Env
                (Invoke-ArgusCheckRunner -Check @($check) -Config (Get-ArgusConfig) -Environment $environment).Status | Should -Be 'Passed'
            }
        }
    }

    Context 'data sets' {
        It 'prefetches each data set once and passes only the declared ones' {
            InModuleScope ARGUS {
                Mock Get-ArgusData { switch ($Name) { 'Users' { , @('u1', 'u2') } 'Groups' { , @('g1') } } }
                $checks = @(
                    Get-TestCheck -Override @{ Id = 'ARG.ENT.001'; Requires = @{ DataSets = @('Users') }; Test = { param($Context) New-ArgusResult -Status Passed -Summary ("{0}|{1}" -f @($Context.Data['Users']).Count, $Context.Data.ContainsKey('Groups')) } }
                    Get-TestCheck -Override @{ Id = 'ARG.ENT.007'; Requires = @{ DataSets = @('Users', 'Groups') }; Test = { param($Context) New-ArgusResult -Status Passed -Summary ("{0}|{1}" -f @($Context.Data['Users']).Count, @($Context.Data['Groups']).Count) } }
                )
                $results = @(Invoke-ArgusCheckRunner -Check $checks -Config (Get-ArgusConfig) -Environment (Get-TestEnvironment))
                $results[0].Summary | Should -Be '2|False'
                $results[1].Summary | Should -Be '2|1'
                Should -Invoke Get-ArgusData -Times 1 -Exactly -ParameterFilter { $Name -eq 'Users' }
                Should -Invoke Get-ArgusData -Times 1 -Exactly -ParameterFilter { $Name -eq 'Groups' }
            }
        }

        It 'does not load data sets for skipped or NotRun checks' {
            InModuleScope ARGUS {
                Mock Get-ArgusData { , @() }
                $checks = @(
                    Get-TestCheck -Override @{ Id = 'ARG.ENT.001'; Requires = @{ Services = @('Exchange'); DataSets = @('Mailboxes') } }
                    Get-TestCheck -Override @{ Id = 'ARG.ENT.007'; Requires = @{ DataSets = @('Devices') } }
                )
                $null = Invoke-ArgusCheckRunner -Check $checks -Config (Get-ArgusConfig) -Environment (Get-TestEnvironment) -ExcludeId 'ARG.ENT.007'
                Should -Invoke Get-ArgusData -Times 0 -Exactly
            }
        }

        It 'returns Error for checks whose data set failed to load' {
            InModuleScope ARGUS {
                Mock Get-ArgusData { throw 'HTTP 403 Forbidden' }
                $check = Get-TestCheck -Override @{ Requires = @{ DataSets = @('Users') }; Test = { param($Context) throw 'must not run' } }
                $result = Invoke-ArgusCheckRunner -Check @($check) -Config (Get-ArgusConfig) -Environment (Get-TestEnvironment)
                $result.Status | Should -Be 'Error'
                $result.ErrorMessage | Should -Be "Data set 'Users' could not be loaded: HTTP 403 Forbidden"
            }
        }
    }

    Context 'global exclusions' {
        BeforeAll {
            InModuleScope ARGUS {
                $script:exclusionTest = {
                    param($Context)
                    $findings = @(
                        [pscustomobject]@{ UserPrincipalName = 'breakglass01@contoso.onmicrosoft.com'; ObjectId = 'a' }
                        [pscustomobject]@{ UserPrincipalName = 'user1@contoso.com'; ObjectId = 'b' }
                    )
                    New-ArgusResult -Status Failed -Summary '{AffectedCount} of {EvaluatedCount} users are inactive.' -EvaluatedCount 10 -Findings $findings
                }
            }
        }

        It 'removes excluded findings and adjusts counts and summary' {
            InModuleScope ARGUS {
                $config = Get-ArgusConfig
                $config.Exclusions.UserPrincipalNames = @('BREAKGLASS01@contoso.onmicrosoft.com')
                $result = Invoke-ArgusCheckRunner -Check @(Get-TestCheck -Override @{ Test = $script:exclusionTest }) -Config $config -Environment (Get-TestEnvironment)
                $result.Status | Should -Be 'Failed'
                @($result.Findings).Count | Should -Be 1
                $result.Findings[0].UserPrincipalName | Should -Be 'user1@contoso.com'
                $result.AffectedCount | Should -Be 1
                $result.EvaluatedCount | Should -Be 9
                $result.ExcludedCount | Should -Be 1
                $result.Summary | Should -Be '1 of 9 users are inactive. 1 object(s) excluded by configuration.'
            }
        }

        It 'turns a Failed result into Passed when every finding is excluded' {
            InModuleScope ARGUS {
                $config = Get-ArgusConfig
                $config.Exclusions.ObjectIds = @('a', 'b')
                $result = Invoke-ArgusCheckRunner -Check @(Get-TestCheck -Override @{ Test = $script:exclusionTest }) -Config $config -Environment (Get-TestEnvironment)
                $result.Status | Should -Be 'Passed'
                $result.AffectedCount | Should -Be 0
                $result.ExcludedCount | Should -Be 2
            }
        }

        It 'keeps findings when the check sets ApplyExclusions = $false' {
            InModuleScope ARGUS {
                $config = Get-ArgusConfig
                $config.Exclusions.UserPrincipalNames = @('breakglass01@contoso.onmicrosoft.com')
                $check = Get-TestCheck -Override @{ ApplyExclusions = $false; Test = $script:exclusionTest }
                $result = Invoke-ArgusCheckRunner -Check @($check) -Config $config -Environment (Get-TestEnvironment)
                @($result.Findings).Count | Should -Be 2
                $result.ExcludedCount | Should -Be 0
            }
        }
    }
}

Describe 'Test-ArgusExcluded' {
    It 'matches <Name>' -ForEach @(
        @{ Name = 'UPN case-insensitively'; Row = @{ UserPrincipalName = 'A@Contoso.com' }; Exclusions = @{ UserPrincipalNames = @('a@contoso.com') }; Expected = $true }
        @{ Name = 'object Id in the Id column'; Row = @{ Id = 'guid-1' }; Exclusions = @{ ObjectIds = @('guid-1') }; Expected = $true }
        @{ Name = 'group Id'; Row = @{ GroupId = 'g1' }; Exclusions = @{ GroupIds = @('g1') }; Expected = $true }
        @{ Name = 'site URL ignoring the trailing slash'; Row = @{ SiteUrl = 'https://contoso.sharepoint.com/sites/hr/' }; Exclusions = @{ SiteUrls = @('https://contoso.sharepoint.com/sites/hr') }; Expected = $true }
        @{ Name = 'app Id'; Row = @{ AppId = 'app-1' }; Exclusions = @{ AppIds = @('app-1') }; Expected = $true }
        @{ Name = 'nothing when no column matches'; Row = @{ DisplayName = 'a@contoso.com' }; Exclusions = @{ UserPrincipalNames = @('a@contoso.com') }; Expected = $false }
        @{ Name = 'nothing when lists are empty'; Row = @{ UserPrincipalName = 'a@contoso.com' }; Exclusions = @{ UserPrincipalNames = @() }; Expected = $false }
    ) {
        InModuleScope ARGUS -Parameters @{ Row = $Row; Exclusions = $Exclusions; Expected = $Expected } {
            Test-ArgusExcluded -InputObject ([pscustomobject]$Row) -Exclusions $Exclusions | Should -Be $Expected
        }
    }
}
