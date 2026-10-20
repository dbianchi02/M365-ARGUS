Register-ArgusCheck @{
    Id          = 'ARG.COP.008'
    Title       = 'Agent creation and access are controlled (manual review)'
    Area        = 'Copilot'
    Category    = 'Agent governance'
    Severity    = 'Info'
    Description = 'Who can use and install agents (Agents > Settings > User access, and Agent and plugin access) is set in the Microsoft 365 admin center, and who can build agents in Copilot Studio is set per Power Platform environment. No Microsoft API exposes these settings to read-only tools, so this check is always To review and lists what to verify. ARG.COP.002 covers self-service trial sign-up. Info severity: it does not change the score.'
    Rationale   = 'When every user can build and run agents, agents connect to data, connectors and external services faster than they can be inventoried. A governed path (approved makers, approved agent types, a managed environment) keeps agents owned, reviewed and retired.'
    Remediation = @{
        Steps      = "1. In the Microsoft 365 admin center, go to Agents > Settings > User access and choose Specific users or groups instead of All users if agents are not meant for everybody.`n2. In Agents > Settings > Agent and plugin access, allow only the agent types the organisation supports (Microsoft, your organisation, external publishers).`n3. In the Power Platform admin center, restrict environment creation to admins and limit Copilot Studio makers to a security group in each environment."
        PortalUrl  = 'https://admin.microsoft.com/'
    }
    References  = @(
        @{ Title = 'Agent settings in Microsoft 365 admin center'; Url = 'https://learn.microsoft.com/en-us/microsoft-365/admin/manage/agent-settings' }
        @{ Title = 'Agents admin guide for Microsoft 365'; Url = 'https://learn.microsoft.com/en-us/microsoft-365/copilot/agent-essentials/m365-agents-admin-guide' }
    )
    Requires    = @{
        Services = @('Graph')
    }
    Tags        = @('Copilot', 'Agents', 'Manual')
    Test        = {
        # Manual review: no tenant data is read, so the context passed by the runner is not used.
        $location = 'Microsoft 365 admin center > Agents > Settings'
        $findings = @(
            [pscustomobject]@{ Setting = 'User access'; Location = $location; Default = 'All users'; Recommended = 'Specific users or groups, unless agents are open to everybody by decision' }
            [pscustomobject]@{ Setting = 'Agent and plugin access'; Location = $location; Default = 'Check the current selection'; Recommended = 'Only the publisher types the organisation supports' }
            [pscustomobject]@{ Setting = 'Copilot Studio makers'; Location = 'Power Platform admin center > Environments'; Default = 'Every licensed user can build agents in the default environment'; Recommended = 'A maker security group per environment; environment creation for admins only' }
        )
        New-ArgusResult -Status Investigate -Findings $findings -EvaluatedCount $findings.Count `
            -Summary 'Verify who can use, install and build agents; no API exposes these settings.'
    }
}
