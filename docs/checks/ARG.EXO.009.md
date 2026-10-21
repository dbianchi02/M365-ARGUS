# ARG.EXO.009 — Distribution groups without owner

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
| Data sets | DistributionGroups |
| Uses Graph beta | No |
| Tags | Exchange, Groups, Ownership |

## What is checked

Distribution groups and mail-enabled security groups (Exchange Online, `Get-DistributionGroup`) with an empty `ManagedBy` list, so only Exchange administrators can manage them.

## Why it matters

Without an owner, membership and delivery restrictions of a distribution list are not maintained, nobody can approve join requests, and the list keeps sending mail to people who left or changed role.

## How to fix

1. Identify a responsible person for each group (for example the team or department lead).
2. Set the owners in the Exchange admin center (Recipients > Groups > Settings), at least two per group.
3. Remove groups that are no longer used.

Portal: <https://admin.exchange.microsoft.com/#/groups>

```powershell
# Sample only - review before running. Sets the owners of one distribution group.
Connect-ExchangeOnline
Set-DistributionGroup -Identity '<PrimarySmtpAddress>' -ManagedBy '<owner1@contoso.com>','<owner2@contoso.com>'
```

## References

- [Create and manage distribution list groups in Exchange Online](https://learn.microsoft.com/en-us/exchange/recipients-in-exchange-online/manage-distribution-groups/manage-distribution-groups)
- [Get-DistributionGroup](https://learn.microsoft.com/en-us/powershell/module/exchangepowershell/get-distributiongroup)

---

*Generated from the check metadata by `./build/build.ps1 -Task Docs`. Do not edit by hand.*
