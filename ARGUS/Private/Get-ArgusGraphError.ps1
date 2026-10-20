function Get-ArgusGraphError {
    <#
    .SYNOPSIS
        Extracts the HTTP status code and Retry-After delay from an error thrown by Invoke-MgGraphRequest.

    .DESCRIPTION
        Invoke-MgGraphRequest surfaces HTTP failures as exceptions carrying an HttpResponseMessage
        (Response property) or, depending on the SDK version, only a message such as
        "Response status code does not indicate success: TooManyRequests (Too Many Requests)."
        Both shapes are handled. StatusCode is $null when it cannot be determined.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [System.Management.Automation.ErrorRecord] $ErrorRecord
    )

    $status = $null
    $retryAfter = $null
    $names = @{
        BadRequest = 400; Unauthorized = 401; Forbidden = 403; NotFound = 404; UnprocessableEntity = 422; TooManyRequests = 429
        InternalServerError = 500; BadGateway = 502; ServiceUnavailable = 503; GatewayTimeout = 504
    }

    $exception = $ErrorRecord.Exception
    foreach ($candidate in @($exception, $exception.InnerException)) {
        if ($null -eq $candidate) { continue }
        $responseProperty = $candidate.PSObject.Properties['Response']
        if ($null -eq $responseProperty -or $null -eq $responseProperty.Value) { continue }
        $response = $responseProperty.Value
        if ($response.PSObject.Properties['StatusCode']) {
            $status = [int]$response.StatusCode
        }
        if ($response.PSObject.Properties['Headers'] -and $response.Headers -and $response.Headers.PSObject.Properties['RetryAfter']) {
            $header = $response.Headers.RetryAfter
            if ($header -and $header.Delta) { $retryAfter = [math]::Ceiling($header.Delta.TotalSeconds) }
            elseif ($header -and $header.Date) { $retryAfter = [math]::Max(0, [math]::Ceiling(($header.Date - [datetimeoffset]::UtcNow).TotalSeconds)) }
        }
        if ($status) { break }
    }

    $message = [string]$exception.Message
    if (-not $status) {
        if ($message -match '\b(400|401|403|404|422|429|500|502|503|504)\b') { $status = [int]$Matches[1] }
        else {
            foreach ($name in $names.Keys) {
                if ($message -match "\b$name\b") { $status = $names[$name]; break }
            }
        }
    }
    if ($null -eq $retryAfter -and $message -match 'Retry-After[^\d]{0,5}(\d+)') { $retryAfter = [int]$Matches[1] }

    [pscustomobject]@{
        StatusCode = $status
        RetryAfter = $retryAfter
        Message    = $message
        Transient  = $status -in 429, 503, 504
    }
}
