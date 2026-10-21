# ARG.LIC.002 — Enabled licensed users inactive for more than 90 days

| | |
|---|---|
| Area | Licensing |
| Category | Licence hygiene |
| Severity | High |
| Services | Graph |
| Graph permissions (read-only) | `AuditLog.Read.All`, `LicenseAssignment.Read.All`, `User.Read.All` |
| Directory roles (delegated) | Directory Readers, Global Reader |
| Licences | AAD_PREMIUM |
| Data sets | Users, SubscribedSkus |
| Uses Graph beta | No |
| Tags | Lifecycle, Licensing, Cost |

## What is checked

Enabled member accounts with at least one licence that have not signed in for **90** days (same inactivity logic as ARG.ENT.001: last successful sign-in, accounts that never signed in count from their creation date). The findings list the licences assigned to each account.

## Why it matters

Licences assigned to people who no longer use them are recurring cost with no business value, and the accounts keep access nobody reviews.

## How to fix

1. Confirm the users are no longer active.
2. Block sign-in, then remove or reassign the licences (or remove the users from the licensing group).
3. Reduce the subscription quantity at renewal if the seats are not needed.

Portal: <https://admin.microsoft.com/>

```powershell
# Sample only - review before running. Removes all licences from one user.
Connect-MgGraph -Scopes 'User.ReadWrite.All'
$skus = (Get-MgUserLicenseDetail -UserId '<ObjectId>').SkuId
Set-MgUserLicense -UserId '<ObjectId>' -AddLicenses @() -RemoveLicenses $skus
```

## Parameters

Defaults, overridable in the configuration file under `Checks."ARG.LIC.002".Parameters`.

| Name | Default |
|---|---|
| `InactiveDays` | 90 |

## References

- [Manage inactive user accounts in Microsoft Entra ID](https://learn.microsoft.com/en-us/entra/identity/monitoring-health/howto-manage-inactive-user-accounts)
- [Assign or unassign licenses for users in the Microsoft 365 admin center](https://learn.microsoft.com/en-us/microsoft-365/admin/manage/assign-licenses-to-users)

---

*Generated from the check metadata by `./build/build.ps1 -Task Docs`. Do not edit by hand.*
