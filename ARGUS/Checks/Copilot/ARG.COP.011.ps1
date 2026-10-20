Register-ArgusCheck @{
    Id          = 'ARG.COP.011'
    Title       = 'Agents from external publishers available to all users'
    Area        = 'Copilot'
    Category    = 'Agent governance'
    Severity    = 'Low'
    Description = 'Packages of the agent catalogue (`GET /copilot/admin/catalog/packages`) with `type` = `external` (built by partners), not blocked, and `availableTo` = all users. Each one is To review: external agents process data under the publisher''s own terms. Requires a Microsoft Agent 365 licence; otherwise the check is Skipped.'
    Rationale   = 'Data processed by non-Microsoft agents and plugins is not covered by Microsoft agreements. Making them available to everybody should follow a review of the publisher''s data handling, ideally with access limited to the teams that need them.'
    Remediation = @{
        Steps      = "1. In the Microsoft 365 admin center, go to Agents > All agents and filter by external publishers.`n2. For each agent, review the publisher terms and the data it can reach.`n3. Limit availability to specific users or groups, or block the agent; consider allowing only Microsoft and organisation agents in Agents > Settings > Agent and plugin access."
        PortalUrl  = 'https://admin.microsoft.com/'
    }
    References  = @(
        @{ Title = 'Manage agents in the Microsoft 365 admin center'; Url = 'https://learn.microsoft.com/en-us/microsoft-365/admin/manage/manage-copilot-agents-integrated-apps' }
        @{ Title = 'List Copilot packages'; Url = 'https://learn.microsoft.com/en-us/microsoft-365/copilot/extensibility/api/admin-settings/package/copilotpackages-list' }
    )
    Requires    = @{
        Services    = @('Graph')
        GraphScopes = @('CopilotPackages.Read.All')
        Licenses    = @('AGENT_365')
        DataSets    = @('CopilotPackages')
    }
    Tags        = @('Copilot', 'Agents', 'Inventory')
    Test        = {
        param($Context)
        $catalog = $Context.Data['CopilotPackages']
        $unavailable = Get-ArgusProperty $catalog 'ArgusUnavailable'
        if ($unavailable) { return New-ArgusResult -Status Skipped -SkipReason $unavailable }
        $packages = @(Get-ArgusProperty $catalog 'Packages' @() | Where-Object { $_ })
        # The enum is allowedForAll; documentation samples also show 'all'.
        $findings = @($packages | Where-Object {
                (Get-ArgusProperty $_ 'type' '') -eq 'external' -and (Get-ArgusProperty $_ 'isBlocked' $false) -ne $true -and
                (Get-ArgusProperty $_ 'availableTo' '') -in 'allowedForAll', 'all'
            } | ForEach-Object {
                [pscustomobject]@{
                    DisplayName  = Get-ArgusProperty $_ 'displayName' ''
                    Publisher    = Get-ArgusProperty $_ 'publisher' ''
                    DeployedTo   = Get-ArgusProperty $_ 'deployedTo' ''
                    Hosts        = (@(Get-ArgusProperty $_ 'supportedHosts' @()) -join ', ')
                    LastModified = Format-ArgusDate (Get-ArgusProperty $_ 'lastModifiedDateTime' '')
                    PackageId    = Get-ArgusProperty $_ 'id' ''
                }
            } | Sort-Object Publisher, DisplayName)
        $external = @($packages | Where-Object { (Get-ArgusProperty $_ 'type' '') -eq 'external' }).Count
        $status = if ($findings.Count -gt 0) { 'Investigate' } else { 'Passed' }
        New-ArgusResult -Status $status -Findings $findings -EvaluatedCount $external `
            -Summary '{AffectedCount} of {EvaluatedCount} agents and apps from external publishers are available to all users.'
    }
}
