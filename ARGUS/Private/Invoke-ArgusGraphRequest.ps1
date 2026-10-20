function Invoke-ArgusGraphRequest {
    <#
    .SYNOPSIS
        Read-only Microsoft Graph GET with paging, throttling retries and advanced-query support.

    .DESCRIPTION
        All Graph reads in ARGUS go through this function.
        - Only GET is allowed: any other method throws before a request is sent (ARGUS is read-only).
        - -Uri is relative ('/users?$select=id') or an absolute https://graph.microsoft.com URL
          (used for @odata.nextLink); other hosts are rejected so the token is never sent elsewhere.
        - -All follows @odata.nextLink until the last page.
        - -Advanced adds 'ConsistencyLevel: eventual' and $count=true (advanced directory queries).
        - -Beta targets /beta instead of /v1.0 (checks using it must set UsesBeta = $true).
        - -OutputFilePath saves the response body to a file (used for usage-report CSV downloads).
        - -Raw emits the response body as is, for entities that have their own 'value' property
          (for example copilotPolicySetting).
        Collection responses are emitted item by item; single-entity responses are emitted as one object.
    #>
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string] $Uri,

        [Parameter()]
        [string] $Method = 'GET',

        [Parameter()]
        [switch] $All,

        [Parameter()]
        [System.Collections.IDictionary] $Headers = @{},

        [Parameter()]
        [switch] $Advanced,

        [Parameter()]
        [switch] $Beta,

        [Parameter()]
        [string] $OutputFilePath,

        [Parameter()]
        [switch] $Raw,

        [Parameter()]
        [ValidateRange(0, 10)]
        [int] $MaxRetries = 5
    )

    if ($Method -ne 'GET') {
        throw "ARGUS is read-only: HTTP method '$Method' is not allowed (only GET)."
    }

    $requestHeaders = @{}
    foreach ($key in $Headers.Keys) { $requestHeaders[$key] = $Headers[$key] }

    if ($Uri -match '^https?://') {
        $parsed = [System.Uri]$Uri
        $expected = ([System.Uri]$script:ArgusGraphBaseUri).Host
        if ($parsed.Scheme -ne 'https' -or $parsed.Host -ne $expected) {
            throw "Refusing to call '$($parsed.Scheme)://$($parsed.Host)': only $script:ArgusGraphBaseUri is allowed."
        }
        $url = $Uri
    }
    else {
        $version = if ($Beta) { 'beta' } else { 'v1.0' }
        $url = '{0}/{1}/{2}' -f $script:ArgusGraphBaseUri, $version, $Uri.TrimStart('/')
    }

    if ($Advanced) {
        $requestHeaders['ConsistencyLevel'] = 'eventual'
        if ($url -notmatch '[?&]\$count=') { $url += $(if ($url.Contains('?')) { '&' } else { '?' }) + '$count=true' }
    }

    if ($OutputFilePath) {
        Invoke-ArgusWithRetry -MaxRetries $MaxRetries -Activity "GET $url" -ScriptBlock {
            Invoke-MgGraphRequest -Method GET -Uri $url -Headers $requestHeaders -OutputFilePath $OutputFilePath -ErrorAction Stop
        } | Out-Null
        return
    }

    while ($url) {
        Write-Verbose "GET $url"
        $response = Invoke-ArgusWithRetry -MaxRetries $MaxRetries -Activity "GET $url" -ScriptBlock {
            Invoke-MgGraphRequest -Method GET -Uri $url -Headers $requestHeaders -OutputType PSObject -ErrorAction Stop
        }
        if ($null -eq $response) { return }

        $valueProperty = $response.PSObject.Properties['value']
        if ($Raw -or $null -eq $valueProperty) {
            $response
            return
        }
        foreach ($item in @($valueProperty.Value)) { $item }

        $next = $response.PSObject.Properties['@odata.nextLink']
        $url = if ($All -and $next -and $next.Value) { [string]$next.Value } else { $null }
        if ($url -and $url -notlike "$script:ArgusGraphBaseUri/*") {
            throw "Unexpected @odata.nextLink host: '$url'."
        }
    }
}
