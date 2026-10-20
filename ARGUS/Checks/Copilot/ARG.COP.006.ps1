Register-ArgusCheck @{
    Id          = 'ARG.COP.006'
    Title       = 'Web search in Copilot is a deliberate choice'
    Area        = 'Copilot'
    Category    = 'AI data processing'
    Severity    = 'Low'
    UsesBeta    = $true
    Description = 'Reads the tenant-level "Allow web search in Copilot" Cloud Policy setting (`GET /beta/copilot/admin/policySettings/microsoft.copilot.allowwebsearch`, delegated sign-in only). When the policy is not configured, web search is available in Copilot and Copilot Chat (unless optional connected experiences are disabled): To review. The meaning of each configured value is not documented, so a configured value is To review unless it is listed in the `DisabledValues` parameter after you verified it in the Cloud Policy service. A group-scoped policy cannot be read by this API and is also To review.'
    Rationale   = 'With web search on, Copilot sends search queries derived from prompts (and sometimes from open documents) to Bing. Microsoft acts as data controller for those queries: the DPA, HIPAA and the EU Data Boundary do not apply to them. Whether that is acceptable is a privacy decision the organisation should take explicitly.'
    Remediation = @{
        Steps      = "1. In the Microsoft 365 Apps admin center (config.office.com), open Customization > Policy Management.`n2. Create or edit a policy with Allow web search in Copilot and choose Enabled, Disabled, or Disabled in Work mode only, according to the organisation's privacy decision.`n3. Record the decision; after verifying the value ARGUS shows for the disabled option, add it to the DisabledValues parameter of ARG.COP.006 in the ARGUS configuration."
        PortalUrl  = 'https://config.office.com/officeSettings/officePolicies'
    }
    References  = @(
        @{ Title = 'Data, privacy, and security for web search in Microsoft Copilot'; Url = 'https://learn.microsoft.com/en-us/microsoft-365/copilot/manage-public-web-access' }
        @{ Title = 'Get copilotPolicySetting'; Url = 'https://learn.microsoft.com/en-us/microsoft-365/copilot/extensibility/api/admin-settings/copilotpolicysetting-get' }
    )
    Requires    = @{
        Services    = @('Graph')
        GraphScopes = @('CopilotPolicySettings.Read')
        DataSets    = @('CopilotWebSearchPolicy')
    }
    Parameters  = @{ DisabledValues = @() }
    Tags        = @('Copilot', 'AI', 'GDPR', 'Policy')
    Test        = {
        param($Context)
        $setting = $Context.Data['CopilotWebSearchPolicy']
        $unavailable = Get-ArgusProperty $setting 'ArgusUnavailable'
        if ($unavailable) { return New-ArgusResult -Status Skipped -SkipReason $unavailable }
        if ((Get-ArgusProperty $setting 'GroupScoped' $false) -eq $true) {
            return New-ArgusResult -Status Investigate -Summary 'Allow web search in Copilot is set in a group-scoped policy, which the API cannot read; review the policy in the Cloud Policy service.'
        }
        $value = Get-ArgusProperty $setting 'value'
        $policyId = Get-ArgusProperty $setting 'policyId'
        $finding = [pscustomobject]@{
            Setting  = 'Allow web search in Copilot'
            Value    = if ($null -eq $value) { 'Not configured' } else { [string]$value }
            PolicyId = if ($policyId) { [string]$policyId } else { 'No tenant-level policy' }
        }
        if ($null -eq $value) {
            return New-ArgusResult -Status Investigate -Findings @($finding) -EvaluatedCount 1 `
                -Summary 'Allow web search in Copilot is not configured: web search is available to users and its queries are outside the DPA and the EU Data Boundary.'
        }
        if ([string]$value -in @($Context.Parameters.DisabledValues | ForEach-Object { [string]$_ })) {
            return New-ArgusResult -Status Passed -EvaluatedCount 1 -AffectedCount 0 -Summary "Web search in Copilot is turned off by policy (value $value)."
        }
        New-ArgusResult -Status Investigate -Findings @($finding) -EvaluatedCount 1 `
            -Summary "Allow web search in Copilot is configured with value '$value'; confirm the chosen option in the Cloud Policy service."
    }
}
