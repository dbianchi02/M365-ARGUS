function Resolve-ArgusSiteUrl {
    <#
    .SYNOPSIS
        Returns the web URL of SharePoint sites from their Site Id (usage report rows with an empty Site URL).

    .DESCRIPTION
        The SharePoint usage reports can return an empty "Site URL" (Microsoft advisory SP676147); the
        documented workaround is to read the site from its "Site Id". Sends one read-only
        GET /sites/{id}?$select=webUrl per site through JSON batching (Sites.Read.All).
        Returns a hashtable: lowercase Site Id -> webUrl. Sites that cannot be read are left out.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [string[]] $SiteId
    )

    $ids = @($SiteId | Where-Object { $_ -and $_ -ne [guid]::Empty.ToString() } | ForEach-Object { $_.ToLowerInvariant() } | Sort-Object -Unique)
    $result = @{}
    if ($ids.Count -eq 0) { return $result }
    $requests = @($ids | ForEach-Object { @{ Id = $_; Url = "/sites/$_`?`$select=webUrl" } })
    foreach ($response in @(Invoke-ArgusGraphBatch -Request $requests)) {
        $url = if ($response.Status -eq 200) { [string](Get-ArgusProperty $response.Body 'webUrl' '') } else { '' }
        if ($url) { $result[[string]$response.Id] = $url }
    }
    $result
}
