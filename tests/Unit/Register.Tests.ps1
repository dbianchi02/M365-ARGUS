#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.5.0' }

BeforeAll {
    Get-Module ARGUS | Remove-Module -Force
    Import-Module (Join-Path $PSScriptRoot '../../ARGUS/ARGUS.psd1') -Force -ErrorAction Stop
    . (Join-Path $PSScriptRoot 'TestHelpers.ps1')
    $script:fakeChecks = Join-Path $PSScriptRoot '../Fixtures/FakeChecks'
}

AfterAll {
    Get-Module ARGUS | Remove-Module -Force
}

Describe 'Register-ArgusCheck' {
    It 'normalises a valid definition with defaults' {
        InModuleScope ARGUS {
            $check = Get-TestCheck
            $check.PSObject.TypeNames | Should -Contain 'Argus.CheckDefinition'
            $check.Id | Should -Be 'ARG.ENT.001'
            $check.UsesBeta | Should -BeFalse
            $check.ApplyExclusions | Should -BeTrue
            $check.Remediation.PowerShell | Should -Be ''
            @($check.Requires.Services).Count | Should -Be 0
            $check.Test | Should -BeOfType [scriptblock]
        }
    }

    It 'rejects <Name>' -ForEach @(
        @{ Name = 'a missing Title'; Override = @{ Title = '' }; Message = "*Field 'Title' is mandatory*" }
        @{ Name = 'an invalid Id format'; Override = @{ Id = 'ENT-001' }; Message = '*must match the format ARG.<AREA>.<NNN>*' }
        @{ Name = 'a lowercase Id'; Override = @{ Id = 'arg.ent.001' }; Message = '*must match the format*' }
        @{ Name = 'an Id that does not match the area'; Override = @{ Id = 'ARG.APP.002' }; Message = '*does not match area*' }
        @{ Name = 'an unknown Area'; Override = @{ Area = 'Intune' }; Message = "*Area 'Intune' is not valid*" }
        @{ Name = 'an unknown Severity'; Override = @{ Severity = 'Urgent' }; Message = "*Severity 'Urgent' is not valid*" }
        @{ Name = 'a Test that is not a scriptblock'; Override = @{ Test = 'Get-Date' }; Message = "*Field 'Test' is mandatory and must be a scriptblock*" }
        @{ Name = 'Remediation without Steps'; Override = @{ Remediation = @{ PortalUrl = 'https://entra.microsoft.com' } }; Message = '*Remediation.Steps is mandatory*' }
        @{ Name = 'a non-https PortalUrl'; Override = @{ Remediation = @{ Steps = 'x'; PortalUrl = 'http://example.com' } }; Message = '*PortalUrl must be an https URL*' }
        @{ Name = 'a reference without https Url'; Override = @{ References = @(@{ Title = 'x'; Url = 'ftp://x' }) }; Message = '*Each reference*' }
        @{ Name = 'an unknown metadata field'; Override = @{ Foo = 1 }; Message = "*Unknown metadata field 'Foo'*" }
        @{ Name = 'an unknown service'; Override = @{ Requires = @{ Services = @('Teams') } }; Message = "*Requires.Services value 'Teams'*" }
        @{ Name = 'an unknown Requires field'; Override = @{ Requires = @{ Roles = @('x') } }; Message = "*Unknown Requires field 'Roles'*" }
    ) {
        InModuleScope ARGUS -Parameters @{ Override = $Override; Message = $Message } {
            { Get-TestCheck -Override $Override } | Should -Throw -ExpectedMessage $Message
        }
    }

    It 'lists every problem in one message' {
        InModuleScope ARGUS {
            { Get-TestCheck -Override @{ Severity = 'Urgent'; Area = 'Intune' } } |
                Should -Throw -ExpectedMessage "*Area 'Intune'*Severity 'Urgent'*"
        }
    }
}

Describe 'Import-ArgusCheck' {
    It 'discovers the fake checks sorted by area order' {
        InModuleScope ARGUS -Parameters @{ Path = $script:fakeChecks } {
            $checks = @(Import-ArgusCheck -Path $Path)
            $checks.Id | Should -Be @('ARG.ENT.901', 'ARG.APP.902', 'ARG.LIC.903', 'ARG.GRP.904', 'ARG.SPO.906', 'ARG.EXO.905')
            $checks | ForEach-Object { $_.Source | Should -BeLike '*ARG.*.ps1' }
        }
    }

    It 'skips broken, empty and duplicate files and keeps loading the others' {
        $folder = Join-Path $TestDrive 'mixed'
        $null = New-Item -Path $folder -ItemType Directory
        Copy-Item -Path (Join-Path $script:fakeChecks 'ARG.ENT.901.ps1') -Destination $folder
        Copy-Item -Path (Join-Path $script:fakeChecks 'ARG.ENT.901.ps1') -Destination (Join-Path $folder 'ARG.ENT.999.ps1')
        Set-Content -Path (Join-Path $folder 'ARG.APP.002.ps1') -Value "Register-ArgusCheck @{ Id = 'ARG.APP.002' }"
        Set-Content -Path (Join-Path $folder 'ARG.LIC.006.ps1') -Value '# registers nothing'
        Copy-Item -Path (Join-Path $script:fakeChecks 'ARG.GRP.904.ps1') -Destination $folder

        InModuleScope ARGUS -Parameters @{ Path = $folder } {
            $errors = $null
            $checks = @(Import-ArgusCheck -Path $Path -ErrorAction SilentlyContinue -ErrorVariable errors)
            $checks.Id | Should -Be @('ARG.ENT.901', 'ARG.GRP.904')
            $messages = @($errors | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] -and $_.FullyQualifiedErrorId -like '*,Import-ArgusCheck' } |
                    ForEach-Object { $_.Exception.Message })
            $messages.Count | Should -Be 3
            $messages -like '*Duplicate check Id*' | Should -HaveCount 1
            $messages -like '*did not call Register-ArgusCheck*' | Should -HaveCount 1
            $messages -like '*Invalid check definition*' | Should -HaveCount 1
        }
    }

    It 'rejects an Id that is already registered' {
        InModuleScope ARGUS -Parameters @{ Path = $script:fakeChecks } {
            $checks = @(Import-ArgusCheck -Path $Path -ExistingId 'ARG.ENT.901' -ErrorAction SilentlyContinue)
            $checks.Id | Should -Not -Contain 'ARG.ENT.901'
            $checks.Count | Should -Be 5
        }
    }

    It 'restores the registration target after loading' {
        InModuleScope ARGUS -Parameters @{ Path = $script:fakeChecks } {
            $null = Import-ArgusCheck -Path $Path
            $script:ArgusRegistrationTarget | Should -BeNullOrEmpty
        }
    }
}

Describe 'Get-ArgusCheckCatalog' {
    It 'adds custom checks to the built-in ones' {
        InModuleScope ARGUS -Parameters @{ Path = $script:fakeChecks } {
            $catalog = @(Get-ArgusCheckCatalog -CustomCheckPath $Path)
            $catalog.Count | Should -Be (@($script:ArgusBuiltInChecks).Count + 6)
        }
    }

    It 'rejects a custom check that reuses a built-in Id' {
        InModuleScope ARGUS -Parameters @{ Path = $script:fakeChecks } {
            $saved = $script:ArgusBuiltInChecks
            try {
                $script:ArgusBuiltInChecks = @(Get-TestCheck -Override @{ Id = 'ARG.ENT.901' })
                $errors = $null
                $catalog = @(Get-ArgusCheckCatalog -CustomCheckPath $Path -ErrorAction SilentlyContinue -ErrorVariable errors)
                @($catalog | Where-Object Id -EQ 'ARG.ENT.901').Count | Should -Be 1
                @($errors | ForEach-Object { "$_" }) -like '*Duplicate check Id*' | Should -Not -BeNullOrEmpty
            }
            finally {
                $script:ArgusBuiltInChecks = $saved
            }
        }
    }

    It 'reports a missing custom folder' {
        InModuleScope ARGUS {
            { Get-ArgusCheckCatalog -CustomCheckPath (Join-Path $TestDrive 'nope') -ErrorAction Stop } | Should -Throw '*does not exist*'
        }
    }
}
