# ARG.ENT.005 — Guests inactive for more than 90 days

| | |
|---|---|
| Area | EntraID |
| Category | External identities |
| Severity | Medium |
| Services | Graph |
| Graph permissions (read-only) | `AuditLog.Read.All`, `User.Read.All` |
| Directory roles (delegated) | Global Reader |
| Licences | AAD_PREMIUM |
| Data sets | Users |
| Uses Graph beta | No |
| Tags | Guests, Lifecycle |

## What is checked

Enabled guest accounts that accepted their invitation but have not signed in for **90** days, including guests that never signed in and were added more than 90 days ago. Guests still pending acceptance are covered by ARG.ENT.004.

## Why it matters

Guests keep access to Teams, sites and files after the collaboration has ended. Removing inactive guests limits what external people can still reach.

## How to fix

1. Confirm with the sponsor or group owners that the collaboration has ended.
2. Block sign-in or delete the guest account.
3. Consider recurring access reviews for guests (Entra ID P2 or ID Governance).

Portal: <https://entra.microsoft.com/>

```powershell
# Sample only - review before running. Deletes one guest account (restorable for 30 days).
Connect-MgGraph -Scopes 'User.ReadWrite.All'
Remove-MgUser -UserId '<ObjectId>'
```

## Parameters

Defaults, overridable in the configuration file under `Checks."ARG.ENT.005".Parameters`.

| Name | Default |
|---|---|
| `InactiveDays` | 90 |

## References

- [Manage inactive user accounts in Microsoft Entra ID](https://learn.microsoft.com/en-us/entra/identity/monitoring-health/howto-manage-inactive-user-accounts)
- [Manage guest access with access reviews](https://learn.microsoft.com/en-us/entra/id-governance/manage-guest-access-with-access-reviews)

---

*Generated from the check metadata by `./build/build.ps1 -Task Docs`. Do not edit by hand.*
