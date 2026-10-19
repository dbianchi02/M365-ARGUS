function ConvertTo-ArgusResultDocument {
    <#
    .SYNOPSIS
        Assembles the versioned results document (SchemaVersion 1.0) written to JSON and rendered to HTML.

    .DESCRIPTION
        Top-level properties: SchemaVersion, Tool, Run, Tenant, Environment, Report, Score, Results.
        Local file paths (config, custom checks, logo) are reduced to file names so the document can be
        shared without leaking the operator's file system layout.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]] $Result,

        [Parameter(Mandatory)]
        [pscustomobject] $Score,

        [Parameter(Mandatory)]
        [pscustomobject] $Environment,

        [Parameter(Mandatory)]
        [System.Collections.IDictionary] $Config,

        [Parameter(Mandatory)]
        [datetimeoffset] $StartedAt,

        [Parameter(Mandatory)]
        [datetimeoffset] $FinishedAt,

        [Parameter()]
        [System.Collections.IDictionary] $Filter = @{},

        [Parameter()]
        [string] $ConfigPath
    )

    $filters = [ordered]@{}
    foreach ($name in 'Area', 'Id', 'ExcludeId', 'Tag') {
        $filters[$name] = [string[]]@($Filter[$name] | Where-Object { $_ })
    }

    $exclusionCounts = [ordered]@{}
    foreach ($list in $script:ArgusExclusionColumns.Keys) {
        $exclusionCounts[$list] = @($Config.Exclusions[$list] | Where-Object { $_ }).Count
    }

    [pscustomobject][ordered]@{
        SchemaVersion = $script:ArgusSchemaVersion
        Tool          = [pscustomobject][ordered]@{
            Name       = 'ARGUS'
            Version    = $script:ArgusVersion
            ProjectUri = 'https://github.com/dbianchi02/M365-ARGUS'
        }
        Run           = [pscustomobject][ordered]@{
            StartedAt         = $StartedAt.ToString('o')
            FinishedAt        = $FinishedAt.ToString('o')
            DurationSeconds   = [math]::Round(($FinishedAt - $StartedAt).TotalSeconds, 1)
            TimeZone          = [System.TimeZoneInfo]::Local.Id
            Account           = $Environment.Account
            AuthMode          = $Environment.AuthMode
            Filters           = [pscustomobject]$filters
            ConfigFile        = if ($ConfigPath) { Split-Path -Path $ConfigPath -Leaf } else { $null }
            ExclusionCounts   = [pscustomobject]$exclusionCounts
            MaxFindingsInHtml = $Config.Report.MaxFindingsInHtml
        }
        Tenant        = [pscustomobject][ordered]@{
            Id            = $Environment.TenantId
            Name          = $Environment.TenantName
            DefaultDomain = $Environment.TenantDefaultDomain
        }
        Environment   = [pscustomobject][ordered]@{
            ConnectedServices    = [string[]]@($Environment.ConnectedServices)
            GrantedScopes        = if ($null -ne $Environment.GrantedScopes) { [string[]]@($Environment.GrantedScopes) } else { $null }
            Licenses             = if ($null -ne $Environment.Licenses) { [string[]]@($Environment.Licenses) } else { $null }
            ConcealedReportNames = $Environment.ConcealedReportNames
        }
        Report        = [pscustomobject][ordered]@{
            CompanyName = [string]$Config.Report.CompanyName
        }
        Score         = $Score
        Results       = @($Result)
    }
}
