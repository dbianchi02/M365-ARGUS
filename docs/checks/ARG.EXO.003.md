# ARG.EXO.003 — Inactive shared mailboxes (more than 90 days)

| | |
|---|---|
| Area | Exchange |
| Category | Lifecycle |
| Severity | Low |
| Services | Graph, Exchange |
| Graph permissions (read-only) | `Reports.Read.All`, `ReportSettings.Read.All` |
| Directory roles (delegated) | Global Reader, Reports Reader, View-Only Organization Management |
| Exchange Online | Entra role Global Reader, or Exchange role group View-Only Organization Management |
| Licences | — |
| Data sets | MailboxUsage, ReportSettings, Mailboxes |
| Uses Graph beta | No |
| Tags | Exchange, Mailboxes, Lifecycle, Reports |

## What is checked

Shared mailboxes (Exchange Online) whose `Last Activity Date` in the mailbox usage report (`getMailboxUsageDetail`, period D180) is older than **90** days, or empty for mailboxes created before that. The report has no recipient type, so shared mailboxes are identified through Exchange Online. With concealed report names, or when the report returns no rows, the result is Investigate.

## Why it matters

Shared mailboxes created for projects, events or old processes outlive their purpose. Unused ones keep permissions, addresses and sometimes licences that nobody reviews.

## How to fix

1. Check with the delegates whether the mailbox is still needed.
2. If it is not, set an auto-reply pointing to the right contact, remove permissions and licences, then delete it after your retention period.
3. If it must be kept for records, apply a retention policy or hold.

Portal: <https://admin.exchange.microsoft.com/#/mailboxes>

## Parameters

Defaults, overridable in the configuration file under `Checks."ARG.EXO.003".Parameters`.

| Name | Default |
|---|---|
| `InactiveDays` | 90 |

## References

- [Microsoft 365 reports in the admin center - Mailbox usage](https://learn.microsoft.com/en-us/microsoft-365/admin/activity-reports/mailbox-usage)
- [About shared mailboxes](https://learn.microsoft.com/en-us/microsoft-365/admin/email/about-shared-mailboxes)

---

*Generated from the check metadata by `./build/build.ps1 -Task Docs`. Do not edit by hand.*
