# ARG.EXO.002 — Shared mailboxes without delegates

| | |
|---|---|
| Area | Exchange |
| Category | Ownership |
| Severity | Low |
| Services | Graph, Exchange |
| Graph permissions (read-only) | — |
| Directory roles (delegated) | Global Reader, View-Only Organization Management |
| Exchange Online | Entra role Global Reader, or Exchange role group View-Only Organization Management |
| Licences | — |
| Data sets | Mailboxes, SharedMailboxPermissions |
| Uses Graph beta | No |
| Tags | Exchange, Mailboxes, Ownership |

## What is checked

Shared mailboxes with no explicit FullAccess permission (`Get-EXOMailboxPermission`: not inherited, not denied, `NT AUTHORITY\SELF` ignored). Send As and Send on Behalf permissions are not considered: without FullAccess nobody can open the mailbox. One Exchange call per shared mailbox.

## Why it matters

A shared mailbox nobody can open still receives mail that nobody reads, often from customers or suppliers. Every shared mailbox should have named people responsible for it.

## How to fix

1. Find out who should handle the mailbox (department, previous owners, mail content).
2. Grant FullAccess to those people, preferably through a mail-enabled security group.
3. If the mailbox is no longer needed, set an auto-reply, then remove it after your retention period.

Portal: <https://admin.exchange.microsoft.com/#/mailboxes>

```powershell
# Sample only - review before running.
Connect-ExchangeOnline
Add-MailboxPermission -Identity '<shared mailbox>' -User '<user or group>' -AccessRights FullAccess -AutoMapping $true
```

## References

- [Manage permissions for recipients in Exchange Online](https://learn.microsoft.com/en-us/exchange/recipients-in-exchange-online/manage-permissions-for-recipients)
- [Get-EXOMailboxPermission](https://learn.microsoft.com/en-us/powershell/module/exchangepowershell/get-exomailboxpermission)

---

*Generated from the check metadata by `./build/build.ps1 -Task Docs`. Do not edit by hand.*
