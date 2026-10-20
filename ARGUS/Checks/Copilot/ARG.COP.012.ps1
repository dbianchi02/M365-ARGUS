Register-ArgusCheck @{
    Id          = 'ARG.COP.012'
    Title       = 'Agent requests pending for more than {PendingDays} days'
    Area        = 'Copilot'
    Category    = 'Agent governance'
    Severity    = 'Low'
    Description = 'Packages with an open user request (`GET /copilot/admin/catalog/packages?$filter=requestStatus eq ''pending''`: publish, activate, access or update) whose `lastModifiedDateTime` is older than {PendingDays} days. The API exposes the package''s last change, not the request date, so the age is approximate. Requires a Microsoft Agent 365 licence; otherwise the check is Skipped.'
    Rationale   = 'An approval process only works when requests are answered. Requests left open push users to workarounds (personal agents, shadow tools) and leave the catalogue out of date.'
    Remediation = @{
        Steps      = "1. In the Microsoft 365 admin center, go to Agents > Requests.`n2. Approve or reject each request, with a reason.`n3. Optionally add the agent management rule that rejects publish requests older than a set number of days (Agents > Settings > Agent management rules)."
        PortalUrl  = 'https://admin.microsoft.com/'
    }
    References  = @(
        @{ Title = 'List Copilot packages: filter by request properties'; Url = 'https://learn.microsoft.com/en-us/microsoft-365/copilot/extensibility/api/admin-settings/package/copilotpackages-list' }
        @{ Title = 'Agent settings: agent management rules'; Url = 'https://learn.microsoft.com/en-us/microsoft-365/admin/manage/agent-settings' }
    )
    Requires    = @{
        Services    = @('Graph')
        GraphScopes = @('CopilotPackages.Read.All')
        Licenses    = @('AGENT_365')
        DataSets    = @('CopilotPackages')
    }
    Parameters  = @{ PendingDays = 7 }
    Tags        = @('Copilot', 'Agents', 'Lifecycle')
    Test        = {
        param($Context)
        $catalog = $Context.Data['CopilotPackages']
        $unavailable = Get-ArgusProperty $catalog 'ArgusUnavailable'
        if ($unavailable) { return New-ArgusResult -Status Skipped -SkipReason $unavailable }
        $pending = @(Get-ArgusProperty $catalog 'PendingRequests' @() | Where-Object { $_ })
        $cutoff = $Context.Now.AddDays(-[int]$Context.Parameters.PendingDays)
        $findings = @($pending | ForEach-Object {
                $modified = ConvertTo-ArgusUtcDate (Get-ArgusProperty $_ 'lastModifiedDateTime' '')
                if ($modified -and $modified -ge $cutoff) { return }
                [pscustomobject]@{
                    DisplayName  = Get-ArgusProperty $_ 'displayName' ''
                    RequestType  = Get-ArgusProperty $_ 'requestType' ''
                    Type         = Get-ArgusProperty $_ 'type' ''
                    Publisher    = Get-ArgusProperty $_ 'publisher' ''
                    LastModified = Format-ArgusDate $modified 'Unknown'
                    DaysPending  = if ($modified) { [int]($Context.Now - $modified).TotalDays } else { $null }
                    PackageId    = Get-ArgusProperty $_ 'id' ''
                }
            } | Sort-Object @{ Expression = { if ($null -eq $_.DaysPending) { [int]::MaxValue } else { $_.DaysPending } }; Descending = $true })
        $status = if ($findings.Count -gt 0) { 'Failed' } else { 'Passed' }
        New-ArgusResult -Status $status -Findings $findings -EvaluatedCount $pending.Count `
            -Summary '{AffectedCount} of {EvaluatedCount} pending agent requests are older than {PendingDays} days.'
    }
}
