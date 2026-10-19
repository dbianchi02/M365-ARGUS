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
