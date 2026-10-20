# Shared helpers for the unit tests. Dot-source in BeforeAll after importing the module.
# The helpers are defined inside the module scope so that check Test scriptblocks created by them
# can call private functions such as New-ArgusResult.

InModuleScope ARGUS {
    function script:Get-TestCheck {
        param([hashtable] $Override = @{})
        $definition = @{
            Id          = 'ARG.ENT.001'
            Title       = 'Test check'
            Area        = 'EntraID'
            Category    = 'Tests'
            Severity    = 'Medium'
            Description = 'Test description.'
            Rationale   = 'Test rationale.'
            Remediation = @{ Steps = '1. Fix it.' }
            Requires    = @{}
            Tags        = @('T1')
            Test        = { param($Context) New-ArgusResult -Status Passed -Summary 'ok' }
        }
        foreach ($key in $Override.Keys) { $definition[$key] = $Override[$key] }
        Register-ArgusCheck -Definition $definition -PassThru
    }

    # Runs one built-in check through the real runner with tenant data placed in the per-run cache.
    function script:Invoke-TestCheck {
        param(
            [Parameter(Mandatory)] [string] $Id,
            [hashtable] $Data = @{},
            [string[]] $Services = @('Graph'),
            [string[]] $Licenses,
            [hashtable] $Setting,
            [hashtable] $Exclusions,
            [datetime] $Now = [datetime]::new(2026, 10, 19, 0, 0, 0, [System.DateTimeKind]::Utc)
        )
        $check = @($script:ArgusBuiltInChecks | Where-Object Id -EQ $Id)
        if ($check.Count -ne 1) { throw "Built-in check $Id not found." }
        $script:ArgusDataCache = @{}
        $script:ArgusDataSetNotes = @{}
        foreach ($key in $Data.Keys) { $script:ArgusDataCache[$key] = $Data[$key] }
        $config = Get-ArgusConfig
        if ($Setting) { $config.Checks[$Id] = $Setting }
        if ($Exclusions) { foreach ($key in $Exclusions.Keys) { $config.Exclusions[$key] = $Exclusions[$key] } }
        $environmentParameters = @{ Services = $Services }
        if ($PSBoundParameters.ContainsKey('Licenses')) { $environmentParameters.Licenses = $Licenses }
        $environment = Get-TestEnvironment @environmentParameters
        Invoke-ArgusCheckRunner -Check $check -Config $config -Environment $environment -Now $Now
    }

    function script:Get-TestEnvironment {
        param([string[]] $Services = @('Graph'), [string[]] $Scopes, [string[]] $Licenses)
        # $null means "unknown"; an empty array means "known to be none" (avoid `if` collapsing @() to $null).
        if (-not $PSBoundParameters.ContainsKey('Scopes')) { $Scopes = $null }
        if (-not $PSBoundParameters.ContainsKey('Licenses')) { $Licenses = $null }
        [pscustomobject]@{
            ConnectedServices    = $Services
            GrantedScopes        = $Scopes
            Licenses             = $Licenses
            ConcealedReportNames = $null
            TenantId             = $null
            TenantName           = $null
            TenantDefaultDomain  = $null
            Account              = $null
            AuthMode             = $null
        }
    }
}
