# ARG.ENT.004 — Guests that never accepted the invitation (more than 30 days)

| | |
|---|---|
| Area | EntraID |
| Category | External identities |
| Severity | Medium |
| Services | Graph |
| Graph permissions (read-only) | `AuditLog.Read.All`, `User.Read.All` |
| Directory roles (delegated) | Global Reader |
| Licences | — |
| Data sets | Users |
| Uses Graph beta | No |
| Tags | Guests, Lifecycle |

## What is checked

Guest accounts whose `externalUserState` is still **PendingAcceptance** more than **30** days after they were invited (`externalUserStateChangeDateTime`, or `createdDateTime` when not set).

## Why it matters

Unredeemed invitations clutter the directory, are often typos or abandoned collaborations, and can be redeemed later by whoever controls the mailbox.

## How to fix

1. Check with the person who invited the guest whether the collaboration is still needed.
2. Resend the invitation if it is, otherwise delete the guest account.

Portal: <https://entra.microsoft.com/>

```powershell
# Sample only - review before running. Deletes one pending guest.
Connect-MgGraph -Scopes 'User.ReadWrite.All'
Remove-MgUser -UserId '<ObjectId>'
```

## Parameters

Defaults, overridable in the configuration file under `Checks."ARG.ENT.004".Parameters`.

| Name | Default |
|---|---|
| `PendingDays` | 30 |

## References

- [Microsoft Entra B2B collaboration invitation redemption](https://learn.microsoft.com/en-us/entra/external-id/redemption-experience)

---

*Generated from the check metadata by `./build/build.ps1 -Task Docs`. Do not edit by hand.*
