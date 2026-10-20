#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.5.0' }

# Every built-in check must ship complete, consistent metadata (spec section 4).

BeforeDiscovery {
    Import-Module (Join-Path $PSScriptRoot '../../ARGUS/ARGUS.psd1') -Force
    $script:checks = @(Get-ArgusCheck | ForEach-Object { @{ Id = $_.Id } })
}

BeforeAll {
    Get-Module ARGUS | Remove-Module -Force
    Import-Module (Join-Path $PSScriptRoot '../../ARGUS/ARGUS.psd1') -Force -ErrorAction Stop
    $script:knownDataSets = InModuleScope ARGUS { @(Get-ArgusDataSetDefinition).Name }
}

AfterAll {
    Get-Module ARGUS | Remove-Module -Force
}

Describe 'Built-in check <Id>' -ForEach $script:checks {
    BeforeAll {
        $script:check = Get-ArgusCheck -Id $Id
    }

    It 'lives in a file named after its Id, in its area folder' {
        $script:check.Source | Should -BeLike "*$([System.IO.Path]::DirectorySeparatorChar)$($script:check.Area)$([System.IO.Path]::DirectorySeparatorChar)$Id.ps1"
    }

    It 'has remediation steps, a portal link and Microsoft Learn references' {
        $script:check.Remediation.Steps | Should -Match '^1\. '
        $script:check.Remediation.PortalUrl | Should -Match '^https://'
        @($script:check.References).Count | Should -BeGreaterThan 0
        $script:check.References | ForEach-Object { $_.Url | Should -Match '^https://learn\.microsoft\.com/' }
        if ($script:check.Remediation.PowerShell) { $script:check.Remediation.PowerShell | Should -Match '^# Sample only' }
    }

    It 'resolves every placeholder in its title and description' {
        $script:check.Title | Should -Not -Match '\{\w+\}'
        $script:check.Description | Should -Not -Match '\{\w+\}'
    }

    It 'requires only read permissions and known data sets' {
        @($script:check.Requires.Services) | Should -Contain 'Graph'
        $script:check.Requires.GraphScopes | ForEach-Object { $_ | Should -Match '\.Read(Basic)?(\.|$)' }
        @($script:check.Requires.DataSets) + @($script:check.Requires.OptionalDataSets) | Where-Object { $_ } |
            ForEach-Object { $script:knownDataSets | Should -Contain $_ }
    }

    It 'has tags and a category' {
        @($script:check.Tags).Count | Should -BeGreaterThan 0
        $script:check.Category | Should -Not -BeNullOrEmpty
    }
}
