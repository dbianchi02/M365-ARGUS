function Invoke-ArgusGraphBatch {
    <#
    .SYNOPSIS
        Runs many read-only Graph GET requests through JSON batching (20 per batch).

    .DESCRIPTION
        Each request is a hashtable with Id and Url (relative, e.g. '/groups/{id}/owners?$select=id').
        Every sub-request is a GET: any other Method throws before anything is sent.
        The batch envelope itself is a POST to /$batch, the documented transport for JSON batching;
        it carries only the GET sub-requests and never changes tenant data. This is the only POST
        ARGUS issues.

        Sub-requests throttled with 429/503/504 are retried (honouring their Retry-After header) up to
        -MaxRetries times. Returns one object per request, in input order: Id, Status, Body.
        Sub-request paging (@odata.nextLink inside a body) is not followed; callers that need more
        than one page call Invoke-ArgusGraphRequest -All for that item.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]] $Request,

        [Parameter()]
        [switch] $Beta,

        [Parameter()]
        [ValidateRange(0, 10)]
        [int] $MaxRetries = 5
    )

    $items = foreach ($entry in $Request) {
        $method = if ($entry -is [System.Collections.IDictionary] -and $entry.Contains('Method')) { [string]$entry['Method'] } else { 'GET' }
        if ($method -ne 'GET') {
            throw "ARGUS is read-only: batch sub-request method '$method' is not allowed (only GET)."
        }
        $id = [string]$entry['Id']
        $url = [string]$entry['Url']
        if (-not $id -or -not $url) { throw 'Each batch request needs an Id and a Url.' }
        if ($url -match '^https?://') { throw "Batch request '$id' must use a relative URL." }
        [pscustomobject]@{ Id = $id; Url = '/' + $url.TrimStart('/') }
    }
    $items = @($items)
    if ($items.Count -eq 0) { return }
    if (@($items.Id | Sort-Object -Unique).Count -ne $items.Count) { throw 'Batch request Ids must be unique.' }

    $version = if ($Beta) { 'beta' } else { 'v1.0' }
    $batchUri = '{0}/{1}/$batch' -f $script:ArgusGraphBaseUri, $version
    $results = @{}

    for ($offset = 0; $offset -lt $items.Count; $offset += 20) {
        $pending = @($items[$offset..([math]::Min($offset + 19, $items.Count - 1))])
        $attempt = 0
        while ($pending.Count -gt 0) {
            $body = @{ requests = @($pending | ForEach-Object { @{ id = $_.Id; method = 'GET'; url = $_.Url } }) } | ConvertTo-Json -Depth 5 -Compress
            $response = Invoke-ArgusWithRetry -MaxRetries $MaxRetries -Activity 'POST $batch' -ScriptBlock {
                # Read-only: the envelope only transports the GET sub-requests built above.
                Invoke-MgGraphRequest -Method POST -Uri $batchUri -Body $body -ContentType 'application/json' -OutputType PSObject -ErrorAction Stop
            }

            $byId = @{}
            foreach ($entry in $pending) { $byId[$entry.Id] = $entry }
            $retry = [System.Collections.Generic.List[object]]::new()
            $delay = 0
            foreach ($sub in @($response.responses)) {
                $status = [int]$sub.status
                $request = $byId[[string]$sub.id]
                if ($status -in 429, 503, 504 -and $attempt -lt $MaxRetries -and $request) {
                    $retry.Add($request)
                    $headers = $sub.PSObject.Properties['headers']
                    $after = if ($headers -and $headers.Value -and $headers.Value.PSObject.Properties['Retry-After']) { [int]$headers.Value.'Retry-After' } else { 0 }
                    $delay = [math]::Max($delay, $after)
                    continue
                }
                $results[[string]$sub.id] = [pscustomobject]@{
                    Id     = [string]$sub.id
                    Status = $status
                    Body   = if ($sub.PSObject.Properties['body']) { $sub.body } else { $null }
                }
            }

            $pending = @($retry)
            if ($pending.Count -gt 0) {
                $attempt++
                if ($delay -le 0) { $delay = [int][math]::Min(60, [math]::Pow(2, $attempt)) }
                Write-Verbose "Batch: $($pending.Count) sub-request(s) throttled; retry $attempt of $MaxRetries in $delay s."
                Start-Sleep -Seconds $delay
            }
        }
    }

    foreach ($item in $items) {
        if ($results.ContainsKey($item.Id)) { $results[$item.Id] }
        else { [pscustomobject]@{ Id = $item.Id; Status = 0; Body = $null } }
    }
}
