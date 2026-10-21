# ARG.COP.006 — Web search in Copilot is a deliberate choice

| | |
|---|---|
| Area | Copilot |
| Category | AI data processing |
| Severity | Low |
| Services | Graph |
| Graph permissions (read-only) | `CopilotPolicySettings.Read` |
| Directory roles (delegated) | AI Administrator |
| Licences | — |
| Data sets | CopilotWebSearchPolicy |
| Uses Graph beta | Yes |
| Tags | Copilot, AI, GDPR, Policy |

## What is checked

Reads the tenant-level "Allow web search in Copilot" Cloud Policy setting (`GET /beta/copilot/admin/policySettings/microsoft.copilot.allowwebsearch`, delegated sign-in only). When the policy is not configured, web search is available in Copilot and Copilot Chat (unless optional connected experiences are disabled): To review. The meaning of each configured value is not documented, so a configured value is To review unless it is listed in the `DisabledValues` parameter after you verified it in the Cloud Policy service. A group-scoped policy cannot be read by this API and is also To review.

## Why it matters

With web search on, Copilot sends search queries derived from prompts (and sometimes from open documents) to Bing. Microsoft acts as data controller for those queries: the DPA, HIPAA and the EU Data Boundary do not apply to them. Whether that is acceptable is a privacy decision the organisation should take explicitly.

## How to fix

1. In the Microsoft 365 Apps admin center (config.office.com), open Customization > Policy Management.
2. Create or edit a policy with Allow web search in Copilot and choose Enabled, Disabled, or Disabled in Work mode only, according to the organisation's privacy decision.
3. Record the decision; after verifying the value ARGUS shows for the disabled option, add it to the DisabledValues parameter of ARG.COP.006 in the ARGUS configuration.

Portal: <https://config.office.com/officeSettings/officePolicies>

## Parameters

Defaults, overridable in the configuration file under `Checks."ARG.COP.006".Parameters`.

| Name | Default |
|---|---|
| `DisabledValues` | — |

## References

- [Data, privacy, and security for web search in Microsoft Copilot](https://learn.microsoft.com/en-us/microsoft-365/copilot/manage-public-web-access)
- [Get copilotPolicySetting](https://learn.microsoft.com/en-us/microsoft-365/copilot/extensibility/api/admin-settings/copilotpolicysetting-get)

---

*Generated from the check metadata by `./build/build.ps1 -Task Docs`. Do not edit by hand.*
