function Resolve-ArgusOneDriveUrl {
    <#
    .SYNOPSIS
        Returns the OneDrive URL of users listed by the OneDrive usage report when its Site URL is empty.

    .DESCRIPTION
        The OneDrive usage report has no Site Id and can return an empty "Site URL" (Microsoft advisory
        SP676147). For users that still exist, the URL is the user's mySite property
        (GET /users/{id}?$select=mySite, JSON batching, User.Read.All). For users that no longer exist the URL
        is derived from the OneDrive naming convention: https://<tenant>-my.sharepoint.com/personal/<UPN with
        every character other than letters, digits and '-' replaced by '_'>; Derived is $true for those.
        Returns a hashtable: lowercase UPN -> [pscustomobject] @{ Url; Derived }.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [string[]] $UserPrincipalName,

        [Parameter()]
        [AllowNull()]
        [AllowEmptyCollection()]
        [object[]] $User = @(),

        [Parameter()]
        [AllowNull()]
        [object] $Organization
    )

    $result = @{}
    $upns = @($UserPrincipalName | Where-Object { $_ } | ForEach-Object { $_.ToLowerInvariant() } | Sort-Object -Unique)
    if ($upns.Count -eq 0) { return $result }

    $ids = @{}
    foreach ($item in @($User | Where-Object { $_ })) {
        $upn = ([string](Get-ArgusProperty $item 'userPrincipalName' '')).ToLowerInvariant()
        if ($upn -in $upns) { $ids[[string](Get-ArgusProperty $item 'id' '')] = $upn }
    }
    if ($ids.Count -gt 0) {
        $requests = @($ids.Keys | ForEach-Object { @{ Id = $_; Url = "/users/$_`?`$select=mySite" } })
        foreach ($response in @(Invoke-ArgusGraphBatch -Request $requests)) {
            $url = if ($response.Status -eq 200) { ([string](Get-ArgusProperty $response.Body 'mySite' '')).TrimEnd('/') } else { '' }
            if ($url) { $result[$ids[[string]$response.Id]] = [pscustomobject]@{ Url = $url; Derived = $false } }
        }
    }

    # Users that no longer exist (or without mySite): derive the URL from the initial .onmicrosoft.com domain.
    $initial = @(Get-ArgusProperty $Organization 'verifiedDomains' @() | Where-Object { (Get-ArgusProperty $_ 'isInitial' $false) -eq $true }) | Select-Object -First 1
    $prefix = ([string](Get-ArgusProperty $initial 'name' '') -split '\.')[0]
    if ($prefix) {
        foreach ($upn in $upns) {
            if ($result.ContainsKey($upn)) { continue }
            $result[$upn] = [pscustomobject]@{ Url = "https://$prefix-my.sharepoint.com/personal/$($upn -replace '[^a-z0-9\-]', '_')"; Derived = $true }
        }
    }
    $result
}
