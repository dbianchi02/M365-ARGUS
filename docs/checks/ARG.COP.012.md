# ARG.COP.012 — Agent requests pending for more than 7 days

| | |
|---|---|
| Area | Copilot |
| Category | Agent governance |
| Severity | Low |
| Services | Graph |
| Graph permissions (read-only) | `CopilotPackages.Read.All` |
| Directory roles (delegated) | AI Administrator |
| Licences | AGENT_365 |
| Data sets | CopilotPackages |
| Uses Graph beta | No |
| Tags | Copilot, Agents, Lifecycle |

## What is checked

Packages with an open user request (`GET /copilot/admin/catalog/packages?$filter=requestStatus eq 'pending'`: publish, activate, access or update) whose `lastModifiedDateTime` is older than 7 days. The API exposes the package's last change, not the request date, so the age is approximate. Requires a Microsoft Agent 365 licence; otherwise the check is Skipped.

## Why it matters

An approval process only works when requests are answered. Requests left open push users to workarounds (personal agents, shadow tools) and leave the catalogue out of date.

## How to fix

1. In the Microsoft 365 admin center, go to Agents > Requests.
2. Approve or reject each request, with a reason.
3. Optionally add the agent management rule that rejects publish requests older than a set number of days (Agents > Settings > Agent management rules).

Portal: <https://admin.microsoft.com/>

## Parameters

Defaults, overridable in the configuration file under `Checks."ARG.COP.012".Parameters`.

| Name | Default |
|---|---|
| `PendingDays` | 7 |

## References

- [List Copilot packages: filter by request properties](https://learn.microsoft.com/en-us/microsoft-365/copilot/extensibility/api/admin-settings/package/copilotpackages-list)
- [Agent settings: agent management rules](https://learn.microsoft.com/en-us/microsoft-365/admin/manage/agent-settings)

---

*Generated from the check metadata by `./build/build.ps1 -Task Docs`. Do not edit by hand.*
