# ARG.EXO.005 — User mailboxes of disabled accounts

| | |
|---|---|
| Area | Exchange |
| Category | Lifecycle |
| Severity | Low |
| Services | Graph, Exchange |
| Graph permissions (read-only) | `AuditLog.Read.All`, `User.Read.All` |
| Directory roles (delegated) | Global Reader, View-Only Organization Management |
| Exchange Online | Entra role Global Reader, or Exchange role group View-Only Organization Management |
| Licences | — |
| Data sets | Users, Mailboxes |
| Uses Graph beta | No |
| Tags | Exchange, Mailboxes, Lifecycle |

## What is checked

User mailboxes (`RecipientTypeDetails` = UserMailbox) whose Microsoft Entra account is disabled (`accountEnabled` = false). Mailboxes on litigation hold or with in-place holds are counted as kept on purpose and not listed. Shared, room and equipment mailboxes are out of scope (their accounts are meant to be disabled).

## Why it matters

A disabled user with a live user mailbox is a leaver process that stopped halfway: mail keeps arriving, nobody reads it, and the mailbox usually keeps a licence. Converting it to a shared mailbox, delegating it or deleting it closes the process.

## How to fix

1. Ask the manager whether incoming mail or content is still needed.
2. Convert the mailbox to a shared mailbox and grant access to the manager, or set up forwarding for a limited period.
3. Remove the licence and delete the account after the retention period; apply a hold first when legal requirements apply.

Portal: <https://admin.exchange.microsoft.com/#/mailboxes>

## References

- [Convert a user mailbox to a shared mailbox](https://learn.microsoft.com/en-us/microsoft-365/admin/email/convert-user-mailbox-to-shared-mailbox)
- [Remove a former employee from Microsoft 365](https://learn.microsoft.com/en-us/microsoft-365/admin/add-users/remove-former-employee)

---

*Generated from the check metadata by `./build/build.ps1 -Task Docs`. Do not edit by hand.*
