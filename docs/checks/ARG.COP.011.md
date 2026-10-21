# ARG.COP.011 — Agents from external publishers available to all users

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
| Tags | Copilot, Agents, Inventory |

## What is checked

Packages of the agent catalogue (`GET /copilot/admin/catalog/packages`) with `type` = `external` (built by partners), not blocked, and `availableTo` = all users. Each one is To review: external agents process data under the publisher's own terms. Requires a Microsoft Agent 365 licence; otherwise the check is Skipped.

## Why it matters

Data processed by non-Microsoft agents and plugins is not covered by Microsoft agreements. Making them available to everybody should follow a review of the publisher's data handling, ideally with access limited to the teams that need them.

## How to fix

1. In the Microsoft 365 admin center, go to Agents > All agents and filter by external publishers.
2. For each agent, review the publisher terms and the data it can reach.
3. Limit availability to specific users or groups, or block the agent; consider allowing only Microsoft and organisation agents in Agents > Settings > Agent and plugin access.

Portal: <https://admin.microsoft.com/>

## References

- [Manage agents in the Microsoft 365 admin center](https://learn.microsoft.com/en-us/microsoft-365/admin/manage/manage-copilot-agents-integrated-apps)
- [List Copilot packages](https://learn.microsoft.com/en-us/microsoft-365/copilot/extensibility/api/admin-settings/package/copilotpackages-list)

---

*Generated from the check metadata by `./build/build.ps1 -Task Docs`. Do not edit by hand.*
