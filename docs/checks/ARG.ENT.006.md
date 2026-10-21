# ARG.ENT.006 — Guests without a sponsor

| | |
|---|---|
| Area | EntraID |
| Category | External identities |
| Severity | Medium |
| Services | Graph |
| Graph permissions (read-only) | `AuditLog.Read.All`, `User.Read.All` |
| Directory roles (delegated) | Directory Readers, Global Reader, Guest Inviter |
| Licences | — |
| Data sets | Users, GuestSponsors |
| Uses Graph beta | No |
| Tags | Guests, Ownership |

## What is checked

Enabled guest users with no sponsor (`GET /users?$expand=sponsors`). Sponsors are the users or groups responsible for the guest's access and information; Microsoft Entra sets the inviter as sponsor for new invitations, so guests without one were usually invited before sponsors existed, lost a sponsor that left, or were invited by sharing a SharePoint file (a known case where no sponsor is set). Skipped when the account cannot read sponsors.

## Why it matters

Without a sponsor nobody is accountable for the guest: access reviews have no reviewer, and the guest stays after the collaboration ends. A sponsor (a person or, better, a group) makes guest lifecycle decisions possible.

## How to fix

1. For each guest, find the team or project that collaborates with them (group memberships, the inviter in the audit log).
2. Add a sponsor in the Microsoft Entra admin center (Users > guest > Sponsors), preferably a group.
3. Remove guests that nobody wants to sponsor, and use sponsors as reviewers in guest access reviews.

Portal: <https://entra.microsoft.com/#view/Microsoft_AAD_UsersAndTenants/UserManagementMenuBlade/~/AllUsers>

```powershell
# Sample only - review before running.
Connect-MgGraph -Scopes 'User.ReadWrite.All'
New-MgUserSponsorByRef -UserId '<guest id>' -BodyParameter @{ '@odata.id' = 'https://graph.microsoft.com/v1.0/users/<sponsor id>' }
```

## References

- [Add sponsors to a guest user](https://learn.microsoft.com/en-us/entra/external-id/b2b-sponsors)
- [List sponsors](https://learn.microsoft.com/en-us/graph/api/user-list-sponsors)

---

*Generated from the check metadata by `./build/build.ps1 -Task Docs`. Do not edit by hand.*
