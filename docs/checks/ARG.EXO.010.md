# ARG.EXO.010 — Empty distribution groups

| | |
|---|---|
| Area | Exchange |
| Category | Lifecycle |
| Severity | Low |
| Services | Graph, Exchange |
| Graph permissions (read-only) | `GroupMember.Read.All` |
| Directory roles (delegated) | Directory Readers, Global Reader, View-Only Organization Management |
| Exchange Online | Entra role Global Reader, or Exchange role group View-Only Organization Management |
| Licences | — |
| Data sets | DistributionGroups, DistributionGroupMembers |
| Uses Graph beta | No |
| Tags | Exchange, Groups, Lifecycle |

## What is checked

Distribution groups and mail-enabled security groups (`Get-DistributionGroup`) without members, read through Microsoft Graph (`GET /groups/<id>/members?$top=1`, sent in `$batch`). Groups whose members could not be read are left out of the evaluation. Dynamic distribution groups are not included.

## Why it matters

An empty distribution group still accepts mail, which then reaches nobody, and clutters the address book. Empty groups are usually left over from projects or reorganisations and can be removed.

## How to fix

1. Check with the owner (ManagedBy) whether the group is still needed.
2. Add the intended members, or delete the group.
3. Before deleting, check that no mail flow rule, connector or application sends to the address.

Portal: <https://admin.exchange.microsoft.com/#/groups>

## References

- [Manage distribution groups in Exchange Online](https://learn.microsoft.com/en-us/exchange/recipients-in-exchange-online/manage-distribution-groups/manage-distribution-groups)
- [List group members](https://learn.microsoft.com/en-us/graph/api/group-list-members)

---

*Generated from the check metadata by `./build/build.ps1 -Task Docs`. Do not edit by hand.*
