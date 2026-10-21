# ARG.LIC.001 — Disabled users that still have licences

| | |
|---|---|
| Area | Licensing |
| Category | Licence hygiene |
| Severity | High |
| Services | Graph |
| Graph permissions (read-only) | `AuditLog.Read.All`, `LicenseAssignment.Read.All`, `User.Read.All` |
| Directory roles (delegated) | Directory Readers, Global Reader, View-Only Organization Management |
| Exchange Online | Entra role Global Reader, or Exchange role group View-Only Organization Management |
| Licences | — |
| Data sets | Users, SubscribedSkus (optional: Mailboxes) |
| Uses Graph beta | No |
| Tags | Licensing, Lifecycle, Cost |

## What is checked

Disabled accounts (`accountEnabled` = false) with at least one licence. Shared, room and equipment mailboxes are excluded using Exchange Online (they are disabled by design and may legitimately need a licence). When Exchange Online is not connected they cannot be told apart, so the result is Investigate.

## Why it matters

A licence on a disabled account is paid for but cannot be used. Leavers are the most common cause.

## How to fix

1. Check whether the mailbox must be kept (convert it to a shared mailbox, or apply a litigation hold / retention policy first).
2. Remove the licences, or remove the user from the licensing group.
3. Delete the account after your retention period.

Portal: <https://admin.microsoft.com/>

```powershell
# Sample only - review before running. Removes all licences from one user.
Connect-MgGraph -Scopes 'User.ReadWrite.All'
$skus = (Get-MgUserLicenseDetail -UserId '<ObjectId>').SkuId
Set-MgUserLicense -UserId '<ObjectId>' -AddLicenses @() -RemoveLicenses $skus
```

## References

- [Assign or unassign licenses for users in the Microsoft 365 admin center](https://learn.microsoft.com/en-us/microsoft-365/admin/manage/assign-licenses-to-users)
- [About shared mailboxes](https://learn.microsoft.com/en-us/microsoft-365/admin/email/about-shared-mailboxes)

---

*Generated from the check metadata by `./build/build.ps1 -Task Docs`. Do not edit by hand.*
