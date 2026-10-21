# ARG.EXO.006 — Mailboxes near their quota (more than 90% of the warning quota)

| | |
|---|---|
| Area | Exchange |
| Category | Storage |
| Severity | Low |
| Services | Graph |
| Graph permissions (read-only) | `Reports.Read.All`, `ReportSettings.Read.All` |
| Directory roles (delegated) | Global Reader, Reports Reader, View-Only Organization Management |
| Exchange Online | Entra role Global Reader, or Exchange role group View-Only Organization Management |
| Licences | — |
| Data sets | MailboxUsage, ReportSettings (optional: Mailboxes) |
| Uses Graph beta | No |
| Tags | Exchange, Storage, Reports |

## What is checked

User and shared mailboxes from the mailbox usage report (`getMailboxUsageDetail`, period D180) whose `Storage Used (Byte)` is more than **90%** of `Issue Warning Quota (Byte)` (the size at which the owner starts receiving warnings; `Prohibit Send Quota` is used when no warning quota is set). The findings also show how close the mailbox is to Prohibit Send. When Exchange Online is connected the mailbox type (user, shared, room, equipment) is shown. Deleted mailboxes and mailboxes without a quota are ignored. With concealed report names, or when the report returns no rows, the result is Investigate.

## Why it matters

Users can react to quota warnings, shared mailboxes cannot: nobody receives their warnings, and they stop accepting mail without notice once they reach the limit. Mailboxes past or near the warning quota need an archive, a retention policy, a cleanup or, for shared mailboxes above 50 GB, a licence.

## How to fix

1. Enable the archive mailbox (and auto-expanding archiving where licensed) for the listed mailboxes.
2. Apply a retention policy that moves old items to the archive.
3. For shared mailboxes above 50 GB, assign the licence that raises the quota.

Portal: <https://admin.exchange.microsoft.com/#/mailboxes>

## Parameters

Defaults, overridable in the configuration file under `Checks."ARG.EXO.006".Parameters`.

| Name | Default |
|---|---|
| `QuotaPercent` | 90 |

## References

- [Microsoft 365 reports in the admin center - Mailbox usage](https://learn.microsoft.com/en-us/microsoft-365/admin/activity-reports/mailbox-usage)
- [Enable archive mailboxes](https://learn.microsoft.com/en-us/purview/enable-archive-mailboxes)

---

*Generated from the check metadata by `./build/build.ps1 -Task Docs`. Do not edit by hand.*
