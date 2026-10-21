# ARG.LIC.007 — Shared mailboxes with a licence

| | |
|---|---|
| Area | Licensing |
| Category | Cost |
| Severity | Low |
| Services | Graph, Exchange |
| Graph permissions (read-only) | `AuditLog.Read.All`, `LicenseAssignment.Read.All`, `User.Read.All` |
| Directory roles (delegated) | Directory Readers, Global Reader, View-Only Organization Management |
| Exchange Online | Entra role Global Reader, or Exchange role group View-Only Organization Management |
| Licences | — |
| Data sets | Users, SubscribedSkus, Mailboxes |
| Uses Graph beta | No |
| Tags | Licensing, Exchange, Cost |

## What is checked

Shared mailboxes (Exchange Online) whose user object has licences assigned. A shared mailbox needs a licence only when it is larger than 50 GB, has an online archive, or is on litigation hold or an in-place hold. Mailboxes that meet one of these conditions (size of **50** GB or more, archive active, `LitigationHoldEnabled`, non-empty `InPlaceHolds`) are not listed; the others are returned for review (Investigate), because organisation-wide retention policies and other needs are not visible to this check.

## Why it matters

Shared mailboxes are often licensed when a user mailbox is converted and the licence is never removed: a recurring cost with no benefit.

## How to fix

1. Confirm the mailbox does not need a licence (size, archive, holds, retention or other services such as Intune).
2. Remove the licence from the user object, or remove it from the licensing group.
3. If the mailbox needs an archive or a hold, consider Exchange Online Plan 2 or the Exchange Online Archiving add-on instead of a full suite.

Portal: <https://admin.microsoft.com/Adminportal/Home#/SharedMailbox>

## Parameters

Defaults, overridable in the configuration file under `Checks."ARG.LIC.007".Parameters`.

| Name | Default |
|---|---|
| `SizeThresholdGB` | 50 |

## References

- [About shared mailboxes](https://learn.microsoft.com/en-us/microsoft-365/admin/email/about-shared-mailboxes)
- [Exchange Online limits: mailbox storage limits](https://learn.microsoft.com/en-us/office365/servicedescriptions/exchange-online-service-description/exchange-online-limits)

---

*Generated from the check metadata by `./build/build.ps1 -Task Docs`. Do not edit by hand.*
