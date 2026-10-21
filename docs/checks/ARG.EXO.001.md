# ARG.EXO.001 — Shared mailboxes with sign-in enabled

| | |
|---|---|
| Area | Exchange |
| Category | Mailbox governance |
| Severity | Medium |
| Services | Graph, Exchange |
| Graph permissions (read-only) | `AuditLog.Read.All`, `User.Read.All` |
| Directory roles (delegated) | Global Reader, View-Only Organization Management |
| Exchange Online | Entra role Global Reader, or Exchange role group View-Only Organization Management |
| Licences | — |
| Data sets | Users, Mailboxes |
| Uses Graph beta | No |
| Tags | Exchange, Mailboxes |

## What is checked

Shared mailboxes (Exchange Online) whose user account in Microsoft Entra ID is enabled (`accountEnabled` = true). People access shared mailboxes through their own accounts and mailbox permissions; the account of the shared mailbox itself does not need to sign in.

## Why it matters

An enabled shared mailbox account has a password that nobody owns, is often excluded from reviews, and lets anyone who knows the password sign in directly instead of through audited delegate access.

## How to fix

1. Confirm that nobody signs in directly to the shared mailbox account (check its sign-in logs).
2. Block sign-in for the account (Microsoft 365 admin center > Users > Block sign-in); mailbox access through permissions keeps working.
3. Make blocking sign-in part of the process that creates or converts shared mailboxes.

Portal: <https://admin.microsoft.com/Adminportal/Home#/SharedMailbox>

```powershell
# Sample only - review before running. Blocks sign-in for one shared mailbox account.
Connect-MgGraph -Scopes 'User.ReadWrite.All'
Update-MgUser -UserId '<ObjectId>' -AccountEnabled:$false
```

## References

- [About shared mailboxes](https://learn.microsoft.com/en-us/microsoft-365/admin/email/about-shared-mailboxes)
- [Block shared mailbox accounts from signing in](https://learn.microsoft.com/en-us/microsoft-365/admin/email/create-a-shared-mailbox#block-sign-in-for-shared-mailbox-accounts)

---

*Generated from the check metadata by `./build/build.ps1 -Task Docs`. Do not edit by hand.*
