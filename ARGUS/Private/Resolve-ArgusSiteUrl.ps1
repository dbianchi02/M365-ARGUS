function Resolve-ArgusSiteUrl {
    <#
    .SYNOPSIS
        Returns the web URL of SharePoint sites from their Site Id (usage report rows with an empty Site URL).

    .DESCRIPTION
        The SharePoint usage reports can return an empty "Site URL" (Microsoft advisory SP676147); the
        documented workaround is to read the site from its "Site Id".
        When the PnP tenant site list (SharePointSites data set) is passed with -TenantSite, the URL is
        read from it first: it lists every site collection, including private group and channel sites
        that a delegated Graph call cannot read when the account is not a member of them.
        The remaining sites are read with one read-only GET /sites/{id}?$select=webUrl per site through
        JSON batching (Sites.Read.All).
        Returns a hashtable: lowercase Site Id -> webUrl. Sites that cannot be read are left out.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [string[]] $SiteId,

        [AllowNull()]
        [object[]] $TenantSite
    )

    $ids = @($SiteId | Where-Object { $_ -and $_ -ne [guid]::Empty.ToString() } | ForEach-Object { $_.ToLowerInvariant() } | Sort-Object -Unique)
    $result = @{}
    if ($ids.Count -eq 0) { return $result }
    foreach ($site in @($TenantSite | Where-Object { $_ })) {
        $id = ([string](Get-ArgusProperty $site 'SiteId' '')).ToLowerInvariant()
        $url = [string](Get-ArgusProperty $site 'Url' '')
        if ($id -and $url -and $id -in $ids) { $result[$id] = $url }
    }
    $requests = @($ids | Where-Object { -not $result.ContainsKey($_) } | ForEach-Object { @{ Id = $_; Url = "/sites/$_`?`$select=webUrl" } })
    if ($requests.Count -eq 0) { return $result }
    foreach ($response in @(Invoke-ArgusGraphBatch -Request $requests)) {
        $url = if ($response.Status -eq 200) { [string](Get-ArgusProperty $response.Body 'webUrl' '') } else { '' }
        if ($url) { $result[[string]$response.Id] = $url }
    }
    $result
}
