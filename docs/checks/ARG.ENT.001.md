# ARG.ENT.001 — Enabled members inactive for more than 90 days

| | |
|---|---|
| Area | EntraID |
| Category | Identity lifecycle |
| Severity | Medium |
| Services | Graph |
| Graph permissions (read-only) | `AuditLog.Read.All`, `User.Read.All` |
| Directory roles (delegated) | Global Reader |
| Licences | AAD_PREMIUM |
| Data sets | Users |
| Uses Graph beta | No |
| Tags | Lifecycle, Users |

## What is checked

Enabled member accounts whose last successful sign-in (interactive or non-interactive) is older than **90** days, including accounts that never signed in and were created more than 90 days ago. Uses `signInActivity.lastSuccessfulSignInDateTime`, falling back to the last sign-in attempt for activity before December 2023.

## Why it matters

Accounts nobody uses keep their group memberships, app access and licences. Reviewing them regularly is the basis of identity lifecycle governance.

## How to fix

1. Confirm with the manager or HR that the account is no longer needed.
2. Block sign-in for the account.
3. After your retention period, remove licences and group memberships, then delete the account.

Portal: <https://entra.microsoft.com/>

```powershell
# Sample only - review before running. Blocks sign-in for one account.
Connect-MgGraph -Scopes 'User.ReadWrite.All'
Update-MgUser -UserId '<ObjectId>' -AccountEnabled:$false
```

## Parameters

Defaults, overridable in the configuration file under `Checks."ARG.ENT.001".Parameters`.

| Name | Default |
|---|---|
| `InactiveDays` | 90 |

## References

- [Manage inactive user accounts in Microsoft Entra ID](https://learn.microsoft.com/en-us/entra/identity/monitoring-health/howto-manage-inactive-user-accounts)

---

*Generated from the check metadata by `./build/build.ps1 -Task Docs`. Do not edit by hand.*
