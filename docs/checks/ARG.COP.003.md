# ARG.COP.003 — Copilot licences unused for more than 30 days

| | |
|---|---|
| Area | Copilot |
| Category | Licence governance |
| Severity | Medium |
| Services | Graph |
| Graph permissions (read-only) | `Reports.Read.All`, `ReportSettings.Read.All` |
| Directory roles (delegated) | AI Administrator, Global Reader, Reports Reader |
| Licences | M365_COPILOT_APPS |
| Data sets | CopilotUsage, ReportSettings |
| Uses Graph beta | No |
| Tags | Copilot, Licensing, Reports |

## What is checked

Users from the Microsoft 365 Copilot usage report (`copilot/reports/getMicrosoft365CopilotUsageUserDetail`, period D180), which lists only users with a Microsoft 365 Copilot licence, whose `Last Activity Date` is older than 30 days or empty (no Copilot use in the last 180 days). With concealed report names, or when the report returns no rows, the result is To review. Skipped when no Microsoft 365 Copilot licence is detected.

## Why it matters

Copilot licences are among the most expensive seats in Microsoft 365. Seats that are not used should go to people on the waiting list, or the user needs adoption support; either way the licence decision should be revisited.

## How to fix

1. Ask the users or their managers whether Copilot is still needed; offer training where adoption is the issue.
2. Remove the licence (or the user from the licensing group) where it is not needed and reassign it.
3. Review the Copilot usage report monthly to keep seats with active users.

Portal: <https://admin.microsoft.com/#/reportsUsage/MicrosoftCopilot>

## Parameters

Defaults, overridable in the configuration file under `Checks."ARG.COP.003".Parameters`.

| Name | Default |
|---|---|
| `InactiveDays` | 30 |

## References

- [Microsoft 365 reports - Microsoft 365 Copilot usage](https://learn.microsoft.com/en-us/microsoft-365/admin/activity-reports/microsoft-365-copilot-usage)
- [getMicrosoft365CopilotUsageUserDetail](https://learn.microsoft.com/en-us/microsoft-365/copilot/extensibility/api/admin-settings/reports/copilotreportroot-getmicrosoft365copilotusageuserdetail)

---

*Generated from the check metadata by `./build/build.ps1 -Task Docs`. Do not edit by hand.*
