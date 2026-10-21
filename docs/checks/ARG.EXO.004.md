# ARG.EXO.004 — Inactive user mailboxes (more than 90 days)

| | |
|---|---|
| Area | Exchange |
| Category | Lifecycle |
| Severity | Low |
| Services | Graph |
| Graph permissions (read-only) | `Reports.Read.All`, `ReportSettings.Read.All` |
| Directory roles (delegated) | Global Reader, Reports Reader, View-Only Organization Management |
| Exchange Online | Entra role Global Reader, or Exchange role group View-Only Organization Management |
| Licences | — |
| Data sets | MailboxUsage, ReportSettings (optional: Mailboxes) |
| Uses Graph beta | No |
| Tags | Exchange, Lifecycle, Reports |

## What is checked

Mailboxes whose `Last Activity Date` in the mailbox usage report (`getMailboxUsageDetail`, period D180) is older than **90** days, or empty for mailboxes created before that. When Exchange Online is connected only user mailboxes are evaluated; otherwise the report also contains shared mailboxes, which is noted in the summary. With concealed report names, or when the report returns no rows, the result is Investigate.

## Why it matters

A user mailbox nobody uses usually belongs to a leaver or a forgotten test account: it keeps a licence, mail and permissions without a reason.

## How to fix

1. Confirm with the manager whether the mailbox is still needed.
2. If the content must be kept, convert it to a shared mailbox or apply a hold, then remove the licence.
3. Otherwise disable and delete the account after your retention period.

Portal: <https://admin.exchange.microsoft.com/#/mailboxes>

## Parameters

Defaults, overridable in the configuration file under `Checks."ARG.EXO.004".Parameters`.

| Name | Default |
|---|---|
| `InactiveDays` | 90 |

## References

- [Microsoft 365 reports in the admin center - Mailbox usage](https://learn.microsoft.com/en-us/microsoft-365/admin/activity-reports/mailbox-usage)
- [Convert a user mailbox to a shared mailbox](https://learn.microsoft.com/en-us/microsoft-365/admin/email/convert-user-mailbox-to-shared-mailbox)

---

*Generated from the check metadata by `./build/build.ps1 -Task Docs`. Do not edit by hand.*
