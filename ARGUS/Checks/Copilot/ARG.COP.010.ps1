Register-ArgusCheck @{
    Id          = 'ARG.COP.010'
    Title       = 'Org-wide agent sharing is restricted (manual review)'
    Area        = 'Copilot'
    Category    = 'Agent governance'
    Severity    = 'Info'
    Description = 'The Sharing setting (Microsoft 365 admin center > Agents > Settings > Sharing) decides who can share agents built with Copilot Agent Builder (Copilot Studio lite) with the whole organisation: All users (default), No users, or Specific users. Sharing with named people stays possible in every case. No Microsoft API exposes the setting, so this check is always To review. Info severity: it does not change the score.'
    Rationale   = 'An agent shared with everyone answers from the knowledge sources its creator chose, for every user who opens it. Restricting org-wide sharing to a few publishers keeps the agent catalogue curated and avoids duplicate or unreviewed agents reaching the whole company.'
    Remediation = @{
        Steps      = "1. In the Microsoft 365 admin center, go to Agents > Settings > Sharing.`n2. Choose No users or Specific users (a group of approved publishers) instead of All users.`n3. Review agents already shared with the whole organisation on the Agents page and block or reassign the ones without an owner."
        PortalUrl  = 'https://admin.microsoft.com/'
    }
    References  = @(
        @{ Title = 'Agent settings in Microsoft 365 admin center: Sharing'; Url = 'https://learn.microsoft.com/en-us/microsoft-365/admin/manage/agent-settings' }
        @{ Title = 'Share and manage agents built with Microsoft 365 Copilot'; Url = 'https://learn.microsoft.com/en-us/microsoft-365-copilot/extensibility/copilot-studio-lite-publish-agent' }
    )
    Requires    = @{
        Services = @('Graph')
    }
    Tags        = @('Copilot', 'Agents', 'Sharing', 'Manual')
    Test        = {
        # Manual review: no tenant data is read, so the context passed by the runner is not used.
        $findings = @(
            [pscustomobject]@{
                Setting     = 'Sharing (agents built with Copilot Agent Builder)'
                Location    = 'Microsoft 365 admin center > Agents > Settings > Sharing'
                Default     = 'All users'
                Recommended = 'No users, or Specific users (approved publishers)'
            }
        )
        New-ArgusResult -Status Investigate -Findings $findings -EvaluatedCount 1 `
            -Summary 'Verify who can share agents with the whole organisation; no API exposes this setting.'
    }
}
