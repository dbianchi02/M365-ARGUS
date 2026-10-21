# ARG.EXO.007 — Mailboxes with forwarding configured (inventory)

| | |
|---|---|
| Area | Exchange |
| Category | Mail flow governance |
| Severity | Low |
| Services | Graph, Exchange |
| Graph permissions (read-only) | `Organization.Read.All` |
| Directory roles (delegated) | Directory Readers, Global Reader, View-Only Organization Management |
| Exchange Online | Entra role Global Reader, or Exchange role group View-Only Organization Management |
| Licences | — |
| Data sets | Mailboxes, Organization |
| Uses Graph beta | No |
| Tags | Exchange, Mailboxes, MailFlow, Inventory |

## What is checked

Inventory of mailboxes with mailbox-level forwarding (`ForwardingSmtpAddress` or `ForwardingAddress` in `Get-EXOMailbox`). A forwarding SMTP address whose domain is not a verified domain of the tenant is marked External; `ForwardingAddress` points to a recipient in the directory (it can be a mail contact outside the organisation). Inbox rules are not evaluated. Listed as To review: forwarding is often legitimate, but each one should have an owner and a reason, and forwarding left on leaver mailboxes should be removed.

## Why it matters

Forwarding set years ago keeps copying mail to addresses nobody reviews, sometimes outside the organisation and after the owner left. Knowing where mail is forwarded, and why, is part of mailbox lifecycle governance; blocking automatic external forwarding is a security control outside the scope of ARGUS.

## How to fix

1. Review each forwarding with the mailbox owner or manager: target, reason, still needed.
2. Remove forwarding that is no longer needed (Exchange admin center > Mailboxes > mailbox > Mail flow settings > Email forwarding).
3. For leavers, replace forwarding with a shared mailbox or delegate access for a limited period.

Portal: <https://admin.exchange.microsoft.com/#/mailboxes>

```powershell
# Sample only - review before running.
Connect-ExchangeOnline
Set-Mailbox -Identity '<mailbox>' -ForwardingSmtpAddress $null -ForwardingAddress $null -DeliverToMailboxAndForward $false
```

## References

- [Configure email forwarding for a mailbox](https://learn.microsoft.com/en-us/exchange/recipients-in-exchange-online/manage-user-mailboxes/configure-email-forwarding)
- [Get-EXOMailbox](https://learn.microsoft.com/en-us/powershell/module/exchangepowershell/get-exomailbox)

---

*Generated from the check metadata by `./build/build.ps1 -Task Docs`. Do not edit by hand.*
