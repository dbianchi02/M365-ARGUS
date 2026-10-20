Register-ArgusCheck @{
    Id          = 'ARG.COP.005'
    Title       = 'Anthropic models with Data Retention, independent processor (manual review)'
    Area        = 'Copilot'
    Category    = 'AI data processing'
    Severity    = 'Info'
    Description = '"Anthropic models with Data Retention" (for example some Fable- and Mythos-class models) are offered under Anthropic''s own Commercial Terms and Data Processing Addendum: Anthropic acts as an independent processor, outside the Microsoft Product Terms and DPA, and retains inputs and outputs. They are off by default in every region and must be enabled explicitly in the Microsoft 365 admin center. No Microsoft API exposes the setting, so this check is always To review. Info severity: it does not change the score.'
    Rationale   = 'With these models prompts, files and responses are stored by Anthropic (most data up to 30 days, flagged content longer) under terms the organisation signs directly with Anthropic. That is a separate data-processing relationship and, for EU organisations, an international transfer that needs its own legal assessment.'
    Remediation = @{
        Steps      = "1. In the Microsoft 365 admin center, go to Copilot > Settings > View all and open the Anthropic models with Data Retention setting.`n2. Check whether it was enabled and for which users or groups.`n3. Keep it off unless legal and the DPO approved Anthropic's terms; when it is enabled, restrict it to the approved groups and record the decision."
        PortalUrl  = 'https://admin.microsoft.com/'
    }
    References  = @(
        @{ Title = 'Anthropic models in Microsoft Online Services: models with Data Retention'; Url = 'https://learn.microsoft.com/en-us/microsoft-365/copilot/connect-to-ai-subprocessor' }
    )
    Requires    = @{
        Services = @('Graph')
    }
    Tags        = @('Copilot', 'AI', 'GDPR', 'Manual')
    Test        = {
        # Manual review: no tenant data is read, so the context passed by the runner is not used.
        $findings = @(
            [pscustomobject]@{
                Setting     = 'Anthropic models with Data Retention'
                Location    = 'Microsoft 365 admin center > Copilot > Settings > View all'
                Default     = 'Off for all users, in every region'
                Recommended = 'Off, unless Anthropic''s Commercial Terms and DPA were approved; then only for approved groups'
            }
        )
        New-ArgusResult -Status Investigate -Findings $findings -EvaluatedCount 1 `
            -Summary 'Verify in the admin center that Anthropic models with Data Retention (Anthropic as independent processor) are not enabled, or only for approved groups; no API exposes this setting.'
    }
}
