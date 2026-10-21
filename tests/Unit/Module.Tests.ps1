#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.5.0' }

BeforeDiscovery {
    $script:expectedCommands = @(
        'Connect-Argus'
        'Disconnect-Argus'
        'Test-ArgusPrerequisite'
        'Get-ArgusRequiredPermission'
        'Get-ArgusCheck'
        'New-ArgusConfig'
        'Invoke-Argus'
        'Export-ArgusReport'
    )
}

BeforeAll {
    $script:moduleRoot = Join-Path $PSScriptRoot '../../ARGUS'
    $script:manifestPath = Join-Path $script:moduleRoot 'ARGUS.psd1'
    Get-Module ARGUS | Remove-Module -Force
    Import-Module $script:manifestPath -Force -ErrorAction Stop
}

AfterAll {
    Get-Module ARGUS | Remove-Module -Force
}

Describe 'ARGUS module' {
    It 'has a valid manifest' {
        { Test-ModuleManifest -Path $script:manifestPath -ErrorAction Stop } | Should -Not -Throw
    }

    It 'targets PowerShell 7.2 Core' {
        $manifest = Import-PowerShellDataFile -Path $script:manifestPath
        $manifest.PowerShellVersion | Should -Be '7.2'
        $manifest.CompatiblePSEditions | Should -Be @('Core')
    }

    It 'is version 1.0.0 without a prerelease tag' {
        $manifest = Import-PowerShellDataFile -Path $script:manifestPath
        $manifest.ModuleVersion | Should -Be '1.0.0'
        $manifest.PrivateData.PSData.Prerelease | Should -BeNullOrEmpty
    }

    It 'requires only Microsoft.Graph.Authentication' {
        $manifest = Import-PowerShellDataFile -Path $script:manifestPath
        @($manifest.RequiredModules).Count | Should -Be 1
        $manifest.RequiredModules[0].ModuleName | Should -Be 'Microsoft.Graph.Authentication'
    }

    It 'exports exactly the public cmdlets of the spec' {
        $exported = (Get-Module ARGUS).ExportedFunctions.Keys | Sort-Object
        $exported | Should -Be ($expectedCommands | Sort-Object)
    }

    It 'lists every exported function explicitly in FunctionsToExport' {
        $manifest = Import-PowerShellDataFile -Path $script:manifestPath
        ($manifest.FunctionsToExport | Sort-Object) | Should -Be ($expectedCommands | Sort-Object)
    }
}

Describe 'Public cmdlet <_>' -ForEach $expectedCommands {
    BeforeAll {
        $script:command = Get-Command -Name $_ -Module ARGUS -ErrorAction SilentlyContinue
        $script:help = Get-Help -Name $_ -Full
    }

    It 'exists' {
        $script:command | Should -Not -BeNullOrEmpty
    }

    It 'uses the Argus noun prefix and an approved verb' {
        $script:command.Noun | Should -BeLike 'Argus*'
        (Get-Verb).Verb | Should -Contain $script:command.Verb
    }

    It 'has a synopsis, description and at least one example' {
        $script:help.Synopsis | Should -Not -BeNullOrEmpty
        $script:help.Synopsis | Should -Not -Be $_
        ($script:help.Description.Text -join '') | Should -Not -BeNullOrEmpty
        @($script:help.Examples.Example).Count | Should -BeGreaterThan 0
    }

    It 'documents every parameter' {
        $common = @([System.Management.Automation.PSCmdlet]::CommonParameters) + @([System.Management.Automation.PSCmdlet]::OptionalCommonParameters)
        $parameters = $script:command.Parameters.Keys | Where-Object { $_ -notin $common }
        foreach ($parameter in $parameters) {
            $doc = $script:help.Parameters.Parameter | Where-Object Name -EQ $parameter
            ($doc.Description.Text -join '') | Should -Not -BeNullOrEmpty -Because "parameter -$parameter of $_ must be documented"
        }
    }
}
