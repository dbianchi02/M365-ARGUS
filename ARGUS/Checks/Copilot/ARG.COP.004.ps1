Register-ArgusCheck @{
    Id          = 'ARG.COP.004'
    Title       = 'Anthropic models as a Microsoft subprocessor (manual review)'
    Area        = 'Copilot'
    Category    = 'AI data processing'
    Severity    = 'Info'
    Description = 'The "AI providers operating as Microsoft subprocessors" setting (Microsoft 365 admin center > Copilot > Settings) controls whether Anthropic models can be used in Copilot, Researcher, Copilot Studio, Power Platform and Copilot in Microsoft 365 apps. No Microsoft API exposes it, so this check is always To review: it reads the tenant country (`organization.countryLetterCode`) and states the default that applies. Anthropic is on by default in the commercial cloud and off by default in the EU, EFTA and the UK. Info severity: it does not change the score.'
    Rationale   = 'As a Microsoft subprocessor Anthropic is covered by the Microsoft Product Terms and DPA, but Anthropic models are excluded from the EU Data Boundary and from in-country processing commitments. For organisations subject to the GDPR this is a data-transfer decision that should be documented (records of processing, DPIA where required) and limited to approved users.'
    Remediation = @{
        Steps      = "1. In the Microsoft 365 admin center, go to Copilot > Settings > View all > AI providers operating as Microsoft subprocessors.`n2. Check whether Anthropic is enabled and who can access it (all users, or specific users and groups).`n3. If it is enabled, record the decision and its legal basis; limit access to approved groups, or select Disable Anthropic as a Microsoft subprocessor.`n4. Also review Copilot in Microsoft 365 apps with Anthropic models, a separate setting for Word, Excel and PowerPoint."
        PortalUrl  = 'https://admin.microsoft.com/'
    }
    References  = @(
        @{ Title = 'Anthropic models in Microsoft Online Services'; Url = 'https://learn.microsoft.com/en-us/microsoft-365/copilot/connect-to-ai-subprocessor' }
        @{ Title = 'Copilot in Microsoft 365 apps with Anthropic models'; Url = 'https://learn.microsoft.com/en-us/microsoft-365/copilot/copilot-anthropic-apps' }
        @{ Title = 'What is the EU Data Boundary?'; Url = 'https://learn.microsoft.com/en-us/privacy/eudb/eu-data-boundary-learn' }
    )
    Requires    = @{
        Services    = @('Graph')
        GraphScopes = @('Organization.Read.All')
        DataSets    = @('Organization')
    }
    Tags        = @('Copilot', 'AI', 'GDPR', 'Manual')
    Test        = {
        param($Context)
        # EU member states, EFTA (IS, LI, NO, CH) and the UK: Anthropic is off by default there.
        $optInCountries = @('AT', 'BE', 'BG', 'HR', 'CY', 'CZ', 'DK', 'EE', 'FI', 'FR', 'DE', 'GR', 'HU', 'IE', 'IT', 'LV', 'LT', 'LU', 'MT', 'NL', 'PL', 'PT', 'RO', 'SK', 'SI', 'ES', 'SE', 'IS', 'LI', 'NO', 'CH', 'GB')
        $country = [string](Get-ArgusProperty $Context.Data['Organization'] 'countryLetterCode' '')
        $default = if (-not $country) { 'Unknown (tenant country not available)' }
        elseif ($country.ToUpperInvariant() -in $optInCountries) { "Off (No users) - tenant country $country is in the EU, EFTA or UK" }
        else { "On for all users - tenant country $country is outside the EU, EFTA and UK" }
        $findings = @(
            [pscustomobject]@{
                Setting     = 'AI providers operating as Microsoft subprocessors > Anthropic'
                Location    = 'Microsoft 365 admin center > Copilot > Settings > View all'
                Default     = $default
                Recommended = 'Enabled only after a documented decision, for approved users or groups'
            }
            [pscustomobject]@{
                Setting     = 'Copilot in Microsoft 365 apps with Anthropic models'
                Location    = 'Microsoft 365 admin center > Copilot > Settings > View all'
                Default     = 'Separate setting for Word, Excel and PowerPoint'
                Recommended = 'Aligned with the subprocessor decision above'
            }
        )
        New-ArgusResult -Status Investigate -Findings $findings -EvaluatedCount $findings.Count `
            -Summary "Verify in the admin center whether Anthropic models are enabled; no API exposes this setting. Default for this tenant: $default."
    }
}
