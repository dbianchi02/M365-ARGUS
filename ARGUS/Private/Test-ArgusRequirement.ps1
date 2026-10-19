function Test-ArgusRequirement {
    <#
    .SYNOPSIS
        Returns the reasons why a check's Requires are not met (empty when it can run).

    .DESCRIPTION
        Services must be connected. GraphScopes and Licenses are only enforced when the environment
        reports them (non-null); unknown values never cause a skip. A X.ReadWrite.All grant satisfies
        X.Read.All, and a licence is satisfied by any licence that implies it (Entra ID P2 implies P1).
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory)]
        [pscustomobject] $Check,

        [Parameter(Mandatory)]
        [pscustomobject] $Environment
    )

    $reasons = [System.Collections.Generic.List[string]]::new()

    foreach ($service in $Check.Requires.Services) {
        if ($service -notin $Environment.ConnectedServices) {
            $reasons.Add("Not connected to $($script:ArgusServices[$service])")
        }
    }

    if ($null -ne $Environment.GrantedScopes) {
        $granted = @($Environment.GrantedScopes)
        foreach ($scope in $Check.Requires.GraphScopes) {
            $readWrite = $scope -replace '\.Read\.', '.ReadWrite.'
            if ($scope -notin $granted -and $readWrite -notin $granted) {
                $reasons.Add("Missing scope $scope")
            }
        }
    }

    if ($null -ne $Environment.Licenses) {
        $owned = @($Environment.Licenses)
        foreach ($license in $Check.Requires.Licenses) {
            $info = $script:ArgusLicenses[$license]
            $acceptable = @($license) + @(if ($info) { $info.ImpliedBy })
            if (-not ($acceptable | Where-Object { $_ -in $owned })) {
                $name = if ($info) { "$($info.DisplayName) licence ($license)" } else { "Licence $license" }
                $reasons.Add("$name not detected")
            }
        }
    }

    $reasons.ToArray()
}
