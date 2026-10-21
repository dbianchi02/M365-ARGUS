# ARG.COP.008 — Agent creation and access are controlled (manual review)

| | |
|---|---|
| Area | Copilot |
| Category | Agent governance |
| Severity | Info |
| Services | Graph |
| Graph permissions (read-only) | — |
| Directory roles (delegated) | — |
| Licences | — |
| Data sets | — |
| Uses Graph beta | No |
| Tags | Copilot, Agents, Manual |

## What is checked

Who can use and install agents (Agents > Settings > User access, and Agent and plugin access) is set in the Microsoft 365 admin center, and who can build agents in Copilot Studio is set per Power Platform environment. No Microsoft API exposes these settings to read-only tools, so this check is always To review and lists what to verify. ARG.COP.002 covers self-service trial sign-up. Info severity: it does not change the score.

## Why it matters

When every user can build and run agents, agents connect to data, connectors and external services faster than they can be inventoried. A governed path (approved makers, approved agent types, a managed environment) keeps agents owned, reviewed and retired.

## How to fix

1. In the Microsoft 365 admin center, go to Agents > Settings > User access and choose Specific users or groups instead of All users if agents are not meant for everybody.
2. In Agents > Settings > Agent and plugin access, allow only the agent types the organisation supports (Microsoft, your organisation, external publishers).
3. In the Power Platform admin center, restrict environment creation to admins and limit Copilot Studio makers to a security group in each environment.

Portal: <https://admin.microsoft.com/>

## References

- [Agent settings in Microsoft 365 admin center](https://learn.microsoft.com/en-us/microsoft-365/admin/manage/agent-settings)
- [Agents admin guide for Microsoft 365](https://learn.microsoft.com/en-us/microsoft-365/copilot/agent-essentials/m365-agents-admin-guide)

---

*Generated from the check metadata by `./build/build.ps1 -Task Docs`. Do not edit by hand.*
