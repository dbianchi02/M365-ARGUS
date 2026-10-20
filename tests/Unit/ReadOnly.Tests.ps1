#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.5.0' }

# Static guard for the hard rule "ARGUS is strictly read-only".
# Parses every module script and inspects the commands it calls (string literals such as
# remediation samples in check metadata are not commands and are ignored).

BeforeDiscovery {
    $script:files = Get-ChildItem -Path (Join-Path $PSScriptRoot '../../ARGUS') -Filter '*.ps1' -Recurse |
        ForEach-Object { @{ Name = $_.Name; Path = $_.FullName } }
}

BeforeAll {
    function Get-CommandCall {
        param([string] $Path)
        $tokens = $null
        $errors = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$tokens, [ref]$errors)
        $ast.FindAll({ param($node) $node -is [System.Management.Automation.Language.CommandAst] }, $true)
    }
}

Describe 'Read-only guard: <Name>' -ForEach $script:files {
    It 'calls Invoke-MgGraphRequest only from the Graph helpers' {
        $calls = @(Get-CommandCall -Path $Path | Where-Object { $_.GetCommandName() -eq 'Invoke-MgGraphRequest' })
        if ($Name -notin 'Invoke-ArgusGraphRequest.ps1', 'Invoke-ArgusGraphBatch.ps1') {
            $calls.Count | Should -Be 0 -Because 'all Graph access goes through Invoke-ArgusGraphRequest / Invoke-ArgusGraphBatch'
        }
        foreach ($call in $calls) {
            $text = $call.Extent.Text
            if ($Name -eq 'Invoke-ArgusGraphBatch.ps1') {
                $text | Should -Match '-Method POST -Uri \$batchUri' -Because 'the only POST is the $batch envelope of GET sub-requests'
            }
            else {
                $text | Should -Match '-Method GET\b'
            }
        }
    }

    It 'never calls write cmdlets for Graph, Exchange or SharePoint' {
        $pattern = '^(New|Set|Update|Remove|Add|Enable|Disable|Grant|Revoke|Clear|Reset|Restore|Move|Send|Invoke|Start|Stop)-(Mg|EXO|Mailbox|Mail|DistributionGroup|UnifiedGroup|PnP|Recipient|Org|Transport|CsTeams|Team|SPO|MSCommerce)'
        $writes = @(Get-CommandCall -Path $Path | ForEach-Object { $_.GetCommandName() } | Where-Object { $_ -and $_ -match $pattern -and $_ -ne 'Invoke-MgGraphRequest' })
        $writes | Should -BeNullOrEmpty
    }
}
