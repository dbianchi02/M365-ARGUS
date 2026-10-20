function Register-ArgusCheck {
    <#
    .SYNOPSIS
        Validates a check definition and adds it to the registration target.

    .DESCRIPTION
        Called from check files (ARG.<AREA>.<NNN>.ps1) with the metadata hashtable described in
        docs/ARGUS-SPEC.md section 4. The definition is validated and normalised into an 'Argus.CheckDefinition'
        object. While Import-ArgusCheck is running the object is added to its registration target;
        -PassThru also returns it.

        Validation errors are thrown as a single message listing every problem found.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [System.Collections.IDictionary] $Definition,

        [Parameter()]
        [switch] $PassThru
    )

    $problems = [System.Collections.Generic.List[string]]::new()
    $get = { param($Key) if ($Definition.Contains($Key)) { $Definition[$Key] } else { $null } }

    $allowedKeys = @('Id', 'Title', 'Area', 'Category', 'Severity', 'Description', 'Rationale', 'Remediation',
        'References', 'Requires', 'Parameters', 'Tags', 'UsesBeta', 'ApplyExclusions', 'Test')
    foreach ($key in $Definition.Keys) {
        if ($key -notin $allowedKeys) { $problems.Add("Unknown metadata field '$key'.") }
    }

    foreach ($key in 'Id', 'Title', 'Area', 'Category', 'Severity', 'Description', 'Rationale') {
        $value = & $get $key
        if ($value -isnot [string] -or [string]::IsNullOrWhiteSpace($value)) {
            $problems.Add("Field '$key' is mandatory and must be a non-empty string.")
        }
    }

    $id = & $get 'Id'
    $area = & $get 'Area'
    if ($id -is [string] -and $id -cnotmatch '^ARG\.[A-Z]{3}\.\d{3}$') {
        $problems.Add("Id '$id' must match the format ARG.<AREA>.<NNN> (for example ARG.ENT.001).")
    }
    if ($area -is [string] -and $area) {
        if (-not $script:ArgusAreas.Contains($area)) {
            $problems.Add("Area '$area' is not valid. Allowed: $($script:ArgusAreas.Keys -join ', ').")
        }
        elseif ($id -is [string] -and $id -cmatch '^ARG\.([A-Z]{3})\.\d{3}$' -and $Matches[1] -cne $script:ArgusAreas[$area].Code) {
            $problems.Add("Id '$id' does not match area '$area' (expected prefix ARG.$($script:ArgusAreas[$area].Code).).")
        }
    }

    $severity = & $get 'Severity'
    if ($severity -is [string] -and $severity -and $severity -notin $script:ArgusSeverities) {
        $problems.Add("Severity '$severity' is not valid. Allowed: $($script:ArgusSeverities -join ', ').")
    }

    if ((& $get 'Test') -isnot [scriptblock]) {
        $problems.Add("Field 'Test' is mandatory and must be a scriptblock.")
    }

    # Remediation
    $remediation = & $get 'Remediation'
    if ($remediation -isnot [System.Collections.IDictionary]) {
        $problems.Add("Field 'Remediation' is mandatory and must be a hashtable with at least 'Steps'.")
        $remediation = @{}
    }
    else {
        foreach ($key in $remediation.Keys) {
            if ($key -notin 'Steps', 'PowerShell', 'PortalUrl') { $problems.Add("Unknown Remediation field '$key'.") }
        }
        if (-not $remediation.Contains('Steps') -or [string]::IsNullOrWhiteSpace([string]$remediation['Steps'])) {
            $problems.Add("Remediation.Steps is mandatory.")
        }
        if ($remediation.Contains('PortalUrl') -and $remediation['PortalUrl'] -and [string]$remediation['PortalUrl'] -notmatch '^https://') {
            $problems.Add("Remediation.PortalUrl must be an https URL.")
        }
    }

    # References
    $references = @(& $get 'References' | Where-Object { $null -ne $_ })
    foreach ($reference in $references) {
        if ($reference -isnot [System.Collections.IDictionary] -or -not $reference['Title'] -or [string]$reference['Url'] -notmatch '^https://') {
            $problems.Add("Each reference must be a hashtable with 'Title' and an https 'Url'.")
            break
        }
    }

    # Requires
    $requires = & $get 'Requires'
    if ($null -eq $requires) { $requires = @{} }
    if ($requires -isnot [System.Collections.IDictionary]) {
        $problems.Add("Field 'Requires' must be a hashtable.")
        $requires = @{}
    }
    foreach ($key in $requires.Keys) {
        if ($key -notin 'Services', 'GraphScopes', 'Licenses', 'DataSets', 'OptionalDataSets') { $problems.Add("Unknown Requires field '$key'.") }
    }
    $services = @($requires['Services'] | Where-Object { $_ })
    foreach ($service in $services) {
        if (-not $script:ArgusServices.Contains([string]$service)) {
            $problems.Add("Requires.Services value '$service' is not valid. Allowed: $($script:ArgusServices.Keys -join ', ').")
        }
    }

    # Parameters
    $parameters = & $get 'Parameters'
    if ($null -eq $parameters) { $parameters = @{} }
    if ($parameters -isnot [System.Collections.IDictionary]) {
        $problems.Add("Field 'Parameters' must be a hashtable.")
        $parameters = @{}
    }

    if ($problems.Count -gt 0) {
        $label = if ($id) { $id } else { '<no Id>' }
        throw "Invalid check definition '$label': $($problems -join ' ')"
    }

    $check = [pscustomobject]@{
        PSTypeName      = 'Argus.CheckDefinition'
        Id              = $id
        Title           = $Definition['Title']
        Area            = $area
        Category        = $Definition['Category']
        Severity        = $severity
        Description     = $Definition['Description']
        Rationale       = $Definition['Rationale']
        Remediation     = [pscustomobject]@{
            Steps      = [string]$remediation['Steps']
            PowerShell = if ($remediation.Contains('PowerShell')) { [string]$remediation['PowerShell'] } else { '' }
            PortalUrl  = if ($remediation.Contains('PortalUrl')) { [string]$remediation['PortalUrl'] } else { '' }
        }
        References      = @($references | ForEach-Object { [pscustomobject]@{ Title = [string]$_['Title']; Url = [string]$_['Url'] } })
        Requires        = [pscustomobject]@{
            Services    = [string[]]@($services)
            GraphScopes = [string[]]@($requires['GraphScopes'] | Where-Object { $_ })
            Licenses    = [string[]]@($requires['Licenses'] | Where-Object { $_ })
            DataSets    = [string[]]@($requires['DataSets'] | Where-Object { $_ })
            # Loaded only when their service is connected; never an error when unavailable.
            OptionalDataSets = [string[]]@($requires['OptionalDataSets'] | Where-Object { $_ })
        }
        Parameters      = $parameters.Clone()
        Tags            = [string[]]@(& $get 'Tags' | Where-Object { $_ })
        UsesBeta        = [bool](& $get 'UsesBeta')
        ApplyExclusions = if ($Definition.Contains('ApplyExclusions')) { [bool]$Definition['ApplyExclusions'] } else { $true }
        Test            = $Definition['Test']
        Source          = $null
    }

    if ($null -ne $script:ArgusRegistrationTarget) {
        $script:ArgusRegistrationTarget.Add($check)
    }
    if ($PassThru) { $check }
}
