function Invoke-ArgusWithRetry {
    <#
    .SYNOPSIS
        Runs a Graph call and retries it on throttling or transient service errors.

    .DESCRIPTION
        Retries on HTTP 429, 503 and 504. The delay is the Retry-After value when the service sends one,
        otherwise exponential backoff (2, 4, 8, 16, 32 seconds, capped at 60). Any other error, or the
        last failure after -MaxRetries retries, is rethrown unchanged.
    #>
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [Parameter(Mandatory)]
        [scriptblock] $ScriptBlock,

        [Parameter()]
        [ValidateRange(0, 10)]
        [int] $MaxRetries = 5,

        [Parameter()]
        [string] $Activity = 'Microsoft Graph request'
    )

    $attempt = 0
    while ($true) {
        try {
            return (& $ScriptBlock)
        }
        catch {
            $info = Get-ArgusGraphError -ErrorRecord $_
            if (-not $info.Transient -or $attempt -ge $MaxRetries) { throw }
            $attempt++
            $delay = if ($info.RetryAfter -gt 0) { [int]$info.RetryAfter } else { [int][math]::Min(60, [math]::Pow(2, $attempt)) }
            Write-Verbose "$Activity returned HTTP $($info.StatusCode); retry $attempt of $MaxRetries in $delay s."
            Start-Sleep -Seconds $delay
        }
    }
}
