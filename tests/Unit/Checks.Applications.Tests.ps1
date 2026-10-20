#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.5.0' }

BeforeAll {
    Get-Module ARGUS | Remove-Module -Force
    Import-Module (Join-Path $PSScriptRoot '../../ARGUS/ARGUS.psd1') -Force -ErrorAction Stop
    . (Join-Path $PSScriptRoot 'TestHelpers.ps1')

    $script:now = [datetime]::new(2026, 10, 19, 0, 0, 0, [System.DateTimeKind]::Utc)

    # Credential relative to $now: -EndDays (negative = expired), -StartDays (days before now).
    function Get-TestCredential {
        param([string] $KeyId, [int] $EndDays, [int] $StartDays = 100, [string] $Usage = 'Verify', [string] $Name = $KeyId)
        [pscustomobject]@{
            keyId = $KeyId; displayName = $Name; hint = 'abc'; usage = $Usage; type = 'AsymmetricX509Cert'
            startDateTime = $script:now.AddDays(-$StartDays).ToString('o'); endDateTime = $script:now.AddDays($EndDays).ToString('o')
        }
    }

    function Get-TestApp {
        param([string] $Name, [object[]] $Secrets = @(), [object[]] $Certificates = @(), [int] $Owners = 1)
        [pscustomobject]@{
            id = "obj-$Name"; appId = "app-$Name"; displayName = $Name; createdDateTime = '2025-01-01T00:00:00Z'; signInAudience = 'AzureADMyOrg'
            passwordCredentials = $Secrets; keyCredentials = $Certificates; OwnerCount = $Owners
        }
    }

    function Invoke-AppCheck {
        param([string] $Id, [object[]] $Apps, [hashtable] $Options = @{})
        InModuleScope ARGUS -Parameters @{ Id = $Id; Apps = $Apps; Options = $Options } {
            Invoke-TestCheck -Id $Id -Data @{ Applications = $Apps } @Options
        }
    }
}

AfterAll {
    Get-Module ARGUS | Remove-Module -Force
}

Describe 'Applications catalogue' {
    It 'registers the 7 Applications checks of the specification' {
        (Get-ArgusCheck -Area Applications).Id | Should -Be @(1..7 | ForEach-Object { 'ARG.APP.{0:D3}' -f $_ })
    }
}

Describe 'ARG.APP.002 Client secrets expiring' {
    It 'fails for expiring secrets without a replacement and marks replaced ones' {
        $apps = @(
            Get-TestApp 'payroll' -Secrets @((Get-TestCredential 's1' 10))
            Get-TestApp 'crm' -Secrets @((Get-TestCredential 's2' 5), (Get-TestCredential 's3' 300))
            Get-TestApp 'ok' -Secrets @(Get-TestCredential 's4' 200)
            Get-TestApp 'expired' -Secrets @(Get-TestCredential 's5' -10)
        )
        $result = Invoke-AppCheck 'ARG.APP.002' $apps
        $result.Status | Should -Be 'Failed'
        $result.EvaluatedCount | Should -Be 4
        $result.Findings.AppName | Should -Be @('crm', 'payroll')
        ($result.Findings | Where-Object AppName -EQ 'crm').Replaced | Should -Be 'Yes'
        ($result.Findings | Where-Object AppName -EQ 'payroll').Replaced | Should -Be 'No'
        ($result.Findings | Where-Object AppName -EQ 'payroll').DaysLeft | Should -Be 10
        $result.Summary | Should -Be '2 of 4 client secrets expire within 30 days; 1 without a replacement secret.'
    }

    It 'passes when every expiring secret already has a replacement' {
        $apps = @(Get-TestApp 'crm' -Secrets @((Get-TestCredential 's2' 5), (Get-TestCredential 's3' 300)))
        $result = Invoke-AppCheck 'ARG.APP.002' $apps
        $result.Status | Should -Be 'Passed'
        @($result.Findings).Count | Should -Be 1
    }

    It 'passes when no secret expires soon' {
        (Invoke-AppCheck 'ARG.APP.002' @(Get-TestApp 'a' -Secrets @(Get-TestCredential 's' 90))).Status | Should -Be 'Passed'
    }

    It 'honours global AppId exclusions' {
        $apps = @(Get-TestApp 'payroll' -Secrets @(Get-TestCredential 's1' 10))
        $result = Invoke-AppCheck 'ARG.APP.002' $apps @{ Exclusions = @{ AppIds = @('app-payroll') } }
        @($result.Findings).Count | Should -Be 0
        $result.ExcludedCount | Should -Be 1
    }
}

Describe 'ARG.APP.003 Expired secrets still present' {
    It 'lists expired secrets' {
        $apps = @(
            Get-TestApp 'old' -Secrets @((Get-TestCredential 'a' -400), (Get-TestCredential 'b' -3))
            Get-TestApp 'fine' -Secrets @(Get-TestCredential 'c' 50)
        )
        $result = Invoke-AppCheck 'ARG.APP.003' $apps
        $result.Status | Should -Be 'Failed'
        $result.Findings.CredentialName | Should -Be @('a', 'b')
        $result.Summary | Should -Be '2 of 3 client secrets are expired but still present on 1 app registration.'
    }

    It 'passes without expired secrets' {
        (Invoke-AppCheck 'ARG.APP.003' @(Get-TestApp 'fine' -Secrets @(Get-TestCredential 'c' 50))).Status | Should -Be 'Passed'
    }
}

Describe 'ARG.APP.005 Certificates expiring' {
    It 'evaluates only authentication certificates (usage Verify)' {
        $apps = @(
            Get-TestApp 'daemon' -Certificates @((Get-TestCredential 'c1' 7), (Get-TestCredential 'enc' 7 -Usage 'Encrypt'))
            Get-TestApp 'renewed' -Certificates @((Get-TestCredential 'c2' 7), (Get-TestCredential 'c3' 365))
        )
        $result = Invoke-AppCheck 'ARG.APP.005' $apps
        $result.Status | Should -Be 'Failed'
        $result.EvaluatedCount | Should -Be 3
        @($result.Findings).Count | Should -Be 2
        ($result.Findings | Where-Object AppName -EQ 'renewed').Replaced | Should -Be 'Yes'
    }

    It 'passes when no certificate expires soon' {
        (Invoke-AppCheck 'ARG.APP.005' @(Get-TestApp 'a' -Certificates @(Get-TestCredential 'c' 120))).Status | Should -Be 'Passed'
    }
}

Describe 'ARG.APP.006 Expired certificates still present' {
    It 'lists expired certificates of any usage' {
        $apps = @(Get-TestApp 'old' -Certificates @((Get-TestCredential 'c1' -30), (Get-TestCredential 'enc' -1 -Usage 'Encrypt'), (Get-TestCredential 'c2' 100)))
        $result = Invoke-AppCheck 'ARG.APP.006' $apps
        $result.Status | Should -Be 'Failed'
        $result.Findings.CertificateName | Should -Be @('c1', 'enc')
    }

    It 'passes without expired certificates' {
        (Invoke-AppCheck 'ARG.APP.006' @(Get-TestApp 'a' -Certificates @(Get-TestCredential 'c' 10))).Status | Should -Be 'Passed'
    }
}

Describe 'ARG.APP.001 App registrations without owners' {
    It 'lists ownerless apps, those with credentials first' {
        $apps = @(
            Get-TestApp 'no-creds' -Owners 0
            Get-TestApp 'with-creds' -Owners 0 -Secrets @(Get-TestCredential 's' 50)
            Get-TestApp 'owned' -Owners 2
        )
        $result = Invoke-AppCheck 'ARG.APP.001' $apps
        $result.Status | Should -Be 'Failed'
        $result.Findings.AppName | Should -Be @('with-creds', 'no-creds')
        $result.Findings[0].Secrets | Should -Be 1
        $result.Summary | Should -Be '2 of 3 app registrations have no owner.'
    }

    It 'passes when every app has an owner' {
        (Invoke-AppCheck 'ARG.APP.001' @(Get-TestApp 'owned' -Owners 1)).Status | Should -Be 'Passed'
    }
}

Describe 'ARG.APP.007 Long-lived certificates' {
    It 'lists valid authentication certificates living longer than 180 days' {
        $apps = @(Get-TestApp 'legacy' -Certificates @(
                (Get-TestCredential 'three-years' 900 -StartDays 200)
                (Get-TestCredential 'short' 90 -StartDays 60)
                (Get-TestCredential 'encryption' 900 -StartDays 200 -Usage 'Encrypt')
                (Get-TestCredential 'expired' -5 -StartDays 1000)
            ))
        $result = Invoke-AppCheck 'ARG.APP.007' $apps
        $result.Status | Should -Be 'Failed'
        $result.EvaluatedCount | Should -Be 2
        $result.Findings.CertificateName | Should -Be @('three-years')
        $result.Findings[0].LifetimeDays | Should -Be 1100
    }

    It 'passes for certificates within 180 days' {
        (Invoke-AppCheck 'ARG.APP.007' @(Get-TestApp 'a' -Certificates @(Get-TestCredential 'c' 100 -StartDays 80))).Status | Should -Be 'Passed'
    }
}

Describe 'ARG.APP.004 Long-lived client secrets' {
    It 'lists valid secrets living longer than 24 months' {
        $apps = @(Get-TestApp 'legacy' -Secrets @(
                (Get-TestCredential 'ten-years' 3000 -StartDays 650)
                (Get-TestCredential 'two-years' 365 -StartDays 365)
                (Get-TestCredential 'expired-long' -10 -StartDays 2000)
            ))
        $result = Invoke-AppCheck 'ARG.APP.004' $apps
        $result.Status | Should -Be 'Failed'
        $result.EvaluatedCount | Should -Be 2
        $result.Findings.CredentialName | Should -Be @('ten-years')
        $result.Findings[0].LifetimeMonths | Should -Be 120
    }

    It 'honours the MaxLifetimeMonths override' {
        $apps = @(Get-TestApp 'a' -Secrets @(Get-TestCredential 's' 200 -StartDays 200))
        (Invoke-AppCheck 'ARG.APP.004' $apps @{ Setting = @{ Parameters = @{ MaxLifetimeMonths = 12 } } }).Status | Should -Be 'Failed'
        (Invoke-AppCheck 'ARG.APP.004' $apps).Status | Should -Be 'Passed'
    }
}
